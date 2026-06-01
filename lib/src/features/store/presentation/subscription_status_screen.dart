import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_tokens.dart';
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
    final usesAppStore = controller.supportsAppStorePurchases;
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      appBar: AppBar(
        title: const Text('Abonelik Yönetimi'),
        backgroundColor: PratiCaseColors.softSurface,
        foregroundColor: PratiCaseColors.navy,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const _SubscriptionIntro(),
              const SizedBox(height: 20),
              _StatusCard(state: state),
              const SizedBox(height: 16),
              if (state.hasActiveSubscription) ...[
                _DetailsCard(state: state, usesAppStore: usesAppStore),
                const SizedBox(height: 16),
              ],
              if (state.warnings.isNotEmpty)
                _WarningsCard(warnings: state.warnings),
              const SizedBox(height: 8),
              _ActionsCard(
                hasActiveSubscription: state.hasActiveSubscription,
                usesAppStore: usesAppStore,
                onManage: _openSubscriptionsSettings,
                onRestore: usesAppStore && !controller.busy
                    ? controller.restore
                    : null,
                onUpgrade: _openPaywall,
              ),
              const SizedBox(height: 16),
              if (controller.errorMessage != null)
                _StatusBanner(message: controller.errorMessage!, isError: true),
              if (controller.statusMessage != null &&
                  controller.errorMessage == null)
                _StatusBanner(
                  message: controller.statusMessage!,
                  isError: false,
                ),
              const SizedBox(height: 16),
              _FaqList(usesAppStore: usesAppStore),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionIntro extends StatelessWidget {
  const _SubscriptionIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Abonelik Yönetimi',
          style: TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Dönemsel MC ve soru hakkı paketini, yenileme ve faturalandırma bilgilerini görüntüle.',
          style: TextStyle(
            color: PratiCaseColors.muted,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: hasActive ? PratiCaseGradients.hero : null,
        color: hasActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        border: hasActive ? null : Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: hasActive
                      ? PratiCaseColors.gold.withValues(alpha: 0.18)
                      : PratiCaseColors.teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
                  border: Border.all(
                    color: hasActive
                        ? PratiCaseColors.gold.withValues(alpha: 0.25)
                        : PratiCaseColors.teal.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  hasActive
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_outline_rounded,
                  color: hasActive
                      ? PratiCaseColors.gold
                      : PratiCaseColors.teal,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActive
                          ? state.productName
                          : 'Aktif abonelik bulunmuyor',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasActive ? Colors.white : PratiCaseColors.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (hasActive
                                    ? PratiCaseColors.white
                                    : PratiCaseColors.teal)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          PratiCaseRadius.pill,
                        ),
                      ),
                      child: Text(
                        hasActive ? 'Paket aktif' : 'Aktif abonelik bulunmuyor',
                        style: TextStyle(
                          color: hasActive
                              ? PratiCaseColors.white
                              : PratiCaseColors.teal,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasActive
                ? remaining == null
                      ? 'Abonelik süresi okunamadı.'
                      : 'Mevcut dönem bitimine ${_formatDuration(remaining)} kaldı.'
                : 'Dönemsel MC ve soru hakkı paketlerini cüzdandan inceleyebilirsin.',
            style: TextStyle(
              color: hasActive
                  ? Colors.white.withValues(alpha: 0.88)
                  : PratiCaseColors.muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
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
  const _DetailsCard({required this.state, required this.usesAppStore});

  final SubscriptionState state;
  final bool usesAppStore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Paket',
            value: state.productName.isEmpty ? '-' : state.productName,
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
            label: usesAppStore ? 'Otomatik yenileme' : 'Yenileme',
            value: usesAppStore
                ? (state.willAutoRenew ? 'Açık' : 'Kapalı')
                : 'Yeni ödeme gerekli',
          ),
          _DetailRow(
            label: 'Kalan soru hakkı',
            value: _formatWholeNumber(state.remainingQuestionAmount),
          ),
          _DetailRow(
            label: 'Kalan Medasi Coin',
            value: _formatWholeNumber(state.remainingCoinAmount),
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

  String _formatWholeNumber(num value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
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
              Icon(
                Icons.notifications_active_rounded,
                color: PratiCaseColors.gold,
              ),
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
    required this.usesAppStore,
    required this.onManage,
    required this.onRestore,
    required this.onUpgrade,
  });

  final bool hasActiveSubscription;
  final bool usesAppStore;
  final VoidCallback onManage;
  final VoidCallback? onRestore;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        children: [
          if (usesAppStore) ...[
            ListTile(
              leading: const Icon(
                Icons.shopping_bag_outlined,
                color: PratiCaseColors.teal,
              ),
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
              leading: const Icon(
                Icons.restore_rounded,
                color: PratiCaseColors.teal,
              ),
              title: const Text('Satın almaları geri yükle'),
              subtitle: const Text(
                'Aynı Apple kimliğiyle yapılan tüm satın almaları yeniler.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onRestore,
            ),
          ],
          if (!usesAppStore || !hasActiveSubscription) ...[
            if (usesAppStore)
              const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(
                usesAppStore
                    ? Icons.workspace_premium_outlined
                    : Icons.account_balance_outlined,
                color: PratiCaseColors.gold,
              ),
              title: Text(
                usesAppStore ? 'Premium’a yükselt' : 'Paket seç ve ödeme yap',
              ),
              subtitle: Text(
                usesAppStore
                    ? 'Aylık, yıllık veya yaşam boyu planlardan birini seç.'
                    : 'Ödeme sayfasında kart veya IBAN seçerek haklarını tanımlarsın.',
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

class _FaqList extends StatelessWidget {
  const _FaqList({required this.usesAppStore});

  final bool usesAppStore;

  static const _appStoreItems = <(String, String)>[
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
    final items = usesAppStore
        ? _appStoreItems
        : const <(String, String)>[
            (
              'Ödeme nasıl alınır?',
              'Seçtiğiniz paket için ödeme sayfasına geçer, kart veya IBAN '
                  'seçeneklerinden biriyle işlemi tamamlarsınız.',
            ),
            (
              'Abonelik otomatik yenilenir mi?',
              'Hayır. Ödeme sayfasıyla alınan süreli paket bitince devam etmek '
                  'için yeni ödeme gerekir.',
            ),
            (
              'Ödeme durumunu nereden görürüm?',
              'Ödeme sayfasındaki sipariş takip ekranında e-posta adresiniz ve '
                  'açıklama kodunuz ile durumu kontrol edebilirsiniz.',
            ),
          ];
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
            borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
            border: Border.all(color: PratiCaseColors.border),
            boxShadow: PratiCaseShadows.card,
          ),
          child: Column(
            children: [
              for (final entry in items)
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
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
