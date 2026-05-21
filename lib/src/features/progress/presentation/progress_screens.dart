import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../data/progress_repository.dart';
import '../domain/progress_models.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BadgeCard>>(
      future: repository.loadBadges(),
      builder: (context, snapshot) {
        return _ProgressPage(
          title: 'Rozetlerim',
          children: [
            const _SegmentHeader(items: ['Tümü', 'Kazanılan', 'Kazanılmamış']),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.workspace_premium_outlined,
                title: 'Rozetler yükleniyor',
                body: 'Canlı rozet verisi Supabase’den okunuyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Rozetler açılamadı',
                body: _errorText(snapshot.error),
              )
            else if (snapshot.requireData.isEmpty)
              const _StateBlock(
                icon: Icons.workspace_premium_outlined,
                title: 'Rozet tanımı yok',
                body:
                    'praticase.badge_definitions verisi eklendiğinde burada görünür.',
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
                children: [
                  for (final badge in snapshot.requireData)
                    _BadgeCardView(badge: badge),
                ],
              ),
          ],
        );
      },
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: repository.loadLeaderboard(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <LeaderboardEntry>[];
        final currentUsers = entries.where((entry) => entry.isCurrentUser);
        final current = currentUsers.isEmpty ? null : currentUsers.first;
        return _ProgressPage(
          title: 'Sıralama',
          children: [
            const _SegmentHeader(items: ['Genel', 'Arkadaşlar', 'Kurum']),
            const SizedBox(height: 12),
            const _SegmentHeader(items: ['Haftalık', 'Aylık', 'Tüm Zamanlar']),
            const SizedBox(height: 18),
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.leaderboard_outlined,
                title: 'Sıralama yükleniyor',
                body: 'Canlı puan tablosu hazırlanıyor.',
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
                body: 'praticase.leaderboard_scores dolduğunda liste oluşur.',
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
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCard>(
      future: repository.loadProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ProgressPage(
            title: 'Profil',
            children: [
              _StateBlock(
                icon: Icons.person_outline_rounded,
                title: 'Profil yükleniyor',
                body: 'Canlı profil verisi hazırlanıyor.',
              ),
            ],
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 116),
          children: [
            _ProfileHero(profile: profile),
            const SizedBox(height: 16),
            _StatsPanel(profile: profile),
            const SizedBox(height: 16),
            _MenuPanel(
              repository: repository,
              items: const [
                _MenuItem(Icons.history_rounded, 'Vaka Geçmişim'),
                _MenuItem(Icons.favorite_border_rounded, 'Favori Vakalarım'),
                _MenuItem(Icons.note_alt_outlined, 'Notlarım'),
                _MenuItem(Icons.notifications_none_rounded, 'Bildirimler'),
                _MenuItem(Icons.workspace_premium_outlined, 'Başarılarım'),
                _MenuItem(Icons.settings_outlined, 'Ayarlar'),
                _MenuItem(Icons.download_rounded, 'İndirmelerim'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCard>(
      future: repository.loadProfile(),
      builder: (context, snapshot) {
        return _ProgressPage(
          title: 'Ayarlar',
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.settings_outlined,
                title: 'Ayarlar yükleniyor',
                body: 'Canlı uygulama ayarları okunuyor.',
              )
            else if (snapshot.hasError)
              _StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Ayarlar açılamadı',
                body: _errorText(snapshot.error),
              )
            else ...[
              _SettingsSection(
                title: 'Hesap',
                rows: [
                  _SettingsRow(
                    Icons.person_outline_rounded,
                    'Profil Bilgileri',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileEditScreen(
                          repository: repository,
                          profile: snapshot.requireData,
                        ),
                      ),
                    ),
                  ),
                  _SettingsRow(Icons.lock_outline_rounded, 'Hesap ve Güvenlik'),
                  _SettingsRow(
                    Icons.notifications_none_rounded,
                    'Bildirim Ayarları',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NotificationsScreen(repository: repository),
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
                  ),
                  _SettingsRow(
                    Icons.language_rounded,
                    'Dil',
                    value: snapshot.requireData.settings.language,
                  ),
                  _SettingsRow(
                    Icons.text_fields_rounded,
                    'Yazı Boyutu',
                    value: snapshot.requireData.settings.textSize,
                  ),
                  _SettingsRow(
                    Icons.volume_up_outlined,
                    'Ses ve Titreşim',
                    enabled: snapshot.requireData.settings.soundAndHaptics,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Veri',
                rows: [
                  _SettingsRow(
                    Icons.data_usage_rounded,
                    'Veri Kullanımı',
                    value: snapshot.requireData.settings.dataUsage,
                  ),
                  _SettingsRow(
                    Icons.wifi_off_rounded,
                    'Çevrimdışı Mod',
                    enabled: snapshot.requireData.settings.offlineMode,
                  ),
                  _SettingsRow(
                    Icons.text_snippet_outlined,
                    'Vaka İndirmeleri',
                    enabled: snapshot.requireData.settings.caseDownloadsEnabled,
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
                            HelpCenterScreen(repository: repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.mail_outline_rounded,
                    'Bize Ulaşın',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ContactScreen(repository: repository),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    Icons.info_outline_rounded,
                    'Hakkında',
                    value: 'v1.2.0',
                  ),
                ],
              ),
              const SizedBox(height: 26),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    fullscreenDialog: true,
                    builder: (_) => const LogoutConfirmScreen(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE04F5F),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Çıkış Yap'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<NotificationCard>(
      title: 'Bildirimler',
      future: repository.loadNotifications(),
      emptyTitle: 'Bildirim yok',
      emptyBody: 'Canlı bildirimler oluştuğunda burada listelenir.',
      itemBuilder: (item) => _NotificationTile(item: item),
    );
  }
}

class FavoriteCasesScreen extends StatelessWidget {
  const FavoriteCasesScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<CaseCollectionItem>(
      title: 'Favori Vakalarım',
      future: repository.loadFavoriteCases(),
      emptyTitle: 'Favori vaka yok',
      emptyBody: 'Favoriye alınan canlı vakalar burada görünür.',
      itemBuilder: (item) => _CaseCollectionTile(item: item),
    );
  }
}

class CaseHistoryScreen extends StatelessWidget {
  const CaseHistoryScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<CaseCollectionItem>(
      title: 'Vaka Geçmişim',
      future: repository.loadCaseHistory(),
      emptyTitle: 'Vaka geçmişi yok',
      emptyBody: 'Başlatılan canlı OSCE oturumları burada listelenir.',
      itemBuilder: (item) => _CaseCollectionTile(item: item, history: true),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<SimpleContentItem>(
      title: 'Yardım Merkezi',
      future: repository.loadSupportTopics(),
      emptyTitle: 'Yardım başlığı yok',
      emptyBody: 'Destek içerikleri canlı tabloda oluştuğunda görünür.',
      itemBuilder: (item) => _SimpleTile(item: item),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return _LiveListPage<SimpleContentItem>(
      title: 'SSS',
      future: repository.loadFaqItems(),
      emptyTitle: 'SSS yok',
      emptyBody: 'Sık sorulan sorular canlı tabloda oluştuğunda görünür.',
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
      emptyBody: 'Aktif duyurular canlı tabloda oluştuğunda görünür.',
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
      emptyBody: 'Kullanıcı veri özetleri canlı view’dan gelir.',
      itemBuilder: (item) => _SimpleTile(item: item),
      footer: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Row(
          children: [
            Icon(Icons.ios_share_rounded, color: PratiCaseColors.teal),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Veri Dışa Aktar',
                style: TextStyle(
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

class ContactScreen extends StatefulWidget {
  const ContactScreen({required this.repository, super.key});

  final ProgressRepository repository;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
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
    setState(() => _saving = true);
    try {
      await widget.repository.createContactRequest(
        subject: _subject.text,
        email: _email.text,
        message: _message.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesajınız canlı destek kaydına alındı.')),
      );
      Navigator.maybePop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProgressPage(
      title: 'İletişim / Bize Ulaşın',
      children: [
        _FormFieldBlock(label: 'Konu', controller: _subject),
        const SizedBox(height: 12),
        _FormFieldBlock(label: 'E-posta', controller: _email),
        const SizedBox(height: 12),
        _FormFieldBlock(label: 'Mesajınız', controller: _message, maxLines: 7),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _send,
          child: Text(_saving ? 'Gönderiliyor...' : 'Gönder'),
        ),
      ],
    );
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
    setState(() => _saving = true);
    try {
      await widget.repository.saveProfile(
        displayName: _name.text,
        email: _email.text,
        specialty: _specialty.text,
        educationLevel: _education.text,
      );
      if (!mounted) return;
      Navigator.maybePop(context);
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
      backgroundColor: Colors.black.withValues(alpha: 0.72),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Çıkış Yapmak İstiyor musunuz?',
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
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                  ),
                  child: const Text('Çıkış Yap'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal'),
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
  const _ProgressPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
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
  }
}

class _LiveListPage<T> extends StatelessWidget {
  const _LiveListPage({
    required this.title,
    required this.future,
    required this.emptyTitle,
    required this.emptyBody,
    required this.itemBuilder,
    this.footer,
  });

  final String title;
  final Future<List<T>> future;
  final String emptyTitle;
  final String emptyBody;
  final Widget Function(T item) itemBuilder;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        return _ProgressPage(
          title: title,
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const _StateBlock(
                icon: Icons.hourglass_empty_rounded,
                title: 'Canlı veri yükleniyor',
                body: 'PratiCase verisi Supabase’den okunuyor.',
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

class _SegmentHeader extends StatelessWidget {
  const _SegmentHeader({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == 0 ? PratiCaseColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    items[index],
                    style: TextStyle(
                      color: index == 0 ? Colors.white : PratiCaseColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
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
              color: Color(0xFF66758A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE8EDF2),
            color: color,
            minHeight: 5,
          ),
          const SizedBox(height: 6),
          Text(
            '${badge.progressCount} / ${badge.targetCount}',
            style: const TextStyle(
              color: Color(0xFF66758A),
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
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in entries)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: entry.rank == 1 ? 38 : 30,
                    backgroundColor: PratiCaseColors.teal.withValues(
                      alpha: 0.14,
                    ),
                    child: Text(
                      _initial(entry.displayName),
                      style: const TextStyle(
                        color: PratiCaseColors.teal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      color: PratiCaseColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
                  Text(
                    '${entry.totalPoints} puan',
                    style: const TextStyle(
                      color: Color(0xFF66758A),
                      fontSize: 12,
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
        borderRadius: BorderRadius.circular(12),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF005263), Color(0xFF007179)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.white,
            child: Text(
              _initial(
                profile.displayName.isEmpty
                    ? profile.email
                    : profile.displayName,
              ),
              style: const TextStyle(
                color: PratiCaseColors.teal,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName.isEmpty ? profile.email : profile.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              profile.target,
              profile.classLevel,
            ].where((e) => e.isNotEmpty).join(' • '),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PratiCase Üyesi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İstatistiklerim',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _MiniMetric(
                label: 'Çözdüğüm Vaka',
                value: '${profile.solvedCaseCount}',
              ),
              _MiniMetric(
                label: 'Toplam Puan',
                value: '${profile.totalPoints}',
              ),
              _MiniMetric(
                label: 'Doğru Tanı',
                value: '%${profile.correctDiagnosisRate}',
              ),
              _MiniMetric(
                label: 'Ortalama',
                value: '${profile.successRatePercent}',
              ),
              _MiniMetric(label: 'Seri', value: '${profile.dailyStreak} gün'),
              _MiniMetric(label: 'Sınıf', value: profile.classLevel),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.repository, required this.items});

  final ProgressRepository repository;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              leading: Icon(item.icon, color: PratiCaseColors.navy),
              title: Text(item.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                if (item.title == 'Vaka Geçmişim') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CaseHistoryScreen(repository: repository),
                    ),
                  );
                }
                if (item.title == 'Favori Vakalarım') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FavoriteCasesScreen(repository: repository),
                    ),
                  );
                }
                if (item.title == 'Notlarım') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MyDataScreen(repository: repository),
                    ),
                  );
                }
                if (item.title == 'Bildirimler') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          NotificationsScreen(repository: repository),
                    ),
                  );
                }
                if (item.title == 'Başarılarım') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BadgesScreen(repository: repository),
                    ),
                  );
                }
                if (item.title == 'Ayarlar') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(repository: repository),
                    ),
                  );
                }
                if (item.title == 'İndirmelerim') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MyDataScreen(repository: repository),
                    ),
                  );
                }
              },
            ),
        ],
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
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: PratiCaseColors.navy),
      title: Text(title),
      trailing: enabled == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  Text(
                    value!,
                    style: const TextStyle(color: Color(0xFF66758A)),
                  ),
                const Icon(Icons.chevron_right_rounded),
              ],
            )
          : Switch(value: enabled!, onChanged: null),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationCard item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: ListTile(
        leading: Icon(
          item.isRead ? Icons.notifications_none_rounded : Icons.star_rounded,
          color: item.isRead ? const Color(0xFF66758A) : PratiCaseColors.gold,
        ),
        title: Text(item.title),
        subtitle: Text(item.body),
        trailing: const Icon(Icons.chevron_right_rounded),
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
      child: ListTile(
        leading: const Icon(
          Icons.article_outlined,
          color: PratiCaseColors.teal,
        ),
        title: Text(item.title),
        subtitle: item.body.isEmpty ? null : Text(item.body),
        trailing: const Icon(Icons.chevron_right_rounded),
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
    );
  }
}

