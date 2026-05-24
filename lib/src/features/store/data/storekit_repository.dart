import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/store_product.dart';
import '../domain/subscription_state.dart';

/// Supabase tarafındaki StoreKit / wallet entegrasyonu için repository.
///
/// - `loadCatalog` praticase için aktif ürünleri Supabase
///   `public.store_products` tablosundan okur (qlinik ile ortak).
/// - `loadSubscriptionState` ortak `wallet_entitlements` üzerinden mevcut
///   aboneliği döndürür.
/// - `verifyPurchase` `praticase-storekit-verify` edge fonksiyonunu çağırır.
class StoreKitRepository {
  StoreKitRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Aktif PratiCase ürünlerini döner.
  ///
  /// Filtre kriterleri:
  /// - `is_active = true`
  /// - `app_store_product_id` praticase namespace'inde
  ///   (`com.medasi.praticase.*`)
  Future<List<PratiCaseStoreProduct>> loadCatalog() async {
    try {
      final rows = await _client
          .from('store_products')
          .select(
            'code,name,description,price_cents,original_price_cents,currency,'
            'interval,features,is_featured,coin_amount,question_amount,'
            'app_store_product_id,badge,entitlement_kind,duration_days,sort_order',
          )
          .eq('is_active', true)
          .like('app_store_product_id', 'com.medasi.praticase.%')
          .order('sort_order')
          .order('price_cents');
      return [
        for (final row in rows)
          PratiCaseStoreProduct.fromMap(Map<String, dynamic>.from(row)),
      ];
    } on PostgrestException catch (error) {
      throw StorePurchaseException(
        'Mağaza kataloğu açılamadı: ${error.message}',
        code: error.code ?? 'catalog_failed',
      );
    }
  }

  /// Aktif abonelik durumunu döner. Kullanıcı yoksa boş döner.
  Future<SubscriptionState> loadSubscriptionState() async {
    final user = _client.auth.currentUser;
    if (user == null) return SubscriptionState.empty;
    try {
      // Wallet senkronizasyonu (eski expire kayıtlarını temizler).
      try {
        await _client.rpc(
          'sync_wallet_profile',
          params: {'p_user_id': user.id},
        );
      } on PostgrestException {
        // RPC erişimi service role gerektiriyor olabilir, sessiz devam et.
      }

      final rows = await _client
          .from('wallet_entitlements')
          .select(
            'product_code,entitlement_type,status,remaining_coin_amount,'
            'remaining_question_amount,period_started_at,expires_at',
          )
          .eq('user_id', user.id)
          .eq('entitlement_type', 'subscription')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('expires_at', ascending: false)
          .limit(1);

      final profileRow = await _client
          .from('profiles')
          .select('wallet_balance,question_quota')
          .eq('id', user.id)
          .maybeSingle();
      final wallet = profileRow == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(profileRow);

      if (rows.isEmpty) {
        return SubscriptionState(
          hasActiveSubscription: false,
          productCode: '',
          productName: '',
          expiresAt: null,
          periodStartedAt: null,
          willAutoRenew: false,
          environment: '',
          transactionId: '',
          originalTransactionId: '',
          walletCoinBalance:
              (wallet['wallet_balance'] as num?)?.toDouble() ?? 0,
          questionQuota: (wallet['question_quota'] as num?)?.round() ?? 0,
        );
      }
      final row = Map<String, dynamic>.from(rows.first);
      return SubscriptionState(
        hasActiveSubscription: true,
        productCode: (row['product_code'] ?? '').toString(),
        productName: _humanProductName((row['product_code'] ?? '').toString()),
        expiresAt: DateTime.tryParse((row['expires_at'] ?? '').toString()),
        periodStartedAt:
            DateTime.tryParse((row['period_started_at'] ?? '').toString()),
        willAutoRenew: true,
        environment: '',
        transactionId: '',
        originalTransactionId: '',
        walletCoinBalance: (wallet['wallet_balance'] as num?)?.toDouble() ?? 0,
        questionQuota: (wallet['question_quota'] as num?)?.round() ?? 0,
        remainingCoinAmount:
            (row['remaining_coin_amount'] as num?)?.toDouble() ?? 0,
        remainingQuestionAmount:
            (row['remaining_question_amount'] as num?)?.round() ?? 0,
      );
    } on PostgrestException catch (error) {
      throw StorePurchaseException(
        'Abonelik durumu okunamadı: ${error.message}',
        code: error.code ?? 'subscription_state_failed',
      );
    }
  }

  /// `praticase-storekit-verify` fonksiyonuna istek atar.
  Future<SubscriptionState> verifyPurchase({
    required String productCode,
    required String appStoreProductId,
    required String purchaseId,
    required String verificationSource,
    required String localVerificationData,
    required String serverVerificationData,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-storekit-verify',
        body: {
          'product_code': productCode,
          'store_product_id': appStoreProductId,
          'provider': 'app_store',
          'purchase_id': purchaseId,
          'verification_data': {
            'source': verificationSource,
            'local_verification_data': localVerificationData,
            'server_verification_data': serverVerificationData,
          },
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final error = (data['error'] ?? '').toString().trim();
      if (error.isNotEmpty) {
        throw StorePurchaseException(error, code: 'verify_failed');
      }
      return SubscriptionState.fromVerificationResponse(data);
    } on FunctionException catch (error) {
      throw StorePurchaseException(
        (error.details?.toString() ?? 'StoreKit doğrulaması başarısız oldu.')
            .trim(),
        code: 'verify_function_failed',
      );
    }
  }

  String _humanProductName(String code) {
    switch (code) {
      case 'com.medasi.praticase.monthly':
      case 'monthly_subscription':
        return 'Aylık Premium';
      case 'com.medasi.praticase.yearly':
      case 'yearly_subscription':
        return 'Yıllık Premium';
      case 'com.medasi.praticase.lifetime':
      case 'lifetime_purchase':
        return 'Yaşam Boyu Premium';
      default:
        return 'PratiCase Premium';
    }
  }
}
