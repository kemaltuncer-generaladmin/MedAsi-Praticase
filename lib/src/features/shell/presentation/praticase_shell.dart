import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../cases/data/cases_repository.dart';
import '../../cases/presentation/cases_screen.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../progress/data/progress_repository.dart';
import '../../progress/presentation/progress_screens.dart';

class PratiCaseShell extends StatefulWidget {
  const PratiCaseShell({
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    super.key,
  });

  final HomeRepository? homeRepository;
  final CasesRepository? casesRepository;
  final ProgressRepository? progressRepository;

  @override
  State<PratiCaseShell> createState() => _PratiCaseShellState();
}

class _PratiCaseShellState extends State<PratiCaseShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final homeRepository = widget.homeRepository;
    final casesRepository = widget.casesRepository;
    final progressRepository = widget.progressRepository;
    final pages = [
      homeRepository == null
          ? const _LiveDataRequiredScreen()
          : HomeScreen(
              repository: homeRepository,
              onOpenCases: () => setState(() => _selectedIndex = 1),
              onOpenProgress: () => setState(() => _selectedIndex = 3),
              onOpenNotifications: progressRepository == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NotificationsScreen(repository: progressRepository),
                      ),
                    ),
              onOpenBadges: progressRepository == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            BadgesScreen(repository: progressRepository),
                      ),
                    ),
            ),
      casesRepository == null
          ? const _LiveDataRequiredScreen()
          : CasesScreen(repository: casesRepository),
      casesRepository == null
          ? const _LiveDataRequiredScreen()
          : CasesScreen(repository: casesRepository),
      progressRepository == null
          ? const _LiveDataRequiredScreen()
          : LeaderboardScreen(repository: progressRepository),
      progressRepository == null
          ? const _LiveDataRequiredScreen()
          : ProfileScreen(repository: progressRepository),
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
              _CenterNavItem(
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              _NavItem(
                selected: selectedIndex == 3,
                icon: Icons.bar_chart_rounded,
                label: 'Sıralama',
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

class _CenterNavItem extends StatelessWidget {
  const _CenterNavItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [PratiCaseColors.teal, Color(0xFF00586A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: PratiCaseColors.teal.withValues(alpha: 0.34),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: PratiCaseColors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Vaka Çöz',
              maxLines: 1,
              style: TextStyle(
                color: selected ? PratiCaseColors.teal : PratiCaseColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDataRequiredScreen extends StatelessWidget {
  const _LiveDataRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 128),
      children: const [
        Icon(Icons.storage_rounded, color: PratiCaseColors.teal, size: 58),
        SizedBox(height: 18),
        Text(
          'PratiCase canlı veri bekliyor',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Ana ekran mock data kullanmaz. SUPABASE_URL ve SUPABASE_ANON_KEY ile başlatıldığında praticase şemasından beslenecek.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF627084),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
