import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/praticase_accent.dart';
import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/data/user_facing_error.dart';
import '../../../shared/ui/praticase_visuals.dart';
import '../../../shared/ui/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../store/data/store_controller.dart';
import '../../store/presentation/subscription_status_screen.dart';
import '../../store/presentation/wallet_screen.dart';
import '../data/progress_repository.dart';
import '../domain/progress_models.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  int _selectedFilter = 0;
  late Future<List<BadgeCard>> _badgesFuture;

  @override
  void initState() {
    super.initState();
    _badgesFuture = widget.repository.loadBadges();
  }

  Future<void> _refresh() async {
    setState(() {
      _badgesFuture = widget.repository.loadBadges();
    });
    await _badgesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BadgeCard>>(
      future: _badgesFuture,
      builder: (context, snapshot) {
        final badges = snapshot.data ?? const <BadgeCard>[];
        final visible = switch (_selectedFilter) {
          1 => badges.where((badge) => badge.earned).toList(),
          2 => badges.where((badge) => !badge.earned).toList(),
          _ => badges,
        };
        return _ProgressPage(
          title: 'Başarılarım',
          onRefresh: _refresh,
          children: [
            _BadgeSummaryHero(badges: badges),
            const SizedBox(height: 16),
            _SegmentHeader(
              items: const ['Tümü', 'Kazanılan', 'Kazanılmamış'],
              selectedIndex: _selectedFilter,
              onSelected: (index) => setState(() => _selectedFilter = index),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.workspace_premium_outlined,
                title: 'Rozetler yükleniyor',
                body: 'Rozet bilgilerin hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Rozetler açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (visible.isEmpty)
              const _StateBlock(
                icon: Icons.workspace_premium_outlined,
                title: 'Bu filtrede rozet yok',
                body: 'Rozet ilerlemesi oluştuğunda burada görünecek.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = PratiCaseResponsive.columnsForWidth(
                    constraints.maxWidth,
                    tablet: 3,
                    desktop: 4,
                  );
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns >= 3 ? 0.78 : 0.72,
                    children: [
                      for (final badge in visible) _BadgeCardView(badge: badge),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _scopeIndex = 0;
  int _periodIndex = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: widget.repository.loadLeaderboard(),
      builder: (context, snapshot) {
        final allEntries = snapshot.data ?? const <LeaderboardEntry>[];
        final entries = _filteredEntries(allEntries);
        final currentUsers = entries.where((entry) => entry.isCurrentUser);
        final current = currentUsers.isEmpty ? null : currentUsers.first;
        return _ProgressPage(
          title: 'Liderlik Tablosu',
          children: [
            _SegmentHeader(
              items: const ['Genel', 'Arkadaşlar', 'Kurum'],
              selectedIndex: _scopeIndex,
              onSelected: (index) => setState(() => _scopeIndex = index),
            ),
            const SizedBox(height: 12),
            _SegmentHeader(
              items: const ['Haftalık', 'Aylık', 'Tüm Zamanlar'],
              selectedIndex: _periodIndex,
              onSelected: (index) => setState(() => _periodIndex = index),
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.leaderboard_outlined,
                title: 'Sıralama yükleniyor',
                body: 'Puan tablosu hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Sıralama açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (entries.isEmpty)
              const _StateBlock(
                icon: Icons.leaderboard_outlined,
                title: 'Sıralama verisi yok',
                body: 'Sıralama verisi oluştuğunda liste burada görünecek.',
              )
            else ...[
              _TopThree(entries: entries.take(3).toList()),
              const SizedBox(height: 18),
              for (final entry in entries.skip(3))
                _LeaderboardTile(entry: entry),
              if (current != null) ...[
                const SizedBox(height: 18),
                _RankSummary(entry: current),
              ],
            ],
          ],
        );
      },
    );
  }

  List<LeaderboardEntry> _filteredEntries(List<LeaderboardEntry> entries) {
    final scoped = switch (_scopeIndex) {
      1 => entries.where((entry) => entry.isCurrentUser).toList(),
      _ => entries,
    };
    final sorted = [...scoped];
    sorted.sort((a, b) {
      final primary = switch (_periodIndex) {
        0 => b.totalPoints.compareTo(a.totalPoints),
        1 => b.correctDiagnosisRate.compareTo(a.correctDiagnosisRate),
        _ => a.rank.compareTo(b.rank),
      };
      return primary == 0 ? a.rank.compareTo(b.rank) : primary;
    });
    return sorted;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.authRepository,
    required this.repository,
    required this.onSignOut,
    required this.storeControllerFactory,
    this.unreadNotificationCount = 0,
    this.onOpenNotifications,
    super.key,
  });

  final AuthRepository authRepository;
  final ProgressRepository repository;
  final Future<void> Function() onSignOut;
  final StoreController Function() storeControllerFactory;
  final int unreadNotificationCount;
  final VoidCallback? onOpenNotifications;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileCard> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.repository.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCard>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PratiCaseScreenSkeleton(
            titleWidth: 170,
            heroHeight: 230,
            cardCount: 2,
          );
        }
        if (snapshot.hasError) {
          return _ProgressPage(
            title: 'Profil',
            children: [
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Profil açılamadı',
                body: _errorText(snapshot.error),
              ),
            ],
          );
        }
        final profile = snapshot.requireData;
        return PratiCaseResponsiveListView(
          padding: PratiCaseResponsive.pagePadding(context),
          children: [
            _ProfileBrandHeader(
              repository: widget.repository,
              profile: profile,
              unreadNotificationCount: widget.unreadNotificationCount,
              onOpenNotifications: widget.onOpenNotifications,
            ),
            const SizedBox(height: 18),
            _ProfileHero(profile: profile),
            const SizedBox(height: 12),
            _ProfilePlanPanel(profile: profile),
            const SizedBox(height: 12),
            _StatsPanel(profile: profile),
            const SizedBox(height: 14),
            _MenuPanel(
              authRepository: widget.authRepository,
              repository: widget.repository,
              storeControllerFactory: widget.storeControllerFactory,
              unreadNotificationCount: widget.unreadNotificationCount,
              onOpenNotifications: widget.onOpenNotifications,
              items: const [
                _MenuItem(
                  Icons.history_rounded,
                  'Vaka Geçmişim',
                  semanticsId: 'menu.case-history',
                ),
                _MenuItem(
                  Icons.favorite_border_rounded,
                  'Favori Vakalarım',
                  semanticsId: 'menu.favorites',
                ),
                _MenuItem(
                  Icons.note_alt_outlined,
                  'Notlarım',
                  semanticsId: 'menu.notes',
                ),
                _MenuItem(
                  Icons.local_fire_department_outlined,
                  'Günlük Hedefler',
                  semanticsId: 'menu.daily-goals',
                ),
                _MenuItem(
                  Icons.leaderboard_outlined,
                  'Liderlik Tablosu',
                  semanticsId: 'menu.leaderboard',
                ),
                _MenuItem(
                  Icons.notifications_none_rounded,
                  'Bildirimler',
                  semanticsId: 'menu.notifications',
                ),
                _MenuItem(
                  Icons.workspace_premium_outlined,
                  'Başarılarım',
                  semanticsId: 'menu.badges',
                ),
                _MenuItem(
                  Icons.storefront_outlined,
                  'Mağaza',
                  semanticsId: 'menu.store',
                ),
                _MenuItem(
                  Icons.diamond_outlined,
                  'Premium Abonelik',
                  semanticsId: 'menu.subscription',
                ),
                _MenuItem(
                  Icons.settings_outlined,
                  'Ayarlar',
                  semanticsId: 'menu.settings',
                ),
                _MenuItem(
                  Icons.download_rounded,
                  'İndirmelerim',
                  semanticsId: 'menu.downloads',
                ),
              ],
              onSignOut: widget.onSignOut,
            ),
          ],
        );
      },
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.authRepository,
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final AuthRepository authRepository;
  final ProgressRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _appVersion = 'v1.0.1';
  late Future<ProfileCard> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.repository.loadProfile();
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = widget.repository.loadProfile();
    });
    await _profileFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCard>(
      future: _profileFuture,
      builder: (context, snapshot) {
        return _ProgressPage(
          title: 'Ayarlar',
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.settings_outlined,
                title: 'Ayarlar yükleniyor',
                body: 'Uygulama ayarların yükleniyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Ayarlar açılamadı',
                body: _errorText(snapshot.error),
              )
            else ...[
              _SettingsHero(settings: snapshot.requireData.settings),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Hesap',
                rows: [
                  _SettingsRow(
                    Icons.person_outline_rounded,
                    'Profil Bilgileri',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileEditScreen(
                          repository: widget.repository,
                          profile: snapshot.requireData,
                        ),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.lock_outline_rounded,
                    'Hesap ve Güvenlik',
                    value: 'E-posta ile giriş',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountSecurityScreen(
                          authRepository: widget.authRepository,
                          profile: snapshot.requireData,
                        ),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.notifications_none_rounded,
                    'Bildirim Ayarları',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NotificationsScreen(repository: widget.repository),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Uygulama',
                rows: [
                  _SettingsRow(
                    Icons.visibility_outlined,
                    'Görüntüleme',
                    value: snapshot.requireData.settings.displayMode,
                    onTap: () => _chooseSetting(
                      snapshot.requireData.settings,
                      title: 'Görüntüleme',
                      values: const ['Sistem', 'Açık', 'Koyu'],
                      apply: (settings, value) => AppSettings(
                        displayMode: value,
                        language: settings.language,
                        textSize: settings.textSize,
                        soundAndHaptics: settings.soundAndHaptics,
                        dataUsage: settings.dataUsage,
                        offlineMode: settings.offlineMode,
                        caseDownloadsEnabled: settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.language_rounded,
                    'Dil',
                    value: snapshot.requireData.settings.language,
                    onTap: () => _chooseSetting(
                      snapshot.requireData.settings,
                      title: 'Dil',
                      values: const ['Türkçe'],
                      apply: (settings, value) => AppSettings(
                        displayMode: settings.displayMode,
                        language: value,
                        textSize: settings.textSize,
                        soundAndHaptics: settings.soundAndHaptics,
                        dataUsage: settings.dataUsage,
                        offlineMode: settings.offlineMode,
                        caseDownloadsEnabled: settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.text_fields_rounded,
                    'Yazı Boyutu',
                    value: snapshot.requireData.settings.textSize,
                    onTap: () => _chooseSetting(
                      snapshot.requireData.settings,
                      title: 'Yazı Boyutu',
                      values: const ['Küçük', 'Orta', 'Büyük'],
                      apply: (settings, value) => AppSettings(
                        displayMode: settings.displayMode,
                        language: settings.language,
                        textSize: value,
                        soundAndHaptics: settings.soundAndHaptics,
                        dataUsage: settings.dataUsage,
                        offlineMode: settings.offlineMode,
                        caseDownloadsEnabled: settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.volume_up_outlined,
                    'Ses ve Titreşim',
                    enabled: snapshot.requireData.settings.soundAndHaptics,
                    onTap: () => _saveSettings(
                      AppSettings(
                        displayMode: snapshot.requireData.settings.displayMode,
                        language: snapshot.requireData.settings.language,
                        textSize: snapshot.requireData.settings.textSize,
                        soundAndHaptics:
                            !snapshot.requireData.settings.soundAndHaptics,
                        dataUsage: snapshot.requireData.settings.dataUsage,
                        offlineMode: snapshot.requireData.settings.offlineMode,
                        caseDownloadsEnabled:
                            snapshot.requireData.settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _AccentPickerCard(),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Veri',
                rows: [
                  _SettingsRow(
                    Icons.data_usage_rounded,
                    'Veri Kullanımı',
                    value: snapshot.requireData.settings.dataUsage,
                    onTap: () => _chooseSetting(
                      snapshot.requireData.settings,
                      title: 'Veri Kullanımı',
                      values: const ['Düşük', 'Standart', 'Yüksek'],
                      apply: (settings, value) => AppSettings(
                        displayMode: settings.displayMode,
                        language: settings.language,
                        textSize: settings.textSize,
                        soundAndHaptics: settings.soundAndHaptics,
                        dataUsage: value,
                        offlineMode: settings.offlineMode,
                        caseDownloadsEnabled: settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.wifi_off_rounded,
                    'Çevrimdışı Mod',
                    enabled: snapshot.requireData.settings.offlineMode,
                    onTap: () => _saveSettings(
                      AppSettings(
                        displayMode: snapshot.requireData.settings.displayMode,
                        language: snapshot.requireData.settings.language,
                        textSize: snapshot.requireData.settings.textSize,
                        soundAndHaptics:
                            snapshot.requireData.settings.soundAndHaptics,
                        dataUsage: snapshot.requireData.settings.dataUsage,
                        offlineMode: !snapshot.requireData.settings.offlineMode,
                        caseDownloadsEnabled:
                            snapshot.requireData.settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.text_snippet_outlined,
                    'Vaka İndirmeleri',
                    enabled: snapshot.requireData.settings.caseDownloadsEnabled,
                    onTap: () => _saveSettings(
                      AppSettings(
                        displayMode: snapshot.requireData.settings.displayMode,
                        language: snapshot.requireData.settings.language,
                        textSize: snapshot.requireData.settings.textSize,
                        soundAndHaptics:
                            snapshot.requireData.settings.soundAndHaptics,
                        dataUsage: snapshot.requireData.settings.dataUsage,
                        offlineMode: snapshot.requireData.settings.offlineMode,
                        caseDownloadsEnabled:
                            !snapshot.requireData.settings.caseDownloadsEnabled,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Destek',
                rows: [
                  _SettingsRow(
                    Icons.help_outline_rounded,
                    'Yardım Merkezi',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HelpCenterScreen(repository: widget.repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.mail_outline_rounded,
                    'Bize Ulaşın',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ContactScreen(repository: widget.repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.info_outline_rounded,
                    'Hakkında',
                    value: _appVersion,
                    onTap: () => _showInfo(
                      context,
                      'Hakkında',
                      'PratiCase, Medasi ekosistemi için eğitim amaçlı OSCE simülasyon uygulamasıdır. Klinik karar desteği, tanı veya tedavi önerisi yerine öğrencinin sınav performansını geliştirmeye odaklanır.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Semantics(
                identifier: 'menu.logout',
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        fullscreenDialog: true,
                        builder: (_) => const LogoutConfirmScreen(),
                      ),
                    );
                    if (confirmed == true) await widget.onSignOut();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PratiCaseColors.errorRed,
                    side: const BorderSide(color: PratiCaseColors.errorRed),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Çıkış Yap'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _chooseSetting(
    AppSettings settings, {
    required String title,
    required List<String> values,
    required AppSettings Function(AppSettings settings, String value) apply,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final value in values)
              ListTile(
                title: Text(value),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _saveSettings(apply(settings, selected));
  }

  Future<void> _saveSettings(AppSettings settings) async {
    try {
      await widget.repository.saveAppSettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ayarlar kaydedildi.')));
      await _refresh();
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    this.onChanged,
    super.key,
  });

  final ProgressRepository repository;
  final Future<void> Function()? onChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({
    required this.authRepository,
    required this.profile,
    super.key,
  });

  final AuthRepository authRepository;
  final ProfileCard profile;

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _sendingReset = false;

  Future<void> _sendResetCode() async {
    if (_sendingReset) return;
    setState(() => _sendingReset = true);
    try {
      await widget.authRepository.sendPasswordResetCode(widget.profile.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Şifre sıfırlama bağlantısı ${widget.profile.email} adresine gönderildi.',
          ),
        ),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProgressPage(
      title: 'Hesap ve Güvenlik',
      children: [
        _InfoCard(
          icon: Icons.verified_user_outlined,
          title: 'Hesap Güvenliği',
          body:
              'Oturum, e-posta doğrulama ve şifre işlemlerini buradan yönetebilirsin.',
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Oturum',
          rows: [
            _SettingsRow(
              Icons.alternate_email_rounded,
              'Hesap E-postası',
              value: widget.profile.email,
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: widget.profile.email),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-posta panoya kopyalandı.')),
                );
              },
            ),
            _SettingsRow(
              Icons.password_rounded,
              _sendingReset
                  ? 'Şifre bağlantısı gönderiliyor'
                  : 'Şifre Sıfırlama Bağlantısı Gönder',
              value: _sendingReset ? 'Bekle' : 'Gönder',
              onTap: _sendingReset ? null : _sendResetCode,
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;
  late Future<List<NotificationCard>> _notificationsFuture;
  StreamSubscription<List<NotificationCard>>? _notificationsSubscription;
  bool _receivedInitialStreamEvent = false;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = widget.repository.loadNotifications();
    _notificationsSubscription = widget.repository.watchNotifications().listen((
      notifications,
    ) {
      if (!mounted) return;
      setState(() {
        _notificationsFuture = Future.value(notifications);
      });
      if (_receivedInitialStreamEvent) {
        unawaited(widget.onChanged?.call());
      }
      _receivedInitialStreamEvent = true;
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = widget.repository.loadNotifications();
    });
    await _notificationsFuture;
    await widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NotificationCard>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <NotificationCard>[];
        final visible = switch (_selectedFilter) {
          1 => notifications.where((item) => !item.isRead).toList(),
          2 => notifications.where((item) => item.isRead).toList(),
          _ => notifications,
        };
        return _ProgressPage(
          title: 'Bildirim Merkezi',
          onRefresh: _refresh,
          children: [
            _NotificationsHero(
              notifications: notifications,
              onMarkAllRead: _markAllRead,
            ),
            const SizedBox(height: 16),
            _SegmentHeader(
              items: const ['Tümü', 'Okunmamış', 'Okunan'],
              selectedIndex: _selectedFilter,
              onSelected: (index) => setState(() => _selectedFilter = index),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.notifications_none_rounded,
                title: 'Bildirimler yükleniyor',
                body: 'Bildirimler yükleniyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Bildirimler açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (visible.isEmpty)
              const _StateBlock(
                icon: Icons.notifications_none_rounded,
                title: 'Bu filtrede bildirim yok',
                body: 'Yeni bildirimler oluştuğunda burada listelenir.',
              )
            else
              for (final item in visible) ...[
                _NotificationTile(
                  item: item,
                  onTap: item.isRead ? null : () => _markRead(item.id),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  Future<void> _markRead(String id) async {
    try {
      await widget.repository.markNotificationRead(id);
      await _refresh();
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _markAllRead() async {
    final notifications = await _notificationsFuture;
    final unread = notifications.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    try {
      await widget.repository.markAllNotificationsRead();
      await _refresh();
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class FavoriteCasesScreen extends StatelessWidget {
  const FavoriteCasesScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _CaseCollectionPage(
      title: 'Favori Vakalarım',
      future: repository.loadFavoriteCases(),
      mode: _CaseCollectionMode.favorites,
      emptyTitle: 'Favori vaka yok',
      emptyBody:
          'Vaka detayından favoriye eklediğin istasyonlar burada görünür.',
    );
  }
}

class CaseHistoryScreen extends StatelessWidget {
  const CaseHistoryScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _CaseCollectionPage(
      title: 'Vaka Geçmişim',
      future: repository.loadCaseHistory(),
      mode: _CaseCollectionMode.history,
      emptyTitle: 'Vaka geçmişi yok',
      emptyBody:
          'Başlatılan OSCE oturumları ve tamamlanma durumları burada listelenir.',
    );
  }
}

class WeakAreaAnalysisScreen extends StatelessWidget {
  const WeakAreaAnalysisScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      (ProfileCard, ClinicalProgressSummary, List<CaseCollectionItem>)
    >(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ProgressPage(
            title: 'Zayıf Alan Analizi',
            children: [
              _StateBlock(
                icon: Icons.track_changes_rounded,
                title: 'Analiz hazırlanıyor',
                body: 'Performans verisi ve vaka geçmişin hazırlanıyor.',
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return _ProgressPage(
            title: 'Zayıf Alan Analizi',
            children: [
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Analiz açılamadı',
                body: _errorText(snapshot.error),
              ),
            ],
          );
        }

        final profile = snapshot.requireData.$1;
        final summary = snapshot.requireData.$2;
        final history = snapshot.requireData.$3;
        final weakest = _weakAreas(summary, history);
        final repeatCases = history
            .where(
              (item) =>
                  (item.score ?? 100) < 75 ||
                  (item.progressPercent ?? 100) < 100,
            )
            .take(4)
            .toList();

        return _ProgressPage(
          title: 'Zayıf Alan Analizi',
          children: [
            _WeakHero(profile: profile),
            const SizedBox(height: 16),
            const _SegmentHeader(items: ['Zayıf Alanlar', 'Tekrar', 'Hedef']),
            const SizedBox(height: 16),
            for (final area in weakest) ...[
              _WeakAreaCard(area: area),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text(
              'Tekrar Önerilen Vakalar',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (repeatCases.isEmpty)
              const _StateBlock(
                icon: Icons.verified_rounded,
                title: 'Tekrar gerektiren vaka yok',
                body:
                    'Tamamlanan vakalar eklendikçe öneriler burada güncellenir.',
              )
            else
              for (final item in repeatCases) ...[
                _CaseCollectionTile(item: item, history: true),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  Future<(ProfileCard, ClinicalProgressSummary, List<CaseCollectionItem>)>
  _load() async {
    final profile = repository.loadProfile();
    final summary = repository.loadClinicalProgressSummary();
    final history = repository.loadCaseHistory();
    return (await profile, await summary, await history);
  }

  List<_WeakArea> _weakAreas(
    ClinicalProgressSummary summary,
    List<CaseCollectionItem> history,
  ) {
    final incomplete = history
        .where((item) => (item.progressPercent ?? 100) < 100)
        .length;
    final lowScore = history.where((item) => (item.score ?? 100) < 75).length;
    if (summary.sessionCount == 0) {
      return const [
        _WeakArea(
          title: 'Anamnez Derinliği',
          percent: 0,
          note: 'Tamamlanan oturum sonucu henüz bulunmuyor.',
        ),
        _WeakArea(
          title: 'Ayırıcı Tanı',
          percent: 0,
          note: 'Tamamlanan oturum sonucu henüz bulunmuyor.',
        ),
        _WeakArea(
          title: 'Yönetim Planı',
          percent: 0,
          note: 'Tamamlanan oturum sonucu henüz bulunmuyor.',
        ),
      ];
    }
    return [
      _WeakArea(
        title: 'Anamnez Derinliği',
        percent: summary.percentFor('history'),
        note: incomplete > 0
            ? '$incomplete oturumda anamnez sonrası akış tamamlanmamış.'
            : 'Kırmızı bayrak ve sistem sorgusunu düzenli tekrar et.',
      ),
      _WeakArea(
        title: 'Ayırıcı Tanı',
        percent: summary.percentFor('diagnosis'),
        note: 'En az 3 kritik ön tanıyı gerekçesiyle yazmaya odaklan.',
      ),
      _WeakArea(
        title: 'Yönetim Planı',
        percent: summary.percentFor('management'),
        note: lowScore > 0
            ? '$lowScore düşük skorlu vaka yönetim planı tekrarı istiyor.'
            : 'Acil yaklaşım, danışma ve izlem adımlarını netleştir.',
      ),
    ];
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<SimpleContentItem>(
      title: 'Yardım ve Destek',
      future: repository.loadSupportTopics(),
      emptyTitle: 'Yardım başlığı yok',
      emptyBody: 'Destek içerikleri hazır olduğunda burada görünecek.',
      header: _SupportQuickActions(repository: repository),
      itemBuilder: (item) => _SimpleTile(item: item),
    );
  }
}

class DailyGoalsScreen extends StatelessWidget {
  const DailyGoalsScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCard>(
      future: repository.loadProfile(),
      builder: (context, snapshot) {
        return _ProgressPage(
          title: 'Günlük Hedefler',
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.local_fire_department_outlined,
                title: 'Hedefler yükleniyor',
                body: 'Günlük hedef ve seri bilgin hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Hedefler açılamadı',
                body: _errorText(snapshot.error),
              )
            else ...[
              _DailyGoalHero(profile: snapshot.requireData),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Bugünkü Plan',
                rows: [
                  _SettingsRow(
                    Icons.timer_outlined,
                    'Tek İstasyon',
                    value: '${snapshot.requireData.dailyGoal} vaka',
                    onTap: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Günlük hedef için Sınavlar ekranından tek istasyon başlat.',
                          ),
                        ),
                      );
                    },
                  ),
                  _SettingsRow(
                    Icons.fact_check_outlined,
                    'Tanı Tekrarı',
                    value: '3 ön tanı',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            WeakAreaAnalysisScreen(repository: repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.insights_outlined,
                    'Gelişim Kontrolü',
                    value: '%${snapshot.requireData.successRatePercent}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            WeakAreaAnalysisScreen(repository: repository),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<SimpleContentItem>(
      title: 'Sık Sorulan Sorular',
      future: repository.loadFaqItems(),
      emptyTitle: 'SSS yok',
      emptyBody: 'Sık sorulan sorular hazır olduğunda burada görünecek.',
      itemBuilder: (item) => _FaqTile(item: item),
    );
  }
}

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<SimpleContentItem>(
      title: 'Duyurular',
      future: repository.loadAnnouncements(),
      emptyTitle: 'Duyuru yok',
      emptyBody: 'Yeni duyurular yayınlandığında burada görünecek.',
      itemBuilder: (item) => _SimpleTile(item: item),
    );
  }
}

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<SimpleContentItem>(
      title: 'Verilerim',
      future: repository.loadUserDataOverview(),
      emptyTitle: 'Veri başlığı yok',
      emptyBody: 'Hesabına ait veri özetleri hazır olduğunda burada görünür.',
      itemBuilder: (item) => _SimpleTile(item: item),
      footer: _ExportDataTile(repository: repository),
    );
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _NotesPage(repository: repository);
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<(ProfileCard, List<CaseCollectionItem>, List<CaseCollectionItem>)>
  _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(ProfileCard, List<CaseCollectionItem>, List<CaseCollectionItem>)>
  _load() async {
    final profile = widget.repository.loadProfile();
    final favorites = widget.repository.loadFavoriteCases();
    final history = widget.repository.loadCaseHistory();
    return (await profile, await favorites, await history);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _toggleDownloads(ProfileCard profile) async {
    if (_saving) return;
    setState(() => _saving = true);
    final settings = profile.settings;
    try {
      await widget.repository.saveAppSettings(
        AppSettings(
          displayMode: settings.displayMode,
          language: settings.language,
          textSize: settings.textSize,
          soundAndHaptics: settings.soundAndHaptics,
          dataUsage: settings.dataUsage,
          offlineMode: settings.offlineMode,
          caseDownloadsEnabled: !settings.caseDownloadsEnabled,
        ),
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.caseDownloadsEnabled
                ? 'Vaka indirmeleri kapatıldı.'
                : 'Vaka indirmeleri açıldı.',
          ),
        ),
      );
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      (ProfileCard, List<CaseCollectionItem>, List<CaseCollectionItem>)
    >(
      future: _future,
      builder: (context, snapshot) {
        return _ProgressPage(
          title: 'İndirmelerim',
          onRefresh: _refresh,
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.download_rounded,
                title: 'İndirme ayarları yükleniyor',
                body: 'Favori ve geçmiş vaka paketlerin hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'İndirmeler açılamadı',
                body: _errorText(snapshot.error),
              )
            else ...[
              _DownloadsHero(
                profile: snapshot.requireData.$1,
                favorites: snapshot.requireData.$2,
                history: snapshot.requireData.$3,
                saving: _saving,
                onToggle: () => _toggleDownloads(snapshot.requireData.$1),
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Çevrimdışı Hazırlık',
                rows: [
                  _SettingsRow(
                    Icons.favorite_border_rounded,
                    'Favori Vakalar',
                    value: '${snapshot.requireData.$2.length} vaka',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FavoriteCasesScreen(repository: widget.repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.history_rounded,
                    'Son Oturumlar',
                    value: '${snapshot.requireData.$3.length} kayıt',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CaseHistoryScreen(repository: widget.repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.wifi_off_rounded,
                    'Çevrimdışı Mod',
                    value: snapshot.requireData.$1.settings.offlineMode
                        ? 'Açık'
                        : 'Kapalı',
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'İndirmeye Hazır Vakalar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              if (snapshot.requireData.$2.isEmpty)
                const _StateBlock(
                  icon: Icons.favorite_border_rounded,
                  title: 'İndirilecek favori vaka yok',
                  body:
                      'Vaka detayından favori eklediğinde çevrimdışı hazırlık listesi burada oluşur.',
                )
              else
                for (final item in snapshot.requireData.$2.take(6)) ...[
                  _CaseCollectionTile(item: item, compact: true),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        );
      },
    );
  }
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createContactRequest(
        subject: _subject.text,
        email: _email.text,
        message: _message.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesajınız alındı. En kısa sürede dönüş yapacağız.'),
        ),
      );
      Navigator.maybePop(context);
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProgressPage(
      title: 'İletişim / Bize Ulaşın',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              _FormFieldBlock(
                label: 'Konu',
                controller: _subject,
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              _FormFieldBlock(
                label: 'E-posta',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: _emailText,
              ),
              const SizedBox(height: 12),
              _FormFieldBlock(
                label: 'Mesajınız',
                controller: _message,
                maxLines: 7,
                validator: _requiredText,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _send,
                child: Text(_saving ? 'Gönderiliyor...' : 'Gönder'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bu alan zorunlu.';
    return null;
  }

  String? _emailText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'E-posta adresini gir.';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
      return 'Geçerli bir e-posta gir.';
    }
    return null;
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    required this.repository,
    required this.profile,
    super.key,
  });

  final ProgressRepository repository;
  final ProfileCard profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _specialty;
  late final TextEditingController _education;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _email = TextEditingController(text: widget.profile.email);
    _specialty = TextEditingController(text: widget.profile.target);
    _education = TextEditingController(text: widget.profile.classLevel);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _specialty.dispose();
    _education.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        !_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli profil bilgilerini gir.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.saveProfile(
        displayName: _name.text,
        email: _email.text,
        specialty: _specialty.text,
        educationLevel: _education.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil güncellendi.')));
      Navigator.maybePop(context);
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProgressPage(
      title: 'Profil Düzenleme',
      children: [
        Center(
          child: CircleAvatar(
            radius: 46,
            backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.14),
            child: Text(
              _initial(widget.profile.displayName),
              style: const TextStyle(
                color: PratiCaseColors.teal,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _FormFieldBlock(label: 'Ad Soyad', controller: _name),
        const SizedBox(height: 12),
        _FormFieldBlock(label: 'E-posta', controller: _email),
        const SizedBox(height: 12),
        _FormFieldBlock(label: 'Uzmanlık Alanı', controller: _specialty),
        const SizedBox(height: 12),
        _FormFieldBlock(label: 'Eğitim Seviyesi', controller: _education),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}

class LogoutConfirmScreen extends StatelessWidget {
  const LogoutConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PratiCaseColors.navy.withValues(alpha: 0.72),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: PratiCaseColors.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: PratiCaseColors.errorRed,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Çıkış Yapmak İstiyor musunuz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Oturumunuz sonlandırılacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PratiCaseColors.muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                Semantics(
                  identifier: 'cta.confirm-logout',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: PratiCaseColors.errorRed,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Çıkış Yap'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('İptal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPage extends StatelessWidget {
  const _ProgressPage({
    required this.title,
    required this.children,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = PratiCaseResponsiveListView(
      padding: PratiCaseResponsive.pagePadding(context, top: 18),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      body: SafeArea(
        bottom: false,
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}

class _LiveListPage<T> extends StatelessWidget {
  const _LiveListPage({
    required this.title,
    required this.future,
    required this.emptyTitle,
    required this.emptyBody,
    required this.itemBuilder,
    this.header,
    this.footer,
  });

  final String title;
  final Future<List<T>> future;
  final String emptyTitle;
  final String emptyBody;
  final Widget Function(T item) itemBuilder;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        return _ProgressPage(
          title: title,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 16)],
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.hourglass_empty_rounded,
                title: 'Yükleniyor',
                body: 'Bilgilerin hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Ekran açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (snapshot.requireData.isEmpty)
              _StateBlock(
                icon: Icons.inbox_outlined,
                title: emptyTitle,
                body: emptyBody,
              )
            else ...[
              for (final item in snapshot.requireData) ...[
                itemBuilder(item),
                const SizedBox(height: 10),
              ],
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ],
        );
      },
    );
  }
}

enum _CaseCollectionMode { favorites, history }

class _CaseCollectionPage extends StatefulWidget {
  const _CaseCollectionPage({
    required this.title,
    required this.future,
    required this.mode,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String title;
  final Future<List<CaseCollectionItem>> future;
  final _CaseCollectionMode mode;
  final String emptyTitle;
  final String emptyBody;

  @override
  State<_CaseCollectionPage> createState() => _CaseCollectionPageState();
}

class _CaseCollectionPageState extends State<_CaseCollectionPage> {
  final _searchController = TextEditingController();
  int _selectedFilter = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterItems = widget.mode == _CaseCollectionMode.history
        ? const ['Tümü', 'Tamamlanan', 'Devam', 'Düşük Skor']
        : const ['Tümü', 'Kolay', 'Orta', 'Zor'];
    return FutureBuilder<List<CaseCollectionItem>>(
      future: widget.future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CaseCollectionItem>[];
        final visible = _visibleItems(items, filterItems);
        return _ProgressPage(
          title: widget.title,
          children: [
            _CaseCollectionHero(items: items, mode: widget.mode),
            const SizedBox(height: 14),
            _SearchField(
              controller: _searchController,
              hintText: widget.mode == _CaseCollectionMode.history
                  ? 'Geçmişte vaka ara'
                  : 'Favorilerde vaka ara',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _SegmentHeader(
              items: filterItems,
              selectedIndex: _selectedFilter,
              onSelected: (index) => setState(() => _selectedFilter = index),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.hourglass_empty_rounded,
                title: 'Yükleniyor',
                body: 'Vaka kayıtların hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Ekran açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (items.isEmpty)
              _StateBlock(
                icon: widget.mode == _CaseCollectionMode.history
                    ? Icons.history_rounded
                    : Icons.favorite_border_rounded,
                title: widget.emptyTitle,
                body: widget.emptyBody,
              )
            else if (visible.isEmpty)
              const _StateBlock(
                icon: Icons.search_off_rounded,
                title: 'Sonuç bulunamadı',
                body: 'Arama veya filtreyi değiştirerek tekrar deneyebilirsin.',
              )
            else
              for (final item in visible) ...[
                _CaseCollectionTile(
                  item: item,
                  history: widget.mode == _CaseCollectionMode.history,
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  List<CaseCollectionItem> _visibleItems(
    List<CaseCollectionItem> items,
    List<String> filters,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filter = filters[_selectedFilter];
    return items.where((item) {
      final haystack = [
        item.title,
        item.branch,
        item.difficulty,
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      if (!matchesQuery) return false;
      if (filter == 'Tümü') return true;
      if (widget.mode == _CaseCollectionMode.favorites) {
        return item.difficulty.toLowerCase() == filter.toLowerCase();
      }
      if (filter == 'Tamamlanan') return (item.progressPercent ?? 0) >= 100;
      if (filter == 'Devam') return (item.progressPercent ?? 0) < 100;
      if (filter == 'Düşük Skor') return (item.score ?? 100) < 75;
      return true;
    }).toList();
  }
}

class _NotesPage extends StatefulWidget {
  const _NotesPage({required this.repository});

  final ProgressRepository repository;

  @override
  State<_NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<_NotesPage> {
  final _searchController = TextEditingController();
  late Future<List<UserNote>> _future;
  String _selectedCategory = 'Tümü';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.loadNotes();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserNote>>(
      future: _future,
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const <UserNote>[];
        final categories = [
          'Tümü',
          ...{
            for (final note in notes)
              if (note.category.trim().isNotEmpty) note.category.trim(),
          },
        ];
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = 'Tümü';
        }
        final visible = _visibleNotes(notes);
        return _ProgressPage(
          title: 'Notlarım',
          onRefresh: _refresh,
          children: [
            _NotesHero(notes: notes),
            const SizedBox(height: 14),
            _SearchField(
              controller: _searchController,
              hintText: 'Notlarda ara',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _FilterChips(
              items: categories,
              selected: _selectedCategory,
              onSelected: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.note_alt_outlined,
                title: 'Notlar yükleniyor',
                body: 'OSCE odasında aldığın notlar hazırlanıyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Notlar açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (notes.isEmpty)
              const _StateBlock(
                icon: Icons.note_alt_outlined,
                title: 'Kayıtlı not yok',
                body: 'OSCE odasında eklediğin vaka notları burada görünür.',
              )
            else if (visible.isEmpty)
              const _StateBlock(
                icon: Icons.search_off_rounded,
                title: 'Not bulunamadı',
                body: 'Arama veya kategori filtresini değiştir.',
              )
            else
              for (final note in visible) ...[
                _NoteTile(item: note),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  List<UserNote> _visibleNotes(List<UserNote> notes) {
    final query = _searchController.text.trim().toLowerCase();
    return notes.where((note) {
      final matchesCategory =
          _selectedCategory == 'Tümü' || note.category == _selectedCategory;
      final haystack = [
        note.title,
        note.body,
        note.category,
        note.caseTitle ?? '',
      ].join(' ').toLowerCase();
      return matchesCategory && (query.isEmpty || haystack.contains(query));
    }).toList();
  }
}

class _SegmentHeader extends StatelessWidget {
  const _SegmentHeader({
    required this.items,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: InkWell(
                onTap: onSelected == null ? null : () => onSelected!(index),
                borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == selectedIndex
                        ? PratiCaseColors.teal
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      items[index],
                      style: TextStyle(
                        color: index == selectedIndex
                            ? PratiCaseColors.white
                            : PratiCaseColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Temizle',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            ChoiceChip(
              label: Text(item),
              selected: selected == item,
              onSelected: (_) => onSelected(item),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CaseCollectionHero extends StatelessWidget {
  const _CaseCollectionHero({required this.items, required this.mode});

  final List<CaseCollectionItem> items;
  final _CaseCollectionMode mode;

  @override
  Widget build(BuildContext context) {
    final completed = items
        .where((item) => (item.progressPercent ?? 0) >= 100)
        .length;
    final average = _averageScore(items);
    final title = mode == _CaseCollectionMode.history
        ? 'OSCE Yolculuğun'
        : 'Klinik Kısa Listen';
    final body = mode == _CaseCollectionMode.history
        ? 'Tamamlanan ve devam eden istasyonlarını tek yerden izle.'
        : 'Tekrar çözmek istediğin vakaları sınav öncesi hızlıca aç.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PratiCaseColors.gradientStart, PratiCaseColors.gradientEnd],
        ),
        borderRadius: BorderRadius.all(Radius.circular(PratiCaseRadius.xxl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: PratiCaseColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                mode == _CaseCollectionMode.history
                    ? Icons.timeline_rounded
                    : Icons.favorite_rounded,
                color: PratiCaseColors.tealBright,
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.8),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: mode == _CaseCollectionMode.history
                      ? 'Toplam Oturum'
                      : 'Favori Vaka',
                  value: '${items.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: mode == _CaseCollectionMode.history
                      ? 'Tamamlanan'
                      : 'Branş',
                  value: mode == _CaseCollectionMode.history
                      ? '$completed'
                      : '${_distinctBranches(items)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: mode == _CaseCollectionMode.history
                      ? 'Ortalama'
                      : 'Toplam Puan',
                  value: mode == _CaseCollectionMode.history
                      ? (average == null ? '-' : '%$average')
                      : '${items.fold<int>(0, (sum, item) => sum + item.points)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesHero extends StatelessWidget {
  const _NotesHero({required this.notes});

  final List<UserNote> notes;

  @override
  Widget build(BuildContext context) {
    final caseLinked = notes.where((note) => note.caseTitle != null).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: PratiCaseColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
            ),
            child: const Icon(
              Icons.note_alt_rounded,
              color: PratiCaseColors.gold,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Klinik Not Defteri',
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${notes.length} not • $caseLinked vaka bağlantılı',
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontWeight: FontWeight.w700,
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

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({
    required this.notifications,
    required this.onMarkAllRead,
  });

  final List<NotificationCard> notifications;
  final Future<void> Function() onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((item) => !item.isRead).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: PratiCaseColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: PratiCaseColors.teal,
                  size: 30,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PratiCaseColors.gold,
                      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildirim Kutusu',
                  style: TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  unread == 0
                      ? 'Okunmamış bildirimin yok.'
                      : '$unread okunmamış bildirim var.',
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: unread == 0 ? null : onMarkAllRead,
            child: const Text('Tümünü Oku'),
          ),
        ],
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.all(Radius.circular(PratiCaseRadius.xxl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uygulama Tercihleri',
            style: TextStyle(
              color: PratiCaseColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sınav odağı, erişilebilirlik ve veri kullanımını buradan yönet.',
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.8),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.visibility_outlined,
                label: settings.displayMode,
              ),
              _StatusPill(
                icon: Icons.text_fields_rounded,
                label: settings.textSize,
              ),
              _StatusPill(
                icon: Icons.data_usage_rounded,
                label: settings.dataUsage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadsHero extends StatelessWidget {
  const _DownloadsHero({
    required this.profile,
    required this.favorites,
    required this.history,
    required this.saving,
    required this.onToggle,
  });

  final ProfileCard profile;
  final List<CaseCollectionItem> favorites;
  final List<CaseCollectionItem> history;
  final bool saving;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = profile.settings.caseDownloadsEnabled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: enabled ? PratiCaseColors.navy : PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        border: Border.all(
          color: enabled
              ? PratiCaseColors.tealBright.withValues(alpha: 0.5)
              : PratiCaseColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  enabled ? 'İndirmeler Açık' : 'İndirmeler Kapalı',
                  style: TextStyle(
                    color: enabled ? Colors.white : PratiCaseColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: saving ? null : (_) => onToggle(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Favori vakalar ve son oturumlar çevrimdışı çalışma hazırlığı için listelenir.',
            style: TextStyle(
              color: enabled
                  ? PratiCaseColors.white.withValues(alpha: 0.8)
                  : PratiCaseColors.muted,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Favori',
                  value: '${favorites.length}',
                  dark: enabled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Geçmiş',
                  value: '${history.length}',
                  dark: enabled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Veri',
                  value: profile.settings.dataUsage,
                  dark: enabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.dark = true,
  });

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? PratiCaseColors.white.withValues(alpha: 0.1)
            : PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(
          color: dark
              ? PratiCaseColors.white.withValues(alpha: 0.18)
              : PratiCaseColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: dark ? PratiCaseColors.white : PratiCaseColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: dark
                    ? PratiCaseColors.white.withValues(alpha: 0.72)
                    : PratiCaseColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PratiCaseColors.tealBright, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportQuickActions extends StatelessWidget {
  const _SupportQuickActions({required this.repository});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SupportActionButton(
                icon: Icons.quiz_outlined,
                label: 'SSS',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FaqScreen(repository: repository),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SupportActionButton(
                icon: Icons.campaign_outlined,
                label: 'Duyurular',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnnouncementsScreen(repository: repository),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SupportActionButton(
          icon: Icons.mail_outline_rounded,
          label: 'Bize Ulaşın',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContactScreen(repository: repository),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportActionButton extends StatelessWidget {
  const _SupportActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      child: Ink(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _cardDecoration(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: PratiCaseColors.teal),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeSummaryHero extends StatelessWidget {
  const _BadgeSummaryHero({required this.badges});

  final List<BadgeCard> badges;

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((badge) => badge.earned).length;
    final total = badges.length;
    final active = badges
        .where((badge) => !badge.earned && badge.progressCount > 0)
        .take(2)
        .toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PratiCaseColors.navy, PratiCaseColors.teal],
        ),
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kazanılan Toplam',
            style: TextStyle(
              color: PratiCaseColors.tealBright,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$earned',
                        style: const TextStyle(
                          color: PratiCaseColors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ' / $total Rozet',
                        style: TextStyle(
                          color: PratiCaseColors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.military_tech_rounded,
                color: PratiCaseColors.tealBright,
                size: 42,
              ),
            ],
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final badge in active) ...[
              _BadgeProgressLine(badge: badge),
              if (badge != active.last) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _BadgeProgressLine extends StatelessWidget {
  const _BadgeProgressLine({required this.badge});

  final BadgeCard badge;

  @override
  Widget build(BuildContext context) {
    final progress = badge.targetCount == 0
        ? 0.0
        : (badge.progressCount / badge.targetCount).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                badge.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${badge.progressCount}/${badge.targetCount}',
              style: TextStyle(
                color: PratiCaseColors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: PratiCaseColors.white.withValues(alpha: 0.24),
            color: PratiCaseColors.tealBright,
          ),
        ),
      ],
    );
  }
}

class _BadgeCardView extends StatelessWidget {
  const _BadgeCardView({required this.badge});

  final BadgeCard badge;

  @override
  Widget build(BuildContext context) {
    final progress = badge.targetCount == 0
        ? 0.0
        : (badge.progressCount / badge.targetCount).clamp(0.0, 1.0);
    final color = _tierColor(badge.tier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _MedalIcon(color: color, earned: badge.earned),
          const SizedBox(height: 12),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: PratiCaseColors.surfaceContainerHighest,
            color: color,
            minHeight: 5,
          ),
          const SizedBox(height: 6),
          Text(
            '${badge.progressCount} / ${badge.targetCount}',
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopThree extends StatelessWidget {
  const _TopThree({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final podium = [
      ...entries.where((entry) => entry.rank == 2),
      ...entries.where((entry) => entry.rank == 1),
      ...entries.where((entry) => entry.rank == 3),
    ];
    if (podium.isEmpty) podium.addAll(entries);
    return SizedBox(
      height: 188,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in podium.take(3)) ...[
            Expanded(child: _PodiumCard(entry: entry)),
            if (entry != podium.take(3).last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final isFirst = entry.rank == 1;
    return Container(
      height: isFirst ? 168 : 146,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(
          color: isFirst
              ? PratiCaseColors.gold.withValues(alpha: 0.62)
              : PratiCaseColors.border,
          width: isFirst ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: isFirst ? 34 : 28,
                backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.14),
                child: Text(
                  _initial(entry.displayName),
                  style: const TextStyle(
                    color: PratiCaseColors.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFirst ? PratiCaseColors.gold : PratiCaseColors.navy,
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                ),
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: isFirst
                        ? PratiCaseColors.navy
                        : PratiCaseColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${entry.totalPoints}',
            style: TextStyle(
              color: isFirst ? PratiCaseColors.gold : PratiCaseColors.teal,
              fontSize: isFirst ? 20 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${entry.solvedCaseCount} vaka',
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? PratiCaseColors.teal.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      ),
      child: ListTile(
        leading: Text(
          '${entry.rank}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        title: Text(entry.displayName),
        trailing: Text('${entry.totalPoints} puan'),
      ),
    );
  }
}

class _RankSummary extends StatelessWidget {
  const _RankSummary({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MiniMetric(label: 'Toplam Puanın', value: '${entry.totalPoints}'),
          _MiniMetric(
            label: 'Çözdüğün Vaka',
            value: '${entry.solvedCaseCount}',
          ),
          _MiniMetric(
            label: 'Doğru Tanı',
            value: '%${entry.correctDiagnosisRate}',
          ),
        ],
      ),
    );
  }
}

class _ProfileBrandHeader extends StatelessWidget {
  const _ProfileBrandHeader({
    required this.repository,
    required this.profile,
    required this.unreadNotificationCount,
    this.onOpenNotifications,
  });

  final ProgressRepository repository;
  final ProfileCard profile;
  final int unreadNotificationCount;
  final VoidCallback? onOpenNotifications;

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
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              children: [
                TextSpan(text: 'Prati'),
                TextSpan(
                  text: 'Case',
                  style: TextStyle(color: PratiCaseColors.teal),
                ),
              ],
            ),
          ),
        ),
        _ProfileNotificationBell(
          count: unreadNotificationCount,
          onTap:
              onOpenNotifications ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificationsScreen(repository: repository),
                ),
              ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 22,
          backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.12),
          child: Text(
            _initial(
              profile.displayName.trim().isEmpty
                  ? profile.email
                  : profile.displayName,
            ),
            style: const TextStyle(
              color: PratiCaseColors.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileNotificationBell extends StatelessWidget {
  const _ProfileNotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Bildirimler',
          onPressed: onTap,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: PratiCaseColors.navy,
            size: 30,
          ),
        ),
        if (count > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: const BoxDecoration(
                color: PratiCaseColors.gold,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    final avatarTitle = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'PratiCase Öğrencisi';
    final subtitle = [
      profile.target,
      profile.classLevel,
    ].where((e) => e.trim().isNotEmpty).join(' • ');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        boxShadow: PratiCaseShadows.floating,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
              child: CustomPaint(painter: _ProfileHeroPatternPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: PratiCaseColors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PratiCaseColors.white.withValues(alpha: 0.24),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initial(avatarTitle),
                      style: const TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          avatarTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PratiCaseColors.white,
                            fontSize: 21,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PratiCaseColors.white.withValues(
                                alpha: 0.78,
                              ),
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
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
                      Icons.verified_user_outlined,
                      color: PratiCaseColors.tealBright,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'PratiCase Üyesi',
                      style: TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ProfileHeroMetric(
                      label: 'Ortalama',
                      value: '%${profile.successRatePercent}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProfileHeroMetric(
                      label: 'Seri',
                      value: '${profile.dailyStreak} gün',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProfileHeroMetric(
                      label: 'Puan',
                      value: '${profile.totalPoints}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = PratiCaseColors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const step = 16.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileHeroMetric extends StatelessWidget {
  const _ProfileHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: PratiCaseColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePlanPanel extends StatelessWidget {
  const _ProfilePlanPanel({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    final branches = profile.targetBranches
        .where((branch) => branch.trim().isNotEmpty)
        .take(3)
        .join(', ');
    final targetBranches = branches.isNotEmpty
        ? branches
        : (profile.target.isEmpty ? '-' : profile.target);
    return PratiCaseGroupedSection(
      title: 'Hedef Planı',
      subtitle: 'Profil kurulumu ve günlük çalışma ayarlarının özeti.',
      icon: Icons.flag_outlined,
      children: [
        _ProfilePlanTile(
          icon: Icons.local_hospital_outlined,
          title: 'Hedef Branşlar',
          value: targetBranches,
          accent: PratiCaseColors.teal,
        ),
        _ProfilePlanTile(
          icon: Icons.local_fire_department_outlined,
          title: 'Günlük Hedef',
          value: '${profile.dailyGoal} istasyon',
          accent: PratiCaseColors.gold,
        ),
        _ProfilePlanTile(
          icon: Icons.event_note_outlined,
          title: 'OSCE Sınav Tarihi',
          value: profile.osceExamDate == null
              ? 'Belirlenmedi'
              : _shortDate(profile.osceExamDate!),
          accent: PratiCaseColors.slateBlue,
        ),
      ],
    );
  }
}

class _ProfilePlanTile extends StatelessWidget {
  const _ProfilePlanTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
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

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    final tiles = <_PremiumStatData>[
      _PremiumStatData(
        icon: Icons.check_circle_outline_rounded,
        accent: PratiCaseColors.teal,
        label: 'Çözdüğüm Vaka',
        value: '${profile.solvedCaseCount}',
      ),
      _PremiumStatData(
        icon: Icons.workspace_premium_rounded,
        accent: PratiCaseColors.slateBlue,
        label: 'Toplam Puan',
        value: _formatPoints(profile.totalPoints),
      ),
      _PremiumStatData(
        icon: Icons.medical_services_outlined,
        accent: PratiCaseColors.successGreen,
        label: 'Doğru Tanı',
        value: '%${profile.correctDiagnosisRate}',
      ),
      _PremiumStatData(
        icon: Icons.trending_up_rounded,
        accent: PratiCaseColors.teal,
        label: 'Ortalama',
        value: '%${profile.successRatePercent}',
      ),
      _PremiumStatData(
        icon: Icons.local_fire_department_rounded,
        accent: PratiCaseColors.gold,
        label: 'Seri',
        value: '${profile.dailyStreak} gün',
      ),
      _PremiumStatData(
        icon: Icons.school_outlined,
        accent: PratiCaseColors.slateBlue,
        label: 'Sınıf',
        value: profile.classLevel.isEmpty ? '-' : profile.classLevel,
      ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.insights_rounded,
                color: PratiCaseColors.teal,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'İstatistiklerim',
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 2 : 3;
              const spacing = 10.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final tile in tiles)
                    SizedBox(
                      width: width,
                      child: _PremiumStatTile(data: tile),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatPoints(int value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K';
    }
    return '$value';
  }
}

class _PremiumStatData {
  const _PremiumStatData({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
}

class _PremiumStatTile extends StatelessWidget {
  const _PremiumStatTile({required this.data});

  final _PremiumStatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: data.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.accent, size: 16),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              maxLines: 1,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.authRepository,
    required this.repository,
    required this.items,
    required this.onSignOut,
    required this.storeControllerFactory,
    required this.unreadNotificationCount,
    this.onOpenNotifications,
  });

  final AuthRepository authRepository;
  final ProgressRepository repository;
  final List<_MenuItem> items;
  final Future<void> Function() onSignOut;
  final StoreController Function() storeControllerFactory;
  final int unreadNotificationCount;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final byTitle = {for (final item in items) item.title: item};
    final sections = [
      (
        'Çalışma Alanım',
        'Vaka, favori, not ve günlük hedefler.',
        Icons.school_outlined,
        ['Vaka Geçmişim', 'Favori Vakalarım', 'Notlarım', 'Günlük Hedefler'],
      ),
      (
        'Performans',
        'Sıralama, rozet ve bildirim takibi.',
        Icons.insights_outlined,
        ['Liderlik Tablosu', 'Başarılarım', 'Bildirimler'],
      ),
      (
        'Hesap ve Mağaza',
        'Abonelik, mağaza, ayarlar ve çevrimdışı hazırlık.',
        Icons.manage_accounts_outlined,
        ['Mağaza', 'Premium Abonelik', 'Ayarlar', 'İndirmelerim'],
      ),
    ];
    return Column(
      children: [
        for (final section in sections) ...[
          PratiCaseGroupedSection(
            title: section.$1,
            subtitle: section.$2,
            icon: section.$3,
            children: [
              for (final title in section.$4)
                if (byTitle[title] != null)
                  _ProfileMenuTile(
                    item: byTitle[title]!,
                    onTap: () => _openMenu(context, byTitle[title]!.title),
                  ),
            ],
          ),
          if (section != sections.last) const SizedBox(height: 14),
        ],
      ],
    );
  }

  void _openMenu(BuildContext context, String title) {
    if (title == 'Vaka Geçmişim') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaseHistoryScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Favori Vakalarım') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FavoriteCasesScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Notlarım') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotesScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Günlük Hedefler') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DailyGoalsScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Liderlik Tablosu') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LeaderboardScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Bildirimler') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Başarılarım') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BadgesScreen(repository: repository),
        ),
      );
      return;
    }
    if (title == 'Mağaza') {
      final controller = storeControllerFactory();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WalletScreen(
            controller: controller,
            unreadNotificationCount: unreadNotificationCount,
            onOpenNotifications: onOpenNotifications ?? () {},
            onOpenProfile: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
      return;
    }
    if (title == 'Premium Abonelik') {
      final controller = storeControllerFactory();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubscriptionStatusScreen(controller: controller),
        ),
      );
      return;
    }
    if (title == 'Ayarlar') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            authRepository: authRepository,
            repository: repository,
            onSignOut: onSignOut,
          ),
        ),
      );
      return;
    }
    if (title == 'İndirmelerim') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DownloadsScreen(repository: repository),
        ),
      );
      return;
    }
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({required this.item, required this.onTap});

  final _MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: item.semanticsId ?? '',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: PratiCaseColors.teal.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                  ),
                  child: Icon(item.icon, color: PratiCaseColors.teal, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: PratiCaseColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PratiCaseColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyGoalHero extends StatelessWidget {
  const _DailyGoalHero({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    final progress = (profile.solvedCaseCount % 3) / 3;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PratiCaseColors.gradientStart, PratiCaseColors.gradientEnd],
        ),
        borderRadius: BorderRadius.all(Radius.circular(PratiCaseRadius.xxl)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günlük Seri',
                  style: TextStyle(
                    color: PratiCaseColors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.dailyStreak} gün',
                  style: const TextStyle(
                    color: PratiCaseColors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress == 0 ? 1 : progress,
                    minHeight: 8,
                    backgroundColor: PratiCaseColors.white.withValues(
                      alpha: 0.24,
                    ),
                    color: PratiCaseColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Icon(
            Icons.local_fire_department_rounded,
            color: PratiCaseColors.gold,
            size: 54,
          ),
        ],
      ),
    );
  }
}

/// Settings ekranında "Görünüm" altında yer alan accent renk seçici kart.
/// PratiCaseAccent.instance üzerinden global accent'i değiştirir.
class _AccentPickerCard extends StatefulWidget {
  const _AccentPickerCard();

  @override
  State<_AccentPickerCard> createState() => _AccentPickerCardState();
}

class _AccentPickerCardState extends State<_AccentPickerCard> {
  @override
  void initState() {
    super.initState();
    PratiCaseAccent.instance.addListener(_onAccentChanged);
  }

  @override
  void dispose() {
    PratiCaseAccent.instance.removeListener(_onAccentChanged);
    super.dispose();
  }

  void _onAccentChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = PratiCaseAccent.instance.option;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Görünüm',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
            border: Border.all(
              color: PratiCaseColors.border.withValues(alpha: 0.78),
            ),
            boxShadow: PratiCaseShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: current.primary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(PratiCaseRadius.md),
                      border: Border.all(
                        color: current.primary.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Icon(Icons.palette_outlined,
                        color: current.primary, size: 19),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vurgu Rengi',
                          style: TextStyle(
                            color: PratiCaseColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Butonlar, ikonlar ve odak çerçeveleri seçimini kullanır.',
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
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final option in PratiCaseAccentOption.values) ...[
                    Expanded(
                      child: _AccentSwatch(
                        option: option,
                        selected: option == current,
                        onTap: () =>
                            PratiCaseAccent.instance.setOption(option),
                      ),
                    ),
                    if (option != PratiCaseAccentOption.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PratiCaseAccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? option.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          border: Border.all(
            color: selected
                ? option.primary
                : PratiCaseColors.border.withValues(alpha: 0.6),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [option.primary, option.bright],
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: option.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              style: TextStyle(
                color: selected ? option.primary : PratiCaseColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.rows});

  final String title;
  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: _cardDecoration(),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
    this.icon,
    this.title, {
    this.value,
    this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final bool? enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        enabled: onTap != null || enabled != null,
        leading: Icon(icon, color: PratiCaseColors.navy),
        title: Text(title),
        trailing: enabled == null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.34,
                      ),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: PratiCaseColors.muted),
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              )
            : Switch(
                value: enabled!,
                activeThumbColor: PratiCaseColors.teal,
                onChanged: onTap == null ? null : (_) => onTap!(),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, this.onTap});

  final NotificationCard item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: _cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  (item.isRead ? PratiCaseColors.muted : PratiCaseColors.gold)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
            ),
            child: Icon(
              item.isRead
                  ? Icons.notifications_none_rounded
                  : Icons.star_rounded,
              color: item.isRead ? PratiCaseColors.muted : PratiCaseColors.gold,
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_shortDate(item.createdAt)} • ${item.body}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: item.isRead
              ? const Icon(Icons.check_circle_outline_rounded)
              : const Text(
                  'Oku',
                  style: TextStyle(
                    color: PratiCaseColors.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.item});

  final UserNote item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PratiCaseColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                ),
                child: const Icon(
                  Icons.note_alt_outlined,
                  color: PratiCaseColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _shortDate(item.updatedAt),
                      style: const TextStyle(
                        color: PratiCaseColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallTag(label: item.category),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.ink,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.caseTitle != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.local_hospital_outlined,
                  color: PratiCaseColors.muted,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.caseTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportDataTile extends StatefulWidget {
  const _ExportDataTile({required this.repository});

  final ProgressRepository repository;

  @override
  State<_ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends State<_ExportDataTile> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final payload = await widget.repository.exportUserData();
      await Clipboard.setData(ClipboardData(text: payload));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı verisi panoya kopyalandı.')),
      );
    } on ProgressDataUnavailable catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _exporting ? null : _export,
      borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.ios_share_rounded, color: PratiCaseColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _exporting ? 'Dışa aktarılıyor...' : 'Veri Dışa Aktar',
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({required this.item});

  final SimpleContentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(
            Icons.article_outlined,
            color: PratiCaseColors.teal,
          ),
          title: Text(item.title),
          subtitle: item.body.isEmpty ? null : Text(item.body),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});

  final SimpleContentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          title: Text(item.title),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(item.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseCollectionTile extends StatelessWidget {
  const _CaseCollectionTile({
    required this.item,
    this.history = false,
    this.compact = false,
  });

  final CaseCollectionItem item;
  final bool history;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = ((item.progressPercent ?? 0) / 100).clamp(0.0, 1.0);
    final score = item.score;
    final scoreColor = score == null
        ? PratiCaseColors.muted
        : score >= 80
        ? PratiCaseColors.successGreen
        : score >= 60
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: PratiCaseColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
                ),
                child: Icon(
                  _caseIcon(item.iconKey),
                  color: PratiCaseColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.branch.isNotEmpty)
                          _SmallTag(label: _statusLabel(item.branch)),
                        if (item.difficulty.isNotEmpty)
                          _SmallTag(label: _statusLabel(item.difficulty)),
                        if (item.updatedAt != null)
                          _SmallTag(label: _shortDate(item.updatedAt!)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                history ? (score == null ? '-' : '$score') : '${item.points}',
                style: TextStyle(
                  color: history ? scoreColor : PratiCaseColors.teal,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (history && !compact) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: PratiCaseColors.surfaceContainerHighest,
                      color: progress >= 1
                          ? PratiCaseColors.successGreen
                          : PratiCaseColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '%${item.progressPercent ?? 0}',
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeakArea {
  const _WeakArea({
    required this.title,
    required this.percent,
    required this.note,
  });

  final String title;
  final int percent;
  final String note;
}

class _WeakHero extends StatelessWidget {
  const _WeakHero({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PratiCaseColors.gradientStart, PratiCaseColors.gradientEnd],
        ),
        borderRadius: BorderRadius.all(Radius.circular(PratiCaseRadius.xxl)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genel Başarı',
                  style: TextStyle(
                    color: PratiCaseColors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '%${profile.successRatePercent}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: PratiCaseColors.white,
                    fontSize: 52,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Zayıf başlıkları hedefli tekrar sınavına dönüştür.',
                  style: TextStyle(
                    color: PratiCaseColors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.track_changes_rounded,
            color: PratiCaseColors.tealBright,
            size: 68,
          ),
        ],
      ),
    );
  }
}

class _WeakAreaCard extends StatelessWidget {
  const _WeakAreaCard({required this.area});

  final _WeakArea area;

  @override
  Widget build(BuildContext context) {
    final color = area.percent >= 75
        ? PratiCaseColors.successGreen
        : area.percent >= 55
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  area.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                '%${area.percent}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
            child: LinearProgressIndicator(
              value: area.percent / 100,
              minHeight: 8,
              backgroundColor: PratiCaseColors.surfaceContainerHighest,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            area.note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PratiCaseColors.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldBlock extends StatelessWidget {
  const _FormFieldBlock({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: PratiCaseColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalIcon extends StatelessWidget {
  const _MedalIcon({required this.color, required this.earned});

  final Color color;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: earned ? 0.18 : 0.08),
        border: Border.all(color: color, width: earned ? 4 : 2),
      ),
      child: Icon(
        Icons.star_rounded,
        color: earned ? color : color.withValues(alpha: 0.45),
        size: 44,
      ),
    );
  }
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(icon, color: PratiCaseColors.teal, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
            ),
            child: Icon(icon, color: PratiCaseColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface,
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: PratiCaseColors.slateBlue,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.title, {this.semanticsId});

  final IconData icon;
  final String title;
  final String? semanticsId;
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
    border: Border.all(color: PratiCaseColors.border.withValues(alpha: 0.88)),
    boxShadow: PratiCaseShadows.card,
  );
}

Color _tierColor(String tier) {
  switch (tier.toLowerCase()) {
    case 'gold':
      return PratiCaseColors.gold;
    case 'silver':
      return PratiCaseColors.muted;
    case 'green':
      return PratiCaseColors.successGreen;
    case 'purple':
      return PratiCaseColors.slateBlue;
    default:
      return PratiCaseColors.teal;
  }
}

IconData _caseIcon(String? iconKey) {
  switch ((iconKey ?? '').toLowerCase()) {
    case 'heart':
      return Icons.monitor_heart_outlined;
    case 'abdomen':
      return Icons.medical_services_outlined;
    case 'surgery':
      return Icons.local_hospital_outlined;
    case 'urology':
      return Icons.water_drop_outlined;
    case 'gynecology':
      return Icons.female_rounded;
    case 'history':
      return Icons.history_rounded;
    default:
      return Icons.local_hospital_rounded;
  }
}

String _statusLabel(String value) {
  switch (value.toLowerCase()) {
    case 'history':
      return 'Anamnez';
    case 'physical_exam':
      return 'Muayene';
    case 'tests':
      return 'Tetkik';
    case 'diagnosis':
      return 'Tanı';
    case 'management':
      return 'Yönetim';
    case 'completed':
      return 'Tamamlandı';
    case 'active':
      return 'Devam Ediyor';
    default:
      return value;
  }
}

String _shortDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

int? _averageScore(List<CaseCollectionItem> items) {
  final scores = [
    for (final item in items)
      if (item.score != null) item.score!,
  ];
  if (scores.isEmpty) return null;
  return (scores.reduce((a, b) => a + b) / scores.length).round();
}

int _distinctBranches(List<CaseCollectionItem> items) {
  return {
    for (final item in items)
      if (item.branch.trim().isNotEmpty) item.branch.trim(),
  }.length;
}

String _errorText(Object? error) {
  if (error is ProgressDataUnavailable) {
    return PratiCaseUserMessage.safe(error.message);
  }
  return PratiCaseUserMessage.generalFailure;
}

void _showInfo(BuildContext context, String title, String body) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'P';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
