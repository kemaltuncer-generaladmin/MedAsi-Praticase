import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/user_facing_error.dart';
import '../domain/subscription_state.dart';
import '../domain/wallet_snapshot.dart';
import '../domain/wallet_transaction.dart';

/// StoreKit / wallet entegrasyonu icin repository.
///
/// Katalog, abonelik durumu ve dogrulama islemleri istemciye tablo erisimi
/// vermeden edge function siniri uzerinden alinir.
class StoreKitRepository {
  StoreKitRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<WalletCatalog> loadWalletCatalog() async {
    final data = await _invoke(const {
      'action': 'store',
    }, fallback: PratiCaseUserMessage.storeFailure);
    return WalletCatalog.fromStoreResponse(data);
  }

  Future<SubscriptionState> loadSubscriptionState() async {
    final user = _client.auth.currentUser;
    if (user == null) return SubscriptionState.empty;
    final data = await _invoke(
      const {'action': 'subscription_status'},
      fallback: 'Abonelik bilgisi şu anda yüklenemedi. Tekrar deneyebilirsin.',
    );
    return SubscriptionState.fromVerificationResponse(data);
  }

  /// Cüzdan işlem geçmişini yükler. Edge fonksiyonu deploy edilmemişse
  /// veya kullanıcı oturumu yoksa boş liste döner — UI bunu sade empty state
  /// ile gösterir.
  Future<List<WalletTransaction>> loadWalletTransactions() async {
    final user = _client.auth.currentUser;
    if (user == null) return const <WalletTransaction>[];
    try {
      final data = await _invoke(const {
        'action': 'wallet_transactions',
      }, fallback: 'İşlem geçmişi şu anda yüklenemedi.');
      final rows = data['transactions'];
      if (rows is! List) return const <WalletTransaction>[];
      return [
        for (final row in rows)
          if (row is Map)
            WalletTransaction.fromMap(Map<String, dynamic>.from(row)),
      ];
    } on StorePurchaseException {
      // Edge fonksiyonu eski sürümde olabilir veya henüz yayında olmayabilir;
      // bu durumda sade empty state göstermek doğrudur.
      return const <WalletTransaction>[];
    }
  }

  Future<Uri> createPaymentCheckout({
    required String productCode,
    required String channel,
  }) async {
    final data = await _invoke({
      'action': 'create_payment_checkout',
      'product_code': productCode,
      'channel': channel,
    }, fallback: PratiCaseUserMessage.purchaseFailure);
    final checkout = data['checkout'];
    final checkoutData = checkout is Map
        ? Map<String, dynamic>.from(checkout)
        : const <String, dynamic>{};
    final uri = Uri.tryParse((checkoutData['checkoutUrl'] ?? '').toString());
    if (uri == null || !uri.hasScheme) {
      throw const StorePurchaseException(
        'Ödeme sayfası şu anda açılamadı. Lütfen tekrar dene.',
        code: 'missing_checkout_url',
      );
    }
    return uri;
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
    final data = await _invoke({
      'action': 'verify',
      'product_code': productCode,
      'store_product_id': appStoreProductId,
      'provider': 'app_store',
      'purchase_id': purchaseId,
      'verification_data': {
        'source': verificationSource,
        'local_verification_data': localVerificationData,
        'server_verification_data': serverVerificationData,
      },
    }, fallback: PratiCaseUserMessage.purchaseFailure);
    return SubscriptionState.fromVerificationResponse(data);
  }

  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body, {
    required String fallback,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-storekit-verify',
        body: body,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final error = (data['error'] ?? '').toString().trim();
      if (error.isNotEmpty) {
        throw StorePurchaseException(
          PratiCaseUserMessage.safe(error, fallback: fallback),
          code: 'request_failed',
        );
      }
      return data;
    } on StorePurchaseException {
      rethrow;
    } on FunctionException catch (error) {
      throw StorePurchaseException(
        _functionErrorMessage(error, fallback: fallback),
        code: 'function_failed',
      );
    } on Object {
      throw StorePurchaseException(fallback, code: 'request_failed');
    }
  }

  String _functionErrorMessage(
    FunctionException error, {
    required String fallback,
  }) {
    final details = error.details;
    if (details is Map) {
      final message = (details['error'] ?? details['message'])?.toString();
      return PratiCaseUserMessage.safe(message, fallback: fallback);
    }
    return PratiCaseUserMessage.safe(details?.toString(), fallback: fallback);
  }
}
