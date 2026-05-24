import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../../../app/theme/praticase_colors.dart';
import '../data/store_controller.dart';
import '../domain/subscription_state.dart';
import 'paywall_screen.dart';

/// Kullanıcının aktif aboneliğinin özetini ve yönetim aksiyonlarını sunar.
///
/// Apple guideline:
/// - Aboneliği iptal işlemi App Store ayarlarına yönlendirilir
///   (`https://apps.apple.com/account/subscriptions`).
/// - Plan değiştirme paywall ekranına yönlendirir.
class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({required this.controller, super.key});

  final StoreController controller;

  @override
  State<SubscriptionStatusScreen> createState() =>
      _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  static const _manageUrl = 'https://apps.apple.com/account/subscriptions';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    if (!widget.controller.initialized) {
      widget.controller.initialize().then((_) {
        if (mounted) widget.controller.refresh();
      });
    } else {
      widget.controller.refresh();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openSubscriptionsSettings() async {
    final uri = Uri.parse(_manageUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.subscriptionState;
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text('Abonelik Yönetimi'),
        backgroundColor: PratiCaseColors.softSurface,
        foregroundColor: PratiCaseColors.navy,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _StatusCard(state: state),
              const SizedBox(height: 16),
              if (state.hasActiveSubscription) ...[
                _DetailsCard(state: state),
                const SizedBox(height: 16),
              ],
              if (state.warnings.isNotEmpty)
                _WarningsCard(warnings: state.warnings),
              const SizedBox(height: 8),
              _ActionsCard(
                hasActiveSubscription: state.hasActiveSubscription,
                onManage: _openSubscriptionsSettings,
                onRestore: controller.busy ? null : controller.restore,
                onUpgrade: _openPaywall,
              ),
              const SizedBox(height: 16),
              if (controller.errorMessage != null)
                _StatusBanner(
                  message: controller.errorMessage!,
                  isError: true,
                ),
              if (controller.statusMessage != null &&
                  controller.errorMessage == null)
                _StatusBanner(
                  message: controller.statusMessage!,
                  isError: false,
                ),
              const SizedBox(height: 16),
              const _FaqList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final hasActive = state.hasActiveSubscription;
    final remaining = state.remainingDuration;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasActive
            ? const LinearGradient(
                colors: [
                  PratiCaseColors.gradientStart,
                  PratiCaseColors.gradientEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: hasActive
            ? null
            : Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasActive
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_outline_rounded,
                color:
                    hasActive ? PratiCaseColors.gold : PratiCaseColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                hasActive ? 'Premium Aktif' : 'Aktif abonelik bulunmuyor',
                style: TextStyle(
                  color: hasActive ? Colors.white : PratiCaseColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasActive ? state.productName : 'PratiCase Premium’u keşfet',
            style: TextStyle(
              color: hasActive ? Colors.white : PratiCaseColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasActive
                ? remaining == null
                    ? 'Abonelik süresi okunamadı.'
                    : 'Mevcut dönem bitimine ${_formatDuration(remaining)} kaldı.'
                : 'Sınırsız vakaya erişmek için bir paket seçerek başla.',
            style: TextStyle(
              color: hasActive
                  ? Colors.white.withValues(alpha: 0.88)
                  : PratiCaseColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      final days = duration.inDays;
      return '$days gün';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours} saat';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes} dakika';
    }
    return 'birkaç saniye';
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Plan kodu',
            value: state.productCode.isEmpty ? '-' : state.productCode,
          ),
          _DetailRow(
            label: 'Dönem başlangıcı',
            value: _formatDate(state.periodStartedAt),
          ),
          _DetailRow(
            label: 'Yenileme / bitiş tarihi',
            value: _formatDate(state.expiresAt),
          ),
          _DetailRow(
            label: 'Otomatik yenileme',
            value: state.willAutoRenew ? 'Açık' : 'Kapalı',
          ),
          _DetailRow(
            label: 'Kalan soru hakkı',
            value: '${state.remainingQuestionAmount}',
          ),
          _DetailRow(
            label: 'Kalan MedAsi Coin',
            value: state.remainingCoinAmount.toStringAsFixed(1),
          ),
          if (state.environment.isNotEmpty)
            _DetailRow(
              label: 'Ortam',
              value: state.environment,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: PratiCaseColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PratiCaseColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: PratiCaseColors.gold),
              SizedBox(width: 8),
              Text(
                'Süre hatırlatıcısı',
                style: TextStyle(
                  color: PratiCaseColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final message in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.hasActiveSubscription,
    required this.onManage,
    required this.onRestore,
    required this.onUpgrade,
  });

  final bool hasActiveSubscription;
  final VoidCallback onManage;
  final VoidCallback? onRestore;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined,
                color: PratiCaseColors.teal),
            title: Text(
              hasActiveSubscription
                  ? 'Aboneliği yönet / iptal et'
                  : 'Apple aboneliklerimi aç',
            ),
            subtitle: const Text(
              'App Store ayarlarına yönlendirir. İptal ve plan değişiklikleri '
              'Apple tarafından yönetilir.',
            ),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: onManage,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.restore_rounded,
                color: PratiCaseColors.teal),
            title: const Text('Satın almaları geri yükle'),
            subtitle: const Text(
              'Aynı Apple kimliğiyle yapılan tüm satın almaları yeniler.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onRestore,
          ),
          if (!hasActiveSubscription) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined,
                  color: PratiCaseColors.gold),
              title: const Text('Premium’a yükselt'),
              subtitle: const Text(
                'Aylık, yıllık veya yaşam boyu planlardan birini seç.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onUpgrade,
            ),
          ],
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
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

class _FaqList extends StatelessWidget {
  const _FaqList();

  static const _items = <(String, String)>[
    (
      'Ödeme nasıl alınır?',
      'Tüm satın alma işlemleri Apple Kimliğinize tanımlı ödeme yöntemi '
          'üzerinden Apple tarafından alınır. PratiCase ödeme bilgilerinizi '
          'kayıt etmez.',
    ),
    (
      'Aboneliğimi nasıl iptal ederim?',
      'iPhone’da Ayarlar > Apple Kimliği > Abonelikler > PratiCase yolunu '
          'kullanın. İptal işlemi mevcut dönem sonunda etkin olur ve yeniden '
          'ücret alınmaz.',
    ),
    (
      'Cihaz değiştirirsem ne olur?',
      'Aynı Apple kimliğiyle giriş yapıp “Satın Almaları Geri Yükle” butonuna '
          'dokunmanız yeterlidir.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'Sık sorulan sorular',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PratiCaseColors.border),
          ),
          child: Column(
            children: [
              for (final entry in _items)
                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    entry.$1,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.$2,
                        style: const TextStyle(
                          color: PratiCaseColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
