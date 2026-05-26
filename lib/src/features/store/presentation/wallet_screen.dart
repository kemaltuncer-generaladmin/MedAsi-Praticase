import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/ui/ui.dart';
import '../data/store_controller.dart';
import '../domain/store_product.dart';
import '../domain/subscription_state.dart';
import '../domain/wallet_transaction.dart';
import 'paywall_screen.dart';
import 'subscription_status_screen.dart';

/// Cüzdan sekmesi: MC bakiyesi, soru hakkı, aktif abonelik ve paket önerileri.
///
/// Tasarım kuralları (PratiCase wallet polish brief):
/// - Premium, klinik, finans uygulaması ciddiyetinde; AI/SaaS kokusu yok.
/// - Mevcut PratiCase token sistemini kullanır (renk/radius/shadow).
/// - Backend'e dokunmaz; sadece [StoreController] üzerinden okur.
class WalletScreen extends StatefulWidget {
  const WalletScreen({
    required this.controller,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.unreadNotificationCount,
    super.key,
  });

  final StoreController controller;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final int unreadNotificationCount;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _balanceHidden = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!widget.controller.initialized) {
      await widget.controller.initialize();
    }
    await widget.controller.refresh();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() => widget.controller.refresh();

  void _openPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallScreen(controller: widget.controller),
      ),
    );
  }

  void _openSubscriptionStatus() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubscriptionStatusScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.subscriptionState;
    final products = controller.products;
    final loading = controller.busy && products.isEmpty;
    final error = controller.errorMessage;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: PratiCaseResponsiveListView(
        padding: PratiCaseResponsive.pagePadding(context),
        children: [
          _WalletBrandHeader(
            onOpenNotifications: widget.onOpenNotifications,
            onOpenProfile: widget.onOpenProfile,
            unreadNotificationCount: widget.unreadNotificationCount,
          ),
          const SizedBox(height: 26),
          const _WalletTitle(),
          const SizedBox(height: 20),
          if (loading) ...[
            const _WalletSkeleton(),
          ] else ...[
            _WalletBalanceCard(
              state: state,
              hidden: _balanceHidden,
              onToggleHidden: () =>
                  setState(() => _balanceHidden = !_balanceHidden),
            ),
            const SizedBox(height: 12),
            _WalletStatsRow(state: state, hidden: _balanceHidden),
            const SizedBox(height: 12),
            _WalletConsumptionCard(transactions: controller.transactions),
            const SizedBox(height: 22),
            if (state.hasActiveSubscription) ...[
              _WalletSubscriptionCard(
                state: state,
                onManage: _openSubscriptionStatus,
              ),
              const SizedBox(height: 22),
            ],
            _WalletCtaBar(onPrimary: _openPaywall, primaryLabel: 'MC Satın Al'),
            const SizedBox(height: 26),
            _WalletSectionHeader(
              title: 'Paketler',
              actionLabel: products.isEmpty ? null : 'Tümünü Gör',
              onAction: products.isEmpty ? null : _openPaywall,
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              const _WalletEmptyPackages()
            else
              _WalletPackagesList(
                products: products,
                onSelect: (_) => _openPaywall(),
              ),
            if (error != null) ...[
              const SizedBox(height: 22),
              _WalletInlineError(message: error, onRetry: _refresh),
            ],
            const SizedBox(height: 26),
            const _WalletSectionHeader(
              title: 'Cüzdan Hareketleri',
              actionLabel: null,
              onAction: null,
            ),
            const SizedBox(height: 12),
            if (controller.transactions.isEmpty)
              const _WalletTransactionsEmpty()
            else
              _WalletTransactionList(transactions: controller.transactions),
            const SizedBox(height: 12),
            const _WalletTrustNote(),
          ],
        ],
      ),
    );
  }
}

// Header and title

