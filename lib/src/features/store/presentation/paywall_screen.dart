import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../../../app/praticase_legal.dart';
import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../shared/ui/glow_button.dart';
import '../data/store_controller.dart';
import '../domain/store_product.dart';

/// Apple Guideline 3.1.1 / 3.1.2 uyumlu paywall ekranı.
///
/// İçerik:
/// - Yerel fiyat, dönem ve otomatik yenileme açıklaması
/// - Restore (geri yükleme) butonu
/// - Kullanım Şartları (EULA) ve Gizlilik linkleri
/// - Türkçe metinler
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    required this.controller,
    this.titleOverride,
    this.subtitleOverride,
    super.key,
  });

  final StoreController controller;
  final String? titleOverride;
  final String? subtitleOverride;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PratiCaseStoreProduct? _selected;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    if (!widget.controller.initialized) {
      widget.controller.initialize().then((_) {
        if (mounted) {
          widget.controller.refresh().then((_) {
            if (mounted) _selectDefault();
          });
        }
      });
    } else {
      widget.controller.refresh().then((_) {
        if (mounted) _selectDefault();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      _selected ??= _defaultProduct();
    });
  }

  void _selectDefault() {
    if (!mounted) return;
    setState(() => _selected = _defaultProduct());
  }

  PratiCaseStoreProduct? _defaultProduct() {
    final products = widget.controller.products;
    if (products.isEmpty) return null;
    final available = products
        .where((product) => product.canPurchaseInPratiCase)
        .toList();
    final selectable = available.isEmpty ? products : available;
    final featured = selectable.where((product) => product.isFeatured).toList();
    if (featured.isNotEmpty) return featured.first;
    return selectable.first;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _purchase() async {
    final product = _selected;
    if (product == null) return;
    await widget.controller.purchase(product);
  }

  Future<void> _restore() async {
    await widget.controller.restore();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final products = controller.products;
    final hasError = controller.errorMessage != null;
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        backgroundColor: PratiCaseColors.softSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: PratiCaseColors.navy),
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          TextButton(
            onPressed: controller.busy ? null : _restore,
            child: const Text(
              'Geri Yükle',
              style: TextStyle(
                color: PratiCaseColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !controller.initialized && products.isEmpty
            ? const Center(child: PratiCaseSpinner())
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _Hero(
                      title:
                          widget.titleOverride ?? 'Medasi Cüzdanına hak ekle',
                      subtitle:
                          widget.subtitleOverride ??
                          'Medasi ekosistemindeki ortak Coin ve soru haklarını '
                              'App Store üzerinden güvenle yönet.',
                    ),
                    const SizedBox(height: 18),
                    const _BenefitList(),
                    const SizedBox(height: 22),
                    if (products.isEmpty)
                      const _EmptyState()
                    else
                      Column(
                        children: [
                          for (final product in products)
                            _ProductCard(
                              product: product,
                              selected: _selected?.code == product.code,
                              onSelect: () =>
                                  setState(() => _selected = product),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    if (controller.statusMessage != null && !hasError)
                      _StatusBanner(
                        message: controller.statusMessage!,
                        isError: false,
                      ),
                    if (hasError)
                      _StatusBanner(
                        message: controller.errorMessage!,
                        isError: true,
                      ),
                    const SizedBox(height: 8),
                    _PurchaseButton(
                      product: _selected,
                      busy: controller.busy,
                      onTap: _purchase,
                    ),
                    const SizedBox(height: 14),
                    _RenewalDisclosure(product: _selected),
                    const SizedBox(height: 18),
                    _LegalLinks(
                      onOpenEula: () => _openUrl(PratiCaseLegal.termsUrl),
                      onOpenPrivacy: () =>
                          _openUrl(PratiCaseLegal.privacyPolicyUrl),
                      onOpenPurchaseTerms: () =>
                          _openUrl(PratiCaseLegal.purchaseTermsUrl),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: controller.busy ? null : _restore,
                        child: const Text(
                          'Önceki satın almalarımı geri yükle',
                          style: TextStyle(
                            color: PratiCaseColors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PratiCaseColors.gradientStart, PratiCaseColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PremiumBadge(),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PratiCaseColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PratiCaseColors.gold.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: PratiCaseColors.gold,
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
            'Medasi Cüzdanı',
            style: TextStyle(
              color: PratiCaseColors.gold,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList();

  static const _items = <(IconData, String, String)>[
    (
      Icons.savings_outlined,
      'Medasi Coin',
      'Sanal hasta, AI karne ve sözlü sınav işlemlerinde kullanılır.',
    ),
    (
      Icons.menu_book_outlined,
      'Soru hakkı',
      'Teorik sınavlarda ortak Medasi soru havuzu için kullanılır.',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Ortak cüzdan',
      'Medasi ekosistemindeki tüm uygulamalar aynı bakiye ve kota üzerinden çalışır.',
    ),
    (
      Icons.verified_outlined,
      'Canlı paket kataloğu',
      'Paket fiyatı ve içeriği ortak Medasi kataloğundan alınır.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        children: [
          for (final entry in _items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PratiCaseColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      entry.$1,
                      color: PratiCaseColors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.$2,
                          style: const TextStyle(
                            color: PratiCaseColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.$3,
                          style: const TextStyle(
                            color: PratiCaseColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatPrice(int cents) {
  if (cents <= 0) return 'Ücretsiz';
  final value = cents / 100;
  final formatted = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst('.', ',');
  return '₺$formatted';
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.onSelect,
  });

  final PratiCaseStoreProduct product;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final periodLabel = product.periodLabel;
    final priceText = _formatPrice(product.priceCents);
    final originalPriceText = product.originalPriceCents == null
        ? null
        : _formatPrice(product.originalPriceCents!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? PratiCaseColors.teal : PratiCaseColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? PratiCaseColors.teal
                              : PratiCaseColors.border,
                          width: 2,
                        ),
                        color: selected
                            ? PratiCaseColors.teal
                            : Colors.transparent,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.localizedTitle?.isNotEmpty == true
                            ? product.localizedTitle!
                            : product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PratiCaseColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (product.badge.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: PratiCaseColors.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          product.badge,
                          style: const TextStyle(
                            color: PratiCaseColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  product.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (periodLabel.isNotEmpty)
                      Text(
                        '/$periodLabel',
                        style: const TextStyle(
                          color: PratiCaseColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (originalPriceText != null)
                      Text(
                        originalPriceText,
                        style: const TextStyle(
                          color: PratiCaseColors.muted,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  const _PurchaseButton({
    required this.product,
    required this.busy,
    required this.onTap,
  });

  final PratiCaseStoreProduct? product;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled =
        product == null ||
        busy ||
        product!.canPurchaseInPratiCase == false;
    final label = product == null
        ? 'Bir paket seçin'
        : !product!.canPurchaseInPratiCase
        ? 'Satın alma bu uygulamada hazır değil'
        : product!.isSubscription
        ? 'Aboneliği başlat'
        : 'Satın al';
    return GlowButton(
      label: label,
      onPressed: disabled ? null : onTap,
      loading: busy,
      pulse: !disabled,
      height: 56,
      icon: disabled ? null : Icons.shopping_bag_rounded,
      semanticIdentifier: 'cta.paywall-purchase',
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? PratiCaseColors.errorRed.withValues(alpha: 0.1)
        : PratiCaseColors.teal.withValues(alpha: 0.1);
    final iconColor = isError ? PratiCaseColors.errorRed : PratiCaseColors.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: iconColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenewalDisclosure extends StatelessWidget {
  const _RenewalDisclosure({required this.product});

  final PratiCaseStoreProduct? product;

  @override
  Widget build(BuildContext context) {
    final localText = product?.isSubscription == true
        ? _renewalText(product!)
        : _oneTimeText;
    return Text(
      localText,
      style: const TextStyle(
        color: PratiCaseColors.muted,
        height: 1.45,
        fontSize: 12,
      ),
    );
  }

  static const _oneTimeText =
      'Tek seferlik satın alımdır. Otomatik yenileme yapılmaz. '
      'Ödeme Apple kimliğinize tanımlı yönteme yansır. '
      'Yüklenen MC veya soru hakkı Medasi Cüzdanınıza eklenir.';

  String _renewalText(PratiCaseStoreProduct product) {
    final price = _formatPrice(product.priceCents);
    final period = product.periodLabel.isNotEmpty
        ? product.periodLabel
        : '${product.durationDays} gün';
    return 'Abonelik $price tutarında $period yenilenir. Yenileme tarihinden '
        'en az 24 saat öncesine kadar Apple Kimliği ayarlarından iptal '
        'edilmedikçe otomatik olarak yenilenir. Ödeme onayı sırasında Apple '
        'kimliğinizden tahsil edilir ve cari dönem sonunda ücret yenilenir. '
        'Paketteki MC ve soru haklarının geçerlilik dönemi paket detayında '
        'belirtilir.';
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({
    required this.onOpenEula,
    required this.onOpenPrivacy,
    required this.onOpenPurchaseTerms,
  });

  final VoidCallback onOpenEula;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenPurchaseTerms;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: PratiCaseColors.muted, fontSize: 12),
        children: [
          const TextSpan(text: 'Devam ederek '),
          TextSpan(
            text: 'Kullanım Şartları (EULA)',
            recognizer: TapGestureRecognizer()..onTap = onOpenEula,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: ' ve '),
          TextSpan(
            text: 'Gizlilik Politikası',
            recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: '; satın alma için '),
          TextSpan(
            text: 'Satın Alma Şartları',
            recognizer: TapGestureRecognizer()..onTap = onOpenPurchaseTerms,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: '’nı kabul etmiş olursunuz.'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: PratiCaseColors.muted, size: 32),
          SizedBox(height: 10),
          Text(
            'Premium paketler şu anda yüklenemedi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'İnternet bağlantınızı kontrol edip sayfayı yenileyin veya daha '
            'sonra tekrar deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PratiCaseColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
