import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show BillingResponse;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show InAppPurchaseAndroidPlatformAddition;

import '../domain/store_product.dart';
import '../domain/subscription_state.dart';

/// Yerel mağaza ile etkileşim.
///
/// iOS / macOS tarafında StoreKit, Android tarafında Google Play Billing
/// kullanılır. Web'de Medasi Pay dış checkout akışı ayrı tutulur.
class StoreKitService {
  StoreKitService({InAppPurchase? iap, this.bundleIdentifier})
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final String? bundleIdentifier;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final _controller = StreamController<PurchaseDetails>.broadcast();
  final _pendingGooglePlayConsumables = <String>{};

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get isAppleStore =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get isGooglePlay =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get storeName => isGooglePlay ? 'Google Play' : 'App Store';

  String get verificationProvider => isGooglePlay ? 'google_play' : 'app_store';

  Stream<PurchaseDetails> get purchaseUpdates => _controller.stream;

  Future<bool> initialize() async {
    if (!isSupported) return false;
    final available = await _iap.isAvailable();
    if (!available) return false;
    _purchaseSubscription ??= _iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          _controller.add(purchase);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _controller.addError(error, stackTrace);
      },
    );
    return true;
  }

  Future<List<PratiCaseStoreProduct>> attachStoreKitMetadata(
    List<PratiCaseStoreProduct> products,
  ) async {
    if (!isSupported || products.isEmpty) return products;
    final ids = <String>{
      for (final product in products)
        if (product.appStoreProductId.isNotEmpty) product.appStoreProductId,
    };
    if (ids.isEmpty) return products;
    final response = await _iap.queryProductDetails(ids);
    if (response.productDetails.isEmpty) return products;
    final metadataByProductId = <String, ProductDetails>{
      for (final detail in response.productDetails) detail.id: detail,
    };
    return [
      for (final product in products)
        metadataByProductId.containsKey(product.appStoreProductId)
            ? product.copyWith(
                localizedPrice:
                    metadataByProductId[product.appStoreProductId]!.price,
                localizedTitle:
                    metadataByProductId[product.appStoreProductId]!.title,
                localizedDescription:
                    metadataByProductId[product.appStoreProductId]!.description,
              )
            : product,
    ];
  }

  Future<bool> buy(PratiCaseStoreProduct product) async {
    if (!isSupported) {
      throw const StorePurchaseException(
        'Satın alma yalnızca mobil uygulamada yapılabilir.',
        code: 'unsupported_platform',
      );
    }
    if (product.appStoreProductId.isEmpty) {
      throw StorePurchaseException(
        'Bu paket için $storeName ürün kimliği tanımlı değil.',
        code: 'missing_store_product_id',
      );
    }
    final response = await _iap.queryProductDetails(<String>{
      product.appStoreProductId,
    });
    if (response.productDetails.isEmpty) {
      throw StorePurchaseException(
        'Bu paket şu anda $storeName üzerinden satın alınamıyor.',
        code: 'store_product_unavailable',
      );
    }
    final details = response.productDetails.first;
    final param = PurchaseParam(productDetails: details);
    if (product.isSubscription) {
      return _iap.buyNonConsumable(purchaseParam: param);
    }
    if (isGooglePlay) {
      _pendingGooglePlayConsumables.add(product.appStoreProductId);
    }
    return _iap.buyConsumable(purchaseParam: param, autoConsume: !isGooglePlay);
  }

  Future<void> restorePurchases() async {
    if (!isSupported) return;
    await _iap.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (isGooglePlay &&
        _pendingGooglePlayConsumables.remove(purchase.productID)) {
      final result = await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(purchase);
      if (result.responseCode != BillingResponse.ok) {
        throw StorePurchaseException(
          'Google Play satın alma teslim edildi ancak tüketim işareti tamamlanamadı.',
          code: 'google_play_consume_failed',
        );
      }
      return;
    }
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    await _controller.close();
  }
}
