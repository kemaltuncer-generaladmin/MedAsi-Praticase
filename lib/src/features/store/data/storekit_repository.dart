import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/user_facing_error.dart';
import '../domain/store_product.dart';
import '../domain/subscription_state.dart';

/// StoreKit / wallet entegrasyonu icin repository.
///
/// Katalog, abonelik durumu ve dogrulama islemleri istemciye tablo erisimi
/// vermeden edge function siniri uzerinden alinir.
class StoreKitRepository {
  StoreKitRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PratiCaseStoreProduct>> loadCatalog() async {
    final data = await _invoke(const {
      'action': 'catalog',
    }, fallback: PratiCaseUserMessage.storeFailure);
    final rows = data['products'];
    if (rows is! List) {
      throw const StorePurchaseException(
        PratiCaseUserMessage.storeFailure,
        code: 'catalog_unavailable',
      );
    }
    return [
      for (final row in rows)
        if (row is Map)
          PratiCaseStoreProduct.fromMap(Map<String, dynamic>.from(row)),
    ];
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
    } on FunctionException {
      throw StorePurchaseException(fallback, code: 'function_failed');
    } on Object {
      throw StorePurchaseException(fallback, code: 'request_failed');
    }
  }
}
