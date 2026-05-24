import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../data/progress_repository.dart';
import '../domain/progress_models.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  late Future<StoreCatalog> _catalogFuture;
  Map<String, StoreProduct> _productsByStoreId = const {};
  Map<String, ProductDetails> _nativeProducts = const {};
  String? _status;
  bool _busy = false;

  bool get _supportsStoreKit =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _catalogFuture = _load();
    _purchaseSubscription = _iap.purchaseStream.listen(_handlePurchases);
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<StoreCatalog> _load() async {
    final catalog = await widget.repository.loadStoreCatalog();
    _productsByStoreId = {
      for (final product in catalog.products)
        if (product.appStoreProductId.isNotEmpty)
          product.appStoreProductId: product,
    };
    if (_supportsStoreKit && _productsByStoreId.isNotEmpty) {
      final available = await _iap.isAvailable();
      if (available) {
        final response = await _iap.queryProductDetails(
          _productsByStoreId.keys.toSet(),
        );
        _nativeProducts = {
          for (final item in response.productDetails) item.id: item,
        };
      }
    }
    return catalog;
  }

  void _refresh() => setState(() => _catalogFuture = _load());

  Future<void> _buy(StoreProduct product) async {
    final native = _nativeProducts[product.appStoreProductId];
    if (native == null) {
      setState(
        () => _status = 'Bu paket App Store tarafında henüz hazır değil.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'App Store ödeme onayı bekleniyor.';
    });
    final param = PurchaseParam(productDetails: native);
    final started = product.interval.trim().isNotEmpty
        ? await _iap.buyNonConsumable(purchaseParam: param)
        : await _iap.buyConsumable(purchaseParam: param);
    if (!started && mounted) {
      setState(() {
        _busy = false;
        _status = 'Satın alma başlatılamadı.';
      });
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.canceled ||
          purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _busy = false;
            _status = purchase.error?.message ?? 'Satın alma iptal edildi.';
          });
        }
        continue;
      }
      final product = _productsByStoreId[purchase.productID];
      if (product == null) continue;
      try {
        await widget.repository.completeStorePurchase(
          product: product,
          purchaseId: purchase.purchaseID ?? '',
          verificationSource: purchase.verificationData.source,
          localVerificationData:
              purchase.verificationData.localVerificationData,
          serverVerificationData:
              purchase.verificationData.serverVerificationData,
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = 'Satın alma doğrulandı, ortak hakların güncellendi.';
          _catalogFuture = _load();
        });
      } on ProgressDataUnavailable catch (error) {
        if (mounted) setState(() => _status = error.message);
      }
    }
  }

  Future<void> _restore() async {
    if (!_supportsStoreKit) return;
    setState(() => _status = 'Satın almalar geri yükleniyor.');
    await _iap.restorePurchases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mağaza')),
      backgroundColor: PratiCaseColors.softSurface,
      body: FutureBuilder<StoreCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: PratiCaseSpinner());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton(
                onPressed: _refresh,
                child: const Text('Mağazayı Yeniden Yükle'),
              ),
            );
          }
          final catalog = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ortak Qlinik Cüzdanı',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${catalog.questionQuota} soru hakkı  |  ${catalog.walletBalance.toStringAsFixed(1)} coin',
                        style: const TextStyle(
                          color: PratiCaseColors.teal,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (catalog.aiQuota > 0)
                        Text('${catalog.aiQuota} AI hakkı'),
                    ],
                  ),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: const TextStyle(color: PratiCaseColors.navy),
                ),
              ],
              const SizedBox(height: 18),
              for (final product in catalog.products)
                Card(
                  child: ListTile(
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${product.description}\n${product.questionAmount} soru hakkı + ${product.coinAmount.toStringAsFixed(1)} coin',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed:
                          _busy ||
                              !_supportsStoreKit ||
                              !_nativeProducts.containsKey(
                                product.appStoreProductId,
                              )
                          ? null
                          : () => _buy(product),
                      child: Text(
                        _nativeProducts[product.appStoreProductId]?.price ??
                            '${(product.priceCents / 100).toStringAsFixed(2)} ${product.currency}',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _supportsStoreKit ? _restore : null,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Satın Almaları Geri Yükle'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paket hakları Qlinik ve PratiCase arasında ortak kullanılır. Ödeme yalnız App Store doğrulaması sonrası etkinleşir.',
                style: TextStyle(color: PratiCaseColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}
