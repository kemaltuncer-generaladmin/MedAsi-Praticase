import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../shared/data/user_facing_error.dart';
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
    if (_busy) return;
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
    try {
      final param = PurchaseParam(productDetails: native);
      final started = product.interval.trim().isNotEmpty
          ? await _iap.buyNonConsumable(purchaseParam: param)
          : await _iap.buyConsumable(purchaseParam: param);
      if (!started && mounted) {
        setState(() {
          _busy = false;
          _status = PratiCaseUserMessage.purchaseFailure;
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = PratiCaseUserMessage.purchase(error);
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
            _status = purchase.status == PurchaseStatus.canceled
                ? 'Satın alma iptal edildi.'
                : PratiCaseUserMessage.purchase(purchase.error?.message);
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
    if (!_supportsStoreKit || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Satın almalar geri yükleniyor.';
    });
    try {
      await _iap.restorePurchases();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = PratiCaseUserMessage.purchase(error);
      });
    }
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
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PratiCaseSpinner(),
                  SizedBox(height: 16),
                  Text('Paketler yükleniyor...'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [_StoreErrorCard(onRetry: _refresh)],
            );
          }
          final catalog = snapshot.requireData;
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _WalletCard(catalog: catalog),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  _StoreStatusBanner(
                    message: PratiCaseUserMessage.safe(
                      _status,
                      fallback: PratiCaseUserMessage.purchaseFailure,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Paketler',
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (catalog.products.isEmpty)
                  _StoreErrorCard(onRetry: _refresh)
                else
                  for (final product in catalog.products) ...[
                    _StoreProductCard(
                      product: product,
                      price:
                          _nativeProducts[product.appStoreProductId]?.price ??
                          '${(product.priceCents / 100).toStringAsFixed(2)} ${product.currency}',
                      enabled:
                          !_busy &&
                          _supportsStoreKit &&
                          _nativeProducts.containsKey(
                            product.appStoreProductId,
                          ),
                      onBuy: () => _buy(product),
                    ),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _supportsStoreKit && !_busy ? _restore : null,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Satın Almaları Geri Yükle'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Medasi Cüzdanı, desteklenen Medasi uygulamalarında kullanılabilir. Satın alımlar App Store üzerinden güvenle yönetilir.',
                  style: TextStyle(
                    color: PratiCaseColors.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.catalog});

  final StoreCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medasi Cüzdanı',
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _WalletMetric(
                    icon: Icons.assignment_outlined,
                    value: _formatWholeNumber(catalog.questionQuota),
                    label: 'soru hakkı',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletMetric(
                    icon: Icons.account_balance_wallet_outlined,
                    value: _formatWholeNumber(catalog.walletBalance),
                    label: 'coin',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Medasi ekosisteminde desteklenen uygulamalarda kullanılabilir.',
              style: TextStyle(
                color: PratiCaseColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: PratiCaseColors.teal, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.teal,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  const _StoreProductCard({
    required this.product,
    required this.price,
    required this.enabled,
    required this.onBuy,
  });

  final StoreProduct product;
  final String price;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (product.isFeatured) ...[
                  const SizedBox(width: 8),
                  const _FeaturedPill(),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.muted,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallPill(
                  label: '${_formatWholeNumber(product.questionAmount)} soru',
                ),
                _SmallPill(
                  label: '${_formatWholeNumber(product.coinAmount)} coin',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enabled ? onBuy : null,
                child: Text(enabled ? '$price ile Satın Al' : price),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PratiCaseColors.slateBlue,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FeaturedPill extends StatelessWidget {
  const _FeaturedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: PratiCaseColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Önerilen',
        style: TextStyle(
          color: PratiCaseColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StoreStatusBanner extends StatelessWidget {
  const _StoreStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: PratiCaseColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StoreErrorCard extends StatelessWidget {
  const _StoreErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              color: PratiCaseColors.teal,
              size: 38,
            ),
            const SizedBox(height: 12),
            const Text(
              'Paketler şu anda yüklenemedi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekrar deneyebilir veya sorun devam ederse destek ekibine ulaşabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PratiCaseColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}

String _formatWholeNumber(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match.group(1)}.',
  );
}
