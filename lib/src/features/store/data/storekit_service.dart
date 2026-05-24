import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/store_product.dart';
import '../domain/subscription_state.dart';

/// Apple StoreKit 2 ile yerel etkileşim.
///
/// Sadece iOS / macOS üzerinde gerçek satın alma akışı çalıştırır. Diğer
/// platformlarda metotlar boş geçer ve `isSupported = false` döner.
/// `in_app_purchase_storekit` 0.4.x sürümünden itibaren StoreKit 2
/// varsayılan olduğu için ek konfigürasyon gerekmiyor.
class StoreKitService {
  StoreKitService({InAppPurchase? iap, this.bundleIdentifier})
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final String? bundleIdentifier;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final _controller = StreamController<PurchaseDetails>.broadcast();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

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
        debugPrint('StoreKit purchase stream error: $error');
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
        'Satın alma yalnızca iPhone uygulamasında yapılabilir.',
        code: 'unsupported_platform',
      );
    }
    if (product.appStoreProductId.isEmpty) {
      throw const StorePurchaseException(
        'Bu paket için App Store kimliği tanımlı değil.',
        code: 'missing_app_store_product_id',
      );
    }
    final response = await _iap.queryProductDetails(<String>{
      product.appStoreProductId,
    });
    if (response.productDetails.isEmpty) {
      throw const StorePurchaseException(
        'Bu paket şu anda App Store üzerinden satın alınamıyor.',
        code: 'app_store_product_unavailable',
      );
    }
    final details = response.productDetails.first;
    final param = PurchaseParam(productDetails: details);
    return product.isSubscription
        ? _iap.buyNonConsumable(purchaseParam: param)
        : _iap.buyConsumable(purchaseParam: param, autoConsume: true);
  }

  Future<void> restorePurchases() async {
    if (!isSupported) return;
    await _iap.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
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