class _CaseCollectionTile extends StatelessWidget {
  const _CaseCollectionTile({required this.item, this.history = false});

  final CaseCollectionItem item;
  final bool history;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PratiCaseColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: PratiCaseColors.teal,
          ),
        ),
        title: Text(item.title),
        subtitle: Text(
          history
              ? 'İlerleme: %${item.progressPercent ?? 0}'
              : '${item.branch} • ${item.difficulty}',
        ),
        trailing: Text(
          history ? '${item.score ?? 0}' : '${item.points} Puan',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _FormFieldBlock extends StatelessWidget {
  const _FormFieldBlock({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

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
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF66758A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
              color: Color(0xFF66758A),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.title);

  final IconData icon;
  final String title;
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: PratiCaseColors.border),
    boxShadow: [
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Color _tierColor(String tier) {
  switch (tier.toLowerCase()) {
    case 'gold':
      return PratiCaseColors.gold;
    case 'silver':
      return const Color(0xFF75828F);
    case 'green':
      return const Color(0xFF2AA765);
    case 'purple':
      return const Color(0xFF7867D8);
    default:
      return const Color(0xFFB6754D);
  }
}

String _errorText(Object? error) {
  if (error is ProgressDataUnavailable) return error.message;
  return 'Canlı veri alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'P';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