class _WalletBrandHeader extends StatelessWidget {
  const _WalletBrandHeader({
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.unreadNotificationCount,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          child: Image.asset(
            'assets/auth/praticase_icon.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Prati'),
                TextSpan(
                  text: 'Case',
                  style: TextStyle(color: PratiCaseColors.teal),
                ),
              ],
            ),
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Bildirimler',
              onPressed: onOpenNotifications,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: PratiCaseColors.navy,
                size: 30,
              ),
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: const BoxDecoration(
                    color: PratiCaseColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadNotificationCount > 9
                        ? '9+'
                        : '$unreadNotificationCount',
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Profilim',
          onPressed: onOpenProfile,
          style: IconButton.styleFrom(
            backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.1),
            fixedSize: const Size(44, 44),
          ),
          icon: const Icon(
            Icons.person_outline_rounded,
            color: PratiCaseColors.teal,
          ),
        ),
      ],
    );
  }
}

class _WalletTitle extends StatelessWidget {
  const _WalletTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: PratiCaseColors.teal,
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Cüzdan',
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Medasi Coin bakiyeni, soru hakkını ve paketleri buradan yönet.',
          style: TextStyle(
            color: PratiCaseColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

// Balance card

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.state,
    required this.hidden,
    required this.onToggleHidden,
  });

  final SubscriptionState state;
  final bool hidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final balance = state.walletCoinBalance;
    final formatted = _formatMc(balance);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        gradient: PratiCaseGradients.hero,
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: PratiCaseColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  border: Border.all(
                    color: PratiCaseColors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: PratiCaseColors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Medasi Coin bakiyesi',
                      style: TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: hidden ? 'Bakiyeyi göster' : 'Bakiyeyi gizle',
                onPressed: onToggleHidden,
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: PratiCaseColors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hidden ? '••••' : formatted,
                    style: const TextStyle(
                      color: PratiCaseColors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'MC',
                  style: TextStyle(
                    color: PratiCaseColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Qlinik ve Medasi ekosisteminde kullanılabilir.',
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.86),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMc(double value) {
    if (value <= 0) return '0,00';
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(2).replaceFirst('.', ',');
  }
}

// Stats row

class _WalletStatsRow extends StatelessWidget {
  const _WalletStatsRow({required this.state, required this.hidden});

  final SubscriptionState state;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final tiles = <Widget>[
          _WalletStatCard(
            icon: Icons.menu_book_outlined,
            accent: PratiCaseColors.teal,
            label: 'Soru hakkı',
            value: hidden ? '••••' : '${state.questionQuota}',
            unit: 'kalan',
            sublabel: 'Teorik sınavda kullanılabilir',
          ),
          _WalletStatCard(
            icon: Icons.savings_outlined,
            accent: PratiCaseColors.slateBlue,
            label: 'Kullanılabilir MC',
            value: hidden ? '••••' : _formatMetricMc(state.walletCoinBalance),
            unit: 'MC',
            sublabel: 'AI işlemlerinde ortak bakiye',
          ),
        ];
        if (wide) {
          return Row(
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ],
          );
        }
        return Column(
          children: [tiles[0], const SizedBox(height: 12), tiles[1]],
        );
      },
    );
  }

  static String _formatMetricMc(double value) {
    return value.toStringAsFixed(2).replaceFirst('.', ',');
  }
}

class _WalletStatCard extends StatelessWidget {
  const _WalletStatCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.unit,
    required this.sublabel,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String unit;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sublabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// Subscription card

class _WalletSubscriptionCard extends StatelessWidget {
  const _WalletSubscriptionCard({required this.state, required this.onManage});

  final SubscriptionState state;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final remaining = state.remainingDuration;
    final remainingLabel = remaining == null
        ? 'Süresiz'
        : remaining == Duration.zero
        ? 'Süresi doldu'
        : '${remaining.inDays} gün kaldı';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: PratiCaseColors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.productName.isEmpty
                      ? 'Aktif aboneliğin var'
                      : state.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  remainingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.slateBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              foregroundColor: PratiCaseColors.teal,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Yönet'),
          ),
        ],
      ),
    );
  }
}

