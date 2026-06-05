import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../../shared/data/user_facing_error.dart';
import '../domain/gift_code_redemption.dart';
import '../domain/store_product.dart';
import '../domain/subscription_state.dart';
import '../domain/wallet_snapshot.dart';
import '../domain/wallet_transaction.dart';
import 'storekit_repository.dart';
import 'storekit_service.dart';

/// Mağaza ekranlarının ortak state'ini tutan basit controller.
///
/// Repository (Supabase) ile Service (StoreKit 2) arasındaki köprü görevi
/// görür. Native mağaza kurallarına uygun şekilde tüm satın alma işlemleri
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
  WalletSnapshot _walletSnapshot = WalletSnapshot.empty;
  SubscriptionState _subscriptionState = SubscriptionState.empty;
  List<WalletTransaction> _transactions = const [];
  Set<String> _blockedProductCodes = const <String>{};
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;
  bool _initialized = false;

  List<PratiCaseStoreProduct> get products => List.unmodifiable(_products);
  WalletSnapshot get walletSnapshot => _walletSnapshot;
  SubscriptionState get subscriptionState => _subscriptionState;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
  Set<String> get blockedProductCodes => _blockedProductCodes;
  bool get busy => _busy;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isSupported => _service.isSupported;
  bool get supportsNativeStorePurchases => _service.isSupported;
  String get nativeStoreName => _service.storeName;
  bool get supportsExternalCheckout => kIsWeb;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _service.initialize();
    _subscription = _service.purchaseUpdates.listen(
      _handlePurchase,
      onError: (Object _) {
        _statusMessage = null;
        _errorMessage =
            '${_service.storeName} satın alma durumu izlenemedi. Lütfen tekrar dene.';
        _setBusy(false);
      },
    );
    _initialized = true;
  }

  Future<void> refresh() async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final catalog = await _repo.loadWalletCatalog(
        storeProvider: _service.verificationProvider,
      );
      _products = await _service.attachStoreKitMetadata(catalog.products);
      _walletSnapshot = catalog.snapshot;
      _blockedProductCodes = catalog.blockedProductCodes;
      try {
        _subscriptionState = await _repo.loadSubscriptionState();
      } on Object {
        _subscriptionState = SubscriptionState.empty;
      }
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
    if (_blockedProductCodes.contains(product.code)) {
      _statusMessage = null;
      _errorMessage =
          'Bu paket cüzdanında zaten aktif. Süresi bitince yeniden alabilirsin.';
      notifyListeners();
      return;
    }
    if (supportsExternalCheckout) {
      await _openPaymentCheckout(product);
      return;
    }
    _errorMessage = null;
    _statusMessage =
        'Ödemeniz alınıyor. ${_service.storeName} onayı bekleniyor.';
    _setBusy(true);
    try {
      final started = await _service.buy(product);
      if (!started) {
        _errorMessage = '${_service.storeName} satın alma başlatılamadı.';
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

  Future<void> redeemGiftCode(String code) async {
    if (_busy) return;
    final normalized = normalizeGiftCode(code);
    if (normalized.isEmpty) {
      _statusMessage = null;
      _errorMessage =
          'Hediye kodunu 16 karakterlik biçimiyle tekrar kontrol edelim.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _statusMessage = 'Hediye kodu kontrol ediliyor.';
    _setBusy(true);
    try {
      final redemption = await _repo.redeemGiftCode(normalized);
      _walletSnapshot = redemption.walletSnapshot;
      _statusMessage = 'Hediye kodu işlendi. Hakların güncellendi.';
      await _reloadAfterEntitlementChange();
    } on StorePurchaseException catch (error) {
      _statusMessage = null;
      _errorMessage = PratiCaseUserMessage.store(error.message);
    } on Object {
      _statusMessage = null;
      _errorMessage =
          'Hediye kodu şu an işlenemedi. Biraz sonra tekrar deneyelim.';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _reloadAfterEntitlementChange() async {
    try {
      final catalog = await _repo.loadWalletCatalog(
        storeProvider: _service.verificationProvider,
      );
      _products = await _service.attachStoreKitMetadata(catalog.products);
      _walletSnapshot = catalog.snapshot;
      _blockedProductCodes = catalog.blockedProductCodes;
    } on Object {
      // Redeem sonucu güncel bakiyeyi taşır; katalog yenileme best-effort.
    }
    try {
      _subscriptionState = await _repo.loadSubscriptionState();
    } on Object {
      _subscriptionState = SubscriptionState.empty;
    }
    try {
      _transactions = await _repo.loadWalletTransactions();
    } on Object {
      _transactions = const [];
    }
  }

  Future<void> _openPaymentCheckout(PratiCaseStoreProduct product) async {
    _errorMessage = null;
    _statusMessage = 'Ödemeniz alınıyor. Ödeme sayfası hazırlanıyor.';
    _setBusy(true);
    try {
      final uri = await _repo.createPaymentCheckout(
        productCode: product.code,
        channel: kIsWeb ? 'web' : 'android',
      );
      var launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
      if (!launched && kIsWeb) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
      }
      if (!launched) {
        throw const StorePurchaseException(
          'Ödeme sayfası şu anda açılamadı. Lütfen tekrar dene.',
          code: 'checkout_launch_failed',
        );
      }
      _statusMessage =
          'Ödeme sayfası açıldı. İşlemini kart veya IBAN ile tamamlayabilirsin.';
    } on StorePurchaseException catch (error) {
      _errorMessage = PratiCaseUserMessage.purchase(error.message);
    } on Object {
      _errorMessage = PratiCaseUserMessage.purchaseFailure;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> restore() async {
    if (_busy) return;
    _setBusy(true);
    _errorMessage = null;
    _statusMessage =
        'Satın almalar ${_service.storeName} üzerinden geri yükleniyor.';
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
        _statusMessage = '${_service.storeName} ödeme onayını bekliyor.';
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
    _statusMessage = '${_service.storeName} makbuzu doğrulanıyor.';
    notifyListeners();
    try {
      final state = await _repo.verifyPurchase(
        productCode: product.code,
        appStoreProductId: product.appStoreProductId,
        provider: _service.verificationProvider,
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
      final catalog = await _repo.loadWalletCatalog(
        storeProvider: _service.verificationProvider,
      );
      _products = await _service.attachStoreKitMetadata(catalog.products);
      _walletSnapshot = catalog.snapshot;
      _blockedProductCodes = catalog.blockedProductCodes;
      try {
        _subscriptionState = await _repo.loadSubscriptionState();
      } on Object {
        _subscriptionState = SubscriptionState.empty;
      }
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
