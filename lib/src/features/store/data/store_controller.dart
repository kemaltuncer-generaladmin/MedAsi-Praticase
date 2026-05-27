import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../shared/data/user_facing_error.dart';
import '../domain/store_product.dart';
import '../domain/subscription_state.dart';
import '../domain/wallet_transaction.dart';
import 'storekit_repository.dart';
import 'storekit_service.dart';

/// Mağaza ekranlarının ortak state'ini tutan basit controller.
///
/// Repository (Supabase) ile Service (StoreKit 2) arasındaki köprü görevi
/// görür. Apple guideline'larına uygun şekilde tüm satın alma işlemleri
/// kullanıcıya geri bildirim verir.
class StoreController extends ChangeNotifier {
  StoreController({StoreKitRepository? repository, StoreKitService? service})
    : _repository = repository,
      _service = service ?? StoreKitService();

  StoreKitRepository? _repository;
  final StoreKitService _service;

  StoreKitRepository get _repo => _repository ??= StoreKitRepository();

  StreamSubscription<PurchaseDetails>? _subscription;

  List<PratiCaseStoreProduct> _products = const [];
  SubscriptionState _subscriptionState = SubscriptionState.empty;
  List<WalletTransaction> _transactions = const [];
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;
  bool _initialized = false;

  List<PratiCaseStoreProduct> get products => List.unmodifiable(_products);
  SubscriptionState get subscriptionState => _subscriptionState;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
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
      final catalog = await _repo.loadCatalog();
      _products = await _service.attachStoreKitMetadata(catalog);
      _subscriptionState = await _repo.loadSubscriptionState();
      // Transactions are best-effort; failure shouldn't break the wallet view.
      try {
        _transactions = await _repo.loadWalletTransactions();
      } on Object {
        _transactions = const [];
      }
    } on StorePurchaseException catch (error) {
      _errorMessage = PratiCaseUserMessage.store(error.message);
    } on Object {
      _errorMessage = PratiCaseUserMessage.storeFailure;
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
      _errorMessage = PratiCaseUserMessage.purchase(error.message);
      _setBusy(false);
    } on Object {
      _errorMessage = PratiCaseUserMessage.purchaseFailure;
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
      _errorMessage = PratiCaseUserMessage.purchase(error.message);
      _setBusy(false);
    } on Object {
      _errorMessage =
          'Satın almalar şu anda geri yüklenemedi. Lütfen tekrar dene.';
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
        _errorMessage = PratiCaseUserMessage.purchase(purchase.error?.message);
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
      _errorMessage = 'Satın alınan paket doğrulanamadı. Lütfen tekrar dene.';
      await _service.completePurchase(purchase);
      _setBusy(false);
      return;
    }
    _statusMessage = 'Apple makbuzu doğrulanıyor.';
    notifyListeners();
    try {
      final state = await _repo.verifyPurchase(
        productCode: product.code,
        appStoreProductId: product.appStoreProductId,
        purchaseId: purchase.purchaseID ?? '',
        verificationSource: purchase.verificationData.source,
        localVerificationData: purchase.verificationData.localVerificationData,
        serverVerificationData:
            purchase.verificationData.serverVerificationData,
      );
      _subscriptionState = state;
      _statusMessage = product.isSubscription
          ? 'Aboneliğiniz aktif edildi.'
          : 'Satın alma doğrulandı.';
      await _service.completePurchase(purchase);
      // Katalog, bakiye ve hareket akışı ortak cüzdandan yeniden okunur.
      _products = await _service.attachStoreKitMetadata(
        await _repo.loadCatalog(),
      );
      _subscriptionState = await _repo.loadSubscriptionState();
      try {
        _transactions = await _repo.loadWalletTransactions();
      } on Object {
        _transactions = const [];
      }
    } on StorePurchaseException catch (error) {
      _errorMessage = PratiCaseUserMessage.purchase(error.message);
    } on Object {
      _errorMessage = PratiCaseUserMessage.purchaseFailure;
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
