import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../cases/data/cases_repository.dart';
import '../../cases/presentation/cases_screen.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../progress/data/progress_repository.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/presentation/progress_screens.dart';

class PratiCaseShell extends StatefulWidget {
  const PratiCaseShell({
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    required this.onSignOut,
    super.key,
  });

  final HomeRepository homeRepository;
  final CasesRepository casesRepository;
  final ProgressRepository progressRepository;
  final Future<void> Function() onSignOut;

  @override
  State<PratiCaseShell> createState() => _PratiCaseShellState();
}

class _PratiCaseShellState extends State<PratiCaseShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        repository: widget.homeRepository,
        casesRepository: widget.casesRepository,
        onOpenCases: () => setState(() => _selectedIndex = 1),
        onOpenProgress: () => setState(() => _selectedIndex = 3),
        onOpenNotifications: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                NotificationsScreen(repository: widget.progressRepository),
          ),
        ),
        onOpenBadges: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BadgesScreen(repository: widget.progressRepository),
          ),
        ),
      ),
      CasesScreen(repository: widget.casesRepository),
      _ExamsScreen(onOpenCases: () => setState(() => _selectedIndex = 1)),
      _ProgressSummaryScreen(repository: widget.progressRepository),
      ProfileScreen(
        repository: widget.progressRepository,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: _PratiCaseBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _PratiCaseBottomNav extends StatelessWidget {
  const _PratiCaseBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: PratiCaseColors.navy.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                selected: selectedIndex == 0,
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                onTap: () => onSelected(0),
              ),
              _NavItem(
                selected: selectedIndex == 1,
                icon: Icons.inventory_2_outlined,
                label: 'Vakalar',
                onTap: () => onSelected(1),
              ),
              _NavItem(
                selected: selectedIndex == 2,
                icon: Icons.assignment_rounded,
                label: 'Sınavlar',
                onTap: () => onSelected(2),
              ),
              _NavItem(
                selected: selectedIndex == 3,
                icon: Icons.trending_up_rounded,
                label: 'Gelişim',
                onTap: () => onSelected(3),
              ),
              _NavItem(
                selected: selectedIndex == 4,
                icon: Icons.person_outline_rounded,
                label: 'Profilim',
                onTap: () => onSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PratiCaseColors.teal : const Color(0xFF7B8798);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

class _ExamsScreen extends StatelessWidget {
  const _ExamsScreen({required this.onOpenCases});

  final VoidCallback onOpenCases;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 132;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
      children: [
        const _ShellTitle(
          title: 'Sınavlar',
          subtitle:
              'OSCE pratiğini tek istasyon veya mini sınav olarak başlat.',
        ),
        const SizedBox(height: 18),
        _ExamModeCard(
          icon: Icons.timer_rounded,
          title: 'Tek İstasyon',
          subtitle: 'Bir vaka seç, süreli OSCE akışına gir.',
          onTap: onOpenCases,
        ),
        _ExamModeCard(
          icon: Icons.view_week_rounded,
          title: 'Mini OSCE',
          subtitle: 'Peş peşe kısa istasyonlarla sınav temposu çalış.',
          onTap: () => _showComingSoon(context, 'Mini OSCE'),
        ),
        _ExamModeCard(
          icon: Icons.track_changes_rounded,
          title: 'Zayıf Konulardan Sınav',
          subtitle: 'Gelişim verilerine göre tekrar gerektiren vakalara dön.',
          onTap: () => _showComingSoon(context, 'Zayıf konulardan sınav'),
        ),
        _ExamModeCard(
          icon: Icons.local_hospital_outlined,
          title: 'Branş Paketi',
          subtitle: 'Genel Cerrahi, Kadın Doğum veya Üroloji odaklı ilerle.',
          onTap: () => _showComingSoon(context, 'Branş paketi'),
        ),
      ],
    );
  }
}

class _ProgressSummaryScreen extends StatelessWidget {
  const _ProgressSummaryScreen({required this.repository});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileCard>(
      future: repository.loadProfile(),
      builder: (context, snapshot) {
        final bottom = MediaQuery.paddingOf(context).bottom + 132;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottom),
          children: [
            const _ShellTitle(
              title: 'Gelişim',
              subtitle: 'OSCE performansının ana göstergelerini takip et.',
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState != ConnectionState.done)
              const _ShellStateCard(
                icon: Icons.insights_outlined,
                title: 'Gelişim yükleniyor',
                body: 'Canlı profil ve performans verisi hazırlanıyor.',
              )
            else if (snapshot.hasError)
              const _ShellStateCard(
                icon: Icons.cloud_off_rounded,
                title: 'Gelişim açılamadı',
                body:
                    'Canlı veri bağlantısı kurulduğunda performans özeti burada görünür.',
              )
            else ...[
              _ProgressHero(profile: snapshot.requireData),
              const SizedBox(height: 14),
              _ProgressMetricGrid(profile: snapshot.requireData),
              const SizedBox(height: 14),
              _ExamModeCard(
                icon: Icons.leaderboard_outlined,
                title: 'Sıralamayı Gör',
                subtitle: 'Toplam puan ve çözülen vaka durumunu karşılaştır.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LeaderboardScreen(repository: repository),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ShellStateCard extends StatelessWidget {
  const _ShellStateCard({
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
      decoration: _shellCardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: PratiCaseColors.teal, size: 42),
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
              color: Color(0xFF64728A),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellTitle extends StatelessWidget {
  const _ShellTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF5E6D82),
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ExamModeCard extends StatelessWidget {
  const _ExamModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _shellCardDecoration(),
          child: Row(
            children: [
              _ShellSoftIcon(icon: icon),
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
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF5F6E83),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: PratiCaseColors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF073844), Color(0xFF006A72)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ortalama Başarı',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '%${profile.successRatePercent}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.insights_rounded,
            color: PratiCaseColors.gold,
            size: 44,
          ),
        ],
      ),
    );
  }
}

class _ProgressMetricGrid extends StatelessWidget {
  const _ProgressMetricGrid({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Vaka', profile.solvedCaseCount.toString()),
      ('Doğru Tanı', '%${profile.correctDiagnosisRate}'),
      ('Seri', '${profile.dailyStreak} gün'),
      ('Puan', profile.totalPoints.toString()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final metric in metrics)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _shellCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.$1,
                  style: const TextStyle(
                    color: Color(0xFF68768A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ShellSoftIcon extends StatelessWidget {
  const _ShellSoftIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: PratiCaseColors.teal),
    );
  }
}

BoxDecoration _shellCardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
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

void _showComingSoon(BuildContext context, String title) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$title yakında kullanıma açılacak.')));
}