class _WalletConsumptionCard extends StatelessWidget {
  const _WalletConsumptionCard({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    WalletTransaction? latestUsage;
    for (final transaction in transactions) {
      if (transaction.isUsage) {
        latestUsage = transaction;
        break;
      }
    }
    final recentText = latestUsage == null
        ? 'Kullanımlar işlem gerçekleştikçe burada listelenir.'
        : 'Son kullanım: ${latestUsage.productName} · '
              '-${latestUsage.coinAmount.abs().toStringAsFixed(2).replaceFirst('.', ',')} MC';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: PratiCaseColors.teal,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MC tüketimi canlı takip edilir',
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Sanal hasta, AI karne ve sözlü sınav işlemlerinde '
                  'kullanım kadar MC düşer. En düşük AI tüketimi 0,10 MC.',
                  style: TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recentText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

// CTA bar

class _WalletCtaBar extends StatelessWidget {
  const _WalletCtaBar({required this.onPrimary, required this.primaryLabel});

  final VoidCallback onPrimary;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(primaryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: PratiCaseColors.teal,
                foregroundColor: PratiCaseColors.white,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onPrimary,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Paketleri Gör'),
            style: OutlinedButton.styleFrom(
              foregroundColor: PratiCaseColors.navy,
              side: const BorderSide(color: PratiCaseColors.border),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// Section header

class _WalletSectionHeader extends StatelessWidget {
  const _WalletSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.chevron_right_rounded),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: PratiCaseColors.teal,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

// Packages

class _WalletPackagesList extends StatelessWidget {
  const _WalletPackagesList({required this.products, required this.onSelect});

  final List<PratiCaseStoreProduct> products;
  final ValueChanged<PratiCaseStoreProduct> onSelect;

  @override
  Widget build(BuildContext context) {
    final featured = [...products]
      ..sort((a, b) {
        if (a.isFeatured == b.isFeatured) return 0;
        return a.isFeatured ? -1 : 1;
      });
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        if (wide) {
          const spacing = 12.0;
          final columns = constraints.maxWidth >= 980 ? 3 : 2;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final p in featured)
                SizedBox(
                  width: width,
                  child: _WalletPackageCard(
                    product: p,
                    onTap: () => onSelect(p),
                  ),
                ),
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < featured.length; i++) ...[
              _WalletPackageCard(
                product: featured[i],
                onTap: () => onSelect(featured[i]),
              ),
              if (i != featured.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _WalletPackageCard extends StatelessWidget {
  const _WalletPackageCard({required this.product, required this.onTap});

  final PratiCaseStoreProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priceLabel =
        product.localizedPrice ??
        _fallbackPrice(product.priceCents, product.currency);
    final periodLabel = product.periodLabel;
    final hasBadge = product.badge.trim().isNotEmpty || product.isFeatured;
    final badgeText = product.badge.trim().isNotEmpty
        ? product.badge.trim()
        : 'En çok tercih edilen';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
            border: Border.all(
              color: product.isFeatured
                  ? PratiCaseColors.teal.withValues(alpha: 0.55)
                  : PratiCaseColors.border,
              width: product.isFeatured ? 1.4 : 1,
            ),
            boxShadow: PratiCaseShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.localizedTitle?.trim().isNotEmpty == true
                          ? product.localizedTitle!.trim()
                          : product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (hasBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: PratiCaseColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          PratiCaseRadius.pill,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: PratiCaseColors.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        priceLabel,
                        style: const TextStyle(
                          color: PratiCaseColors.navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  if (periodLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/$periodLabel',
                        style: const TextStyle(
                          color: PratiCaseColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (product.coinAmount > 0 || product.questionAmount > 0)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (product.coinAmount > 0)
                      _PackageChip(
                        icon: Icons.savings_outlined,
                        label: '${product.coinAmount.toStringAsFixed(0)} MC',
                      ),
                    if (product.questionAmount > 0)
                      _PackageChip(
                        icon: Icons.menu_book_outlined,
                        label: '${product.questionAmount} soru',
                      ),
                  ],
                ),
              if (product.description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  product.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'İncele',
                    style: TextStyle(
                      color: PratiCaseColors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: PratiCaseColors.teal,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fallbackPrice(int cents, String currency) {
    if (cents <= 0) return 'Ücretsiz';
    final value = cents / 100;
    final symbol = currency.trim().toUpperCase() == 'TRY' ? '₺' : currency;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return symbol == '₺' ? '$formatted ₺' : '$formatted $symbol';
  }
}

class _PackageChip extends StatelessWidget {
  const _PackageChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: PratiCaseColors.slateBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: PratiCaseColors.slateBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// States: empty, error, skeleton

class _WalletEmptyPackages extends StatelessWidget {
  const _WalletEmptyPackages();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: PratiCaseColors.teal,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paketler şu anda yüklenemedi',
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Birazdan tekrar dene. İnternet bağlantını kontrol etmek faydalı olabilir.',
                  style: TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _WalletTransactionList extends StatelessWidget {
  const _WalletTransactionList({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            _WalletTransactionTile(transaction: transactions[i]),
            if (i != transactions.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: PratiCaseColors.border,
                indent: 18,
                endIndent: 18,
              ),
          ],
        ],
      ),
    );
  }
}

class _WalletTransactionTile extends StatelessWidget {
  const _WalletTransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.isCredit;
    final amountColor = positive
        ? PratiCaseColors.successGreen
        : PratiCaseColors.slateBlue;
    final amount = _formatAmount();
    final subtitle = _subtitle();
    final statusLabel = _statusLabel();
    final statusColor = transaction.isActive
        ? PratiCaseColors.successGreen
        : transaction.expired
        ? PratiCaseColors.muted
        : PratiCaseColors.slateBlue;
    final icon = transaction.isUsage
        ? Icons.remove_circle_outline_rounded
        : transaction.isSubscription
        ? Icons.autorenew_rounded
        : Icons.add_card_outlined;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: amountColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount() {
    final coin = transaction.coinAmount;
    final question = transaction.questionAmount;
    if (transaction.isUsage && coin < 0) {
      return '-${_fmtDebit(coin.abs())} MC';
    }
    if (coin > 0 && question > 0) {
      return '+${_fmtNum(coin)} MC · +$question soru';
    }
    if (coin > 0) {
      return '+${_fmtNum(coin)} MC';
    }
    if (question > 0) {
      return '+$question soru';
    }
    return '-';
  }

  String _subtitle() {
    final at = transaction.occurredAt;
    final base = at == null ? 'Tarih bilinmiyor' : _formatDate(at.toLocal());
    if (transaction.isUsage) {
      return '$base · MC tüketimi';
    }
    if (transaction.isSubscription) {
      return '$base · Abonelik';
    }
    return base;
  }

  String _statusLabel() {
    if (transaction.expired) return 'Süresi doldu';
    switch (transaction.status) {
      case 'active':
        return 'Aktif';
      case 'consumed':
        return 'Kullanıldı';
      case 'refunded':
        return 'İade edildi';
      case 'pending':
        return 'Bekleniyor';
      default:
        return transaction.status;
    }
  }

  static String _fmtNum(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _fmtDebit(double value) {
    return value.toStringAsFixed(2).replaceFirst('.', ',');
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _WalletTransactionsEmpty extends StatelessWidget {
  const _WalletTransactionsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PratiCaseColors.slateBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: PratiCaseColors.slateBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Henüz işlem yok',
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Satın alma ve kullanım geçmişin burada görünecek.',
            style: TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTrustNote extends StatelessWidget {
  const _WalletTrustNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(
          Icons.lock_outline_rounded,
          color: PratiCaseColors.muted,
          size: 14,
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Satın alma ve kullanım geçmişin Medasi güvencesiyle saklanır.',
            style: TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletInlineError extends StatelessWidget {
  const _WalletInlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(
          color: PratiCaseColors.errorRed.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: PratiCaseColors.errorRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: PratiCaseColors.errorRed,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _block(height: 148, radius: PratiCaseRadius.xxl),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _block(height: 116)),
            const SizedBox(width: 12),
            Expanded(child: _block(height: 116)),
          ],
        ),
        const SizedBox(height: 22),
        _block(height: 52, radius: PratiCaseRadius.lg),
        const SizedBox(height: 22),
        _block(height: 132, radius: PratiCaseRadius.lg),
      ],
    );
  }

  Widget _block({required double height, double radius = PratiCaseRadius.lg}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// Helpers

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
    border: Border.all(color: PratiCaseColors.border),
    boxShadow: PratiCaseShadows.card,
  );
}
