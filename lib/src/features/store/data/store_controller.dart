import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/store_product.dart';
import '../domain/subscription_state.dart';
import 'storekit_repository.dart';
import 'storekit_service.dart';

/// Mağaza ekranlarının ortak state'ini tutan basit controller.
///
/// Repository (Supabase) ile Service (StoreKit 2) arasındaki köprü görevi
/// görür. Apple guideline'larına uygun şekilde tüm satın alma işlemleri
/// kullanıcıya geri bildirim verir.
class StoreController extends ChangeNotifier {
  StoreController({
    StoreKitRepository? repository,
    StoreKitService? service,
  })  : _repository = repository ?? StoreKitRepository(),
        _service = service ?? StoreKitService();

  final StoreKitRepository _repository;
  final StoreKitService _service;

  StreamSubscription<PurchaseDetails>? _subscription;

  List<PratiCaseStoreProduct> _products = const [];
  SubscriptionState _subscriptionState = SubscriptionState.empty;
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;
  bool _initialized = false;

  List<PratiCaseStoreProduct> get products => List.unmodifiable(_products);
  SubscriptionState get subscriptionState => _subscriptionState;
  bool get busy => _busy;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isSupported => _service.isSupported;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _service.initialize();
    _subscription = _service.purchaseUpdates.listen(_handlePurchase);
    _initialized = true;
  }

  Future<void> refresh() async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final catalog = await _repository.loadCatalog();
      _products = await _service.attachStoreKitMetadata(catalog);
      _subscriptionState = await _repository.loadSubscriptionState();
    } on StorePurchaseException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Mağaza verisi alınamadı: $error';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> purchase(PratiCaseStoreProduct product) async {
    if (_busy) return;
    _setBusy(true);
    _errorMessage = null;
    _statusMessage = 'App Store ödeme onayı bekleniyor.';
    try {
      final started = await _service.buy(product);
      if (!started) {
        _errorMessage = 'App Store satın alma başlatılamadı.';
        _setBusy(false);
      }
    } on StorePurchaseException catch (error) {
      _errorMessage = error.message;
      _setBusy(false);
    } catch (error) {
      _errorMessage = 'Satın alma başlatılamadı: $error';
      _setBusy(false);
    }
  }

  Future<void> restore() async {
    if (_busy) return;
    _setBusy(true);
    _errorMessage = null;
    _statusMessage = 'Satın almalar App Store üzerinden geri yükleniyor.';
    try {
      await _service.restorePurchases();
    } on StorePurchaseException catch (error) {
      _errorMessage = error.message;
      _setBusy(false);
    } catch (error) {
      _errorMessage = 'Geri yükleme başarısız oldu: $error';
      _setBusy(false);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _statusMessage = 'Apple ödeme onayını bekliyor.';
        notifyListeners();
        return;
      case PurchaseStatus.canceled:
        _errorMessage = 'Satın alma iptal edildi.';
        _statusMessage = null;
        _setBusy(false);
        return;
      case PurchaseStatus.error:
        _errorMessage = purchase.error?.message ?? 'App Store hatası.';
        _statusMessage = null;
        _setBusy(false);
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _completeServerVerification(purchase);
        return;
    }
  }

  Future<void> _completeServerVerification(PurchaseDetails purchase) async {
    final product = _findProduct(purchase.productID);
    if (product == null) {
      _errorMessage = 'Satın alınan ürün Supabase tarafında tanımlı değil: '
          '${purchase.productID}';
      await _service.completePurchase(purchase);
      _setBusy(false);
      return;
    }
    _statusMessage = 'Apple makbuzu doğrulanıyor.';
    notifyListeners();
    try {
      final state = await _repository.verifyPurchase(
        productCode: product.code,
        appStoreProductId: product.appStoreProductId,
        purchaseId: purchase.purchaseID ?? '',
        verificationSource: purchase.verificationData.source,
        localVerificationData: purchase.verificationData.localVerificationData,
        serverVerificationData:
            purchase.verificationData.serverVerificationData,
      );
      _subscriptionState = state;
      _statusMessage = state.hasActiveSubscription
          ? 'Aboneliğiniz aktif edildi.'
          : 'Satın alma doğrulandı.';
      await _service.completePurchase(purchase);
      // Katalog görünümünü güncelle.
      _products = await _service.attachStoreKitMetadata(
        await _repository.loadCatalog(),
      );
    } on StorePurchaseException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Doğrulama sırasında hata oluştu: $error';
    } finally {
      _setBusy(false);
    }
  }

  PratiCaseStoreProduct? _findProduct(String appStoreProductId) {
    for (final product in _products) {
      if (product.appStoreProductId == appStoreProductId) return product;
    }
    return null;
  }

  void clearStatus() {
    _statusMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    if (!value) {
      // status mesajını koru, hata mesajı varsa öne çıkar.
    }
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _service.dispose();
    super.dispose();
  }
}
