import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/ui/ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../cases/data/cases_repository.dart';
import '../../cases/presentation/cases_screen.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../progress/data/progress_repository.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/presentation/progress_screens.dart';
import '../../theoretical_exam/data/theoretical_exam_repository.dart';
import '../../theoretical_exam/presentation/theoretical_exam_screen.dart';

class PratiCaseShell extends StatefulWidget {
  const PratiCaseShell({
    required this.authRepository,
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    required this.theoreticalExamRepository,
    required this.onSignOut,
    super.key,
  });

  final AuthRepository authRepository;
  final HomeRepository homeRepository;
  final CasesRepository casesRepository;
  final ProgressRepository progressRepository;
  final TheoreticalExamRepository theoreticalExamRepository;
  final Future<void> Function() onSignOut;

  @override
  State<PratiCaseShell> createState() => _PratiCaseShellState();
}

class _PratiCaseShellState extends State<PratiCaseShell> {
  int _selectedIndex = 0;
  int? _unreadNotificationCount;
  StreamSubscription<int>? _notificationCountSubscription;

  @override
  void initState() {
    super.initState();
    _notificationCountSubscription = widget.progressRepository
        .watchUnreadNotificationCount()
        .listen(
          (count) {
            if (!mounted) return;
            setState(() => _unreadNotificationCount = count);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _unreadNotificationCount = 0);
          },
        );
    _refreshUnreadNotificationCount();
  }

  @override
  void dispose() {
    _notificationCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final count = await widget.progressRepository
          .loadUnreadNotificationCount();
      if (!mounted) return;
      setState(() => _unreadNotificationCount = count);
    } on ProgressDataUnavailable {
      if (!mounted) return;
      setState(() => _unreadNotificationCount = 0);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          repository: widget.progressRepository,
          onChanged: _refreshUnreadNotificationCount,
        ),
      ),
    );
    await _refreshUnreadNotificationCount();
  }

  void _openProfile() => setState(() => _selectedIndex = 4);

  @override
  Widget build(BuildContext context) {
    final useSideNavigation = PratiCaseResponsive.usesSideNavigation(context);
    final pages = [
      HomeScreen(
        repository: widget.homeRepository,
        casesRepository: widget.casesRepository,
        onOpenCases: () => setState(() => _selectedIndex = 1),
        onOpenExams: () => setState(() => _selectedIndex = 2),
        onOpenTheoreticalExam: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TheoreticalExamSetupScreen(
              repository: widget.theoreticalExamRepository,
            ),
          ),
        ),
        onOpenProgress: () => setState(() => _selectedIndex = 3),
        unreadNotificationCount: _unreadNotificationCount,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfile,
        onOpenBadges: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BadgesScreen(repository: widget.progressRepository),
          ),
        ),
      ),
      CasesScreen(
        repository: widget.casesRepository,
        unreadNotificationCount: _unreadNotificationCount ?? 0,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfile,
      ),
      _ExamsScreen(
        progressRepository: widget.progressRepository,
        theoreticalExamRepository: widget.theoreticalExamRepository,
        onOpenCases: () => setState(() => _selectedIndex = 1),
        unreadNotificationCount: _unreadNotificationCount ?? 0,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfile,
      ),
      _ProgressSummaryScreen(repository: widget.progressRepository),
      ProfileScreen(
        authRepository: widget.authRepository,
        repository: widget.progressRepository,
        unreadNotificationCount: _unreadNotificationCount ?? 0,
        onOpenNotifications: _openNotifications,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      extendBody: !useSideNavigation,
      body: SafeArea(
        bottom: false,
        child: useSideNavigation
            ? Row(
                children: [
                  _PratiCaseSideNavigation(
                    selectedIndex: _selectedIndex,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: PratiCaseColors.border,
                  ),
                  Expanded(
                    child: IndexedStack(index: _selectedIndex, children: pages),
                  ),
                ],
              )
            : IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: useSideNavigation
          ? null
          : _PratiCaseBottomNav(
              selectedIndex: _selectedIndex,
              onSelected: (index) => setState(() => _selectedIndex = index),
            ),
    );
  }
}

class _PratiCaseSideNavigation extends StatelessWidget {
  const _PratiCaseSideNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final extended = PratiCaseResponsive.isDesktop(context);
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      minWidth: 88,
      minExtendedWidth: 224,
      groupAlignment: -0.72,
      backgroundColor: PratiCaseColors.white,
      indicatorColor: PratiCaseColors.teal.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: PratiCaseColors.teal),
      unselectedIconTheme: const IconThemeData(color: PratiCaseColors.muted),
      selectedLabelTextStyle: const TextStyle(
        color: PratiCaseColors.teal,
        fontWeight: FontWeight.w900,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: PratiCaseColors.muted,
        fontWeight: FontWeight.w700,
      ),
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
        child: _RailBrand(extended: extended),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Ana Sayfa'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: Text('Vakalar'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: Text('Sınavlar'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.trending_up_outlined),
          selectedIcon: Icon(Icons.trending_up_rounded),
          label: Text('Gelişim'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profilim'),
        ),
      ],
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      child: Image.asset(
        'assets/auth/praticase_icon.png',
        width: 42,
        height: 42,
        fit: BoxFit.cover,
      ),
    );
    if (!extended) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        const Text.rich(
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
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
      minimum: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
            border: Border.all(color: PratiCaseColors.border),
            boxShadow: PratiCaseShadows.floating,
          ),
          child: Row(
            children: [
              _NavItem(
                identifier: 'nav.home',
                selected: selectedIndex == 0,
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                onTap: () => onSelected(0),
              ),
              _NavItem(
                identifier: 'nav.cases',
                selected: selectedIndex == 1,
                icon: Icons.inventory_2_outlined,
                label: 'Vakalar',
                onTap: () => onSelected(1),
              ),
              _NavItem(
                identifier: 'nav.exams',
                selected: selectedIndex == 2,
                icon: Icons.assignment_rounded,
                label: 'Sınavlar',
                onTap: () => onSelected(2),
              ),
              _NavItem(
                identifier: 'nav.progress',
                selected: selectedIndex == 3,
                icon: Icons.trending_up_rounded,
                label: 'Gelişim',
                onTap: () => onSelected(3),
              ),
              _NavItem(
                identifier: 'nav.profile',
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
    required this.identifier,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String identifier;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PratiCaseColors.teal : PratiCaseColors.muted;
    return Expanded(
      child: Semantics(
        identifier: identifier,
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: () {
            if (!selected) PratiCaseHaptics.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          child: AnimatedContainer(
            duration: PratiCaseDurations.fast,
            curve: PratiCaseCurves.standard,
            height: 62,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? PratiCaseColors.teal.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: PratiCaseDurations.fast,
                  switchInCurve: PratiCaseCurves.standard,
                  switchOutCurve: PratiCaseCurves.exit,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.86, end: 1)
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    icon,
                    key: ValueKey(selected),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: PratiCaseSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
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

class _ExamsScreen extends StatefulWidget {
  const _ExamsScreen({
    required this.progressRepository,
    required this.theoreticalExamRepository,
    required this.onOpenCases,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.unreadNotificationCount,
  });

  final ProgressRepository progressRepository;
  final TheoreticalExamRepository theoreticalExamRepository;
  final VoidCallback onOpenCases;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final int unreadNotificationCount;

  @override
  State<_ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<_ExamsScreen> {
  late Future<List<ExamModeItem>> _examModesFuture;

  @override
  void initState() {
    super.initState();
    _examModesFuture = widget.progressRepository.loadExamModes();
  }

  Future<void> _refresh() async {
    setState(() {
      _examModesFuture = widget.progressRepository.loadExamModes();
    });
    await _examModesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ExamModeItem>>(
        future: _examModesFuture,
        builder: (context, snapshot) {
          final modes = snapshot.data ?? const <ExamModeItem>[];
          return PratiCaseResponsiveListView(
            padding: PratiCaseResponsive.pagePadding(context),
            children: [
              _ShellBrandHeader(
                onOpenNotifications: widget.onOpenNotifications,
                onOpenProfile: widget.onOpenProfile,
                unreadNotificationCount: widget.unreadNotificationCount,
              ),
              const SizedBox(height: 36),
              const _ShellTitle(
                title: 'Sınavlar',
                subtitle:
                    'OSCE pratiğini tek istasyon veya mini sınav olarak başlat.',
              ),
              const SizedBox(height: 26),
              if (snapshot.connectionState != ConnectionState.done)
                const _ShellStateCard(
                  icon: Icons.assignment_outlined,
                  title: 'Sınavlar yükleniyor',
                  body: 'Canlı sınav modları Supabase’den okunuyor.',
                )
              else if (snapshot.hasError)
                _ShellStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Sınavlar açılamadı',
                  body: _errorText(snapshot.error),
                )
              else if (modes.isEmpty)
                const _ShellStateCard(
                  icon: Icons.assignment_outlined,
                  title: 'Sınav modu yok',
                  body: 'Canlı sınav kartları yayınlandığında burada görünür.',
                )
              else
                _ExamModeGrid(
                  modes: modes,
                  onOpenMode: (mode) => _openExamMode(context, mode.actionKey),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openExamMode(BuildContext context, String actionKey) {
    switch (actionKey) {
      case 'weak_areas':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                WeakAreaAnalysisScreen(repository: widget.progressRepository),
          ),
        );
        return;
      case 'theoretical_exam':
      case 'kuramsal_sinav':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TheoreticalExamSetupScreen(
              repository: widget.theoreticalExamRepository,
            ),
          ),
        );
        return;
      case 'single_station':
      case 'mini_osce':
      case 'branch_package':
      case 'cases':
      default:
        widget.onOpenCases();
        return;
    }
  }
}

class _ProgressSummaryScreen extends StatefulWidget {
  const _ProgressSummaryScreen({required this.repository});

  final ProgressRepository repository;

  @override
  State<_ProgressSummaryScreen> createState() => _ProgressSummaryScreenState();
}

class _ProgressSummaryScreenState extends State<_ProgressSummaryScreen> {
  late Future<(ProfileCard, ClinicalProgressSummary, List<BadgeCard>)>
  _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = _loadProgress();
  }

  Future<void> _refresh() async {
    setState(() => _progressFuture = _loadProgress());
    await _progressFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(ProfileCard, ClinicalProgressSummary, List<BadgeCard>)>(
        future: _progressFuture,
        builder: (context, snapshot) {
          return PratiCaseResponsiveListView(
            padding: PratiCaseResponsive.pagePadding(context),
            children: [
              const _ProgressTitleBar(),
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
                _ProgressSummaryLayout(
                  profile: snapshot.requireData.$1,
                  summary: snapshot.requireData.$2,
                  badges: snapshot.requireData.$3,
                  repository: widget.repository,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<(ProfileCard, ClinicalProgressSummary, List<BadgeCard>)>
  _loadProgress() async {
    final profile = widget.repository.loadProfile();
    final summary = widget.repository.loadClinicalProgressSummary();
    final badges = widget.repository.loadBadges();
    return (await profile, await summary, await badges);
  }
}

class _ExamModeGrid extends StatelessWidget {
  const _ExamModeGrid({required this.modes, required this.onOpenMode});

  final List<ExamModeItem> modes;
  final ValueChanged<ExamModeItem> onOpenMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = PratiCaseResponsive.columnsForWidth(
          constraints.maxWidth,
          desktop: 2,
        );
        final spacing = columns == 1 ? 0.0 : 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: [
            for (final mode in modes)
              SizedBox(
                width: itemWidth,
                child: _ExamModeCard(
                  icon: _examModeIcon(mode.iconKey),
                  title: mode.title,
                  subtitle: mode.subtitle,
                  onTap: () => onOpenMode(mode),
                ),
              ),
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
    return StateCard(icon: icon, title: title, body: body);
  }
}

class _ShellBrandHeader extends StatelessWidget {
  const _ShellBrandHeader({
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
        Expanded(
          child: RichText(
            maxLines: 1,
            text: const TextSpan(
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontFamily: 'Plus Jakarta Sans',
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
        _HeaderBell(
          unreadCount: unreadNotificationCount,
          onTap: onOpenNotifications,
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

class _HeaderBell extends StatelessWidget {
  const _HeaderBell({required this.unreadCount, required this.onTap});

  final int unreadCount;
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
        if (unreadCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: const BoxDecoration(
                color: PratiCaseColors.gold,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
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
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            color: PratiCaseColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ProgressTitleBar extends StatelessWidget {
  const _ProgressTitleBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PratiCaseColors.border)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.trending_up_rounded,
            color: PratiCaseColors.teal,
            size: 27,
          ),
          SizedBox(width: 12),
          Text(
            'Gelişim',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
      child: ClinicalCard(
        onTap: onTap,
        child: Row(
          children: [
            SoftIconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
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
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.profile});

  final ProfileCard profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Genel Ortalama',
                  style: TextStyle(
                    color: PratiCaseColors.tealBright,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '%${profile.successRatePercent}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                    border: Border.all(
                      color: PratiCaseColors.tealBright,
                      width: 1.4,
                    ),
                  ),
                  child: const Text(
                    'Klinik beceri takibi',
                    style: TextStyle(
                      color: PratiCaseColors.tealBright,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.track_changes_rounded,
            color: PratiCaseColors.tealBright,
            size: 72,
          ),
        ],
      ),
    );
  }
}

class _SkillBars extends StatelessWidget {
  const _SkillBars({required this.summary});

  final ClinicalProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Anamnez', summary.percentFor('history'), PratiCaseColors.teal),
      (
        'Fizik Muayene',
        summary.percentFor('physical'),
        PratiCaseColors.tealBright,
      ),
      ('Tetkik İnceleme', summary.percentFor('tests'), PratiCaseColors.teal),
      (
        'Yönetim & Tedavi',
        summary.percentFor('management'),
        PratiCaseColors.gold,
      ),
    ];
    return ClinicalCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Klinik Beceriler',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          for (final item in values) ...[
            _SkillBar(label: item.$1, value: item.$2, color: item.$3),
            if (item != values.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: PratiCaseColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '%$value',
              style: const TextStyle(
                color: PratiCaseColors.slateBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            color: color,
            backgroundColor: PratiCaseColors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _AiResultTrendCard extends StatelessWidget {
  const _AiResultTrendCard({required this.summary});

  final ClinicalProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final results = summary.recentResults.take(5).toList();
    return ClinicalCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressCardTitle(
            icon: Icons.show_chart_rounded,
            title: 'AI Sonuç Trendi',
          ),
          const SizedBox(height: 16),
          for (final result in results) ...[
            Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    '%${result.score}',
                    maxLines: 1,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                    child: LinearProgressIndicator(
                      value: result.score / 100,
                      minHeight: 8,
                      color: result.score >= 80
                          ? PratiCaseColors.teal
                          : PratiCaseColors.gold,
                      backgroundColor: PratiCaseColors.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 112,
                  child: Text(
                    result.branch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              result.caseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PratiCaseColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (result != results.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AiFeedbackCard extends StatelessWidget {
  const _AiFeedbackCard({required this.summary});

  final ClinicalProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressCardTitle(
            icon: Icons.psychology_alt_outlined,
            title: 'AI Geri Bildirimleri',
          ),
          const SizedBox(height: 14),
          for (final section in summary.feedback) ...[
            Text(
              section.title,
              style: const TextStyle(
                color: PratiCaseColors.teal,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in section.items) ...[
              _FeedbackLine(text: item),
              const SizedBox(height: 7),
            ],
            if (section != summary.feedback.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ProgressCardTitle extends StatelessWidget {
  const _ProgressCardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: PratiCaseColors.teal),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 7, color: PratiCaseColors.gold),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: PratiCaseColors.ink,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressMetricGrid extends StatelessWidget {
  const _ProgressMetricGrid({required this.profile, required this.badges});

  final ProfileCard profile;
  final List<BadgeCard> badges;

  @override
  Widget build(BuildContext context) {
    final earnedBadges = badges.where((badge) => badge.earned).length;
    final metrics = [
      (Icons.folder_outlined, 'Vaka', profile.solvedCaseCount.toString()),
      (
        Icons.track_changes_rounded,
        'Doğru Tanı',
        '%${profile.correctDiagnosisRate}',
      ),
      (
        Icons.local_fire_department_outlined,
        'Seri',
        '${profile.dailyStreak} gün',
      ),
      (Icons.workspace_premium_outlined, 'Rozet', '$earnedBadges'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.65 : 2.15,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final metric in metrics)
              ClinicalCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PratiCaseColors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                      ),
                      child: Icon(metric.$1, color: PratiCaseColors.teal),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            metric.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PratiCaseColors.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            metric.$2,
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
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProgressSummaryLayout extends StatelessWidget {
  const _ProgressSummaryLayout({
    required this.profile,
    required this.summary,
    required this.badges,
    required this.repository,
  });

  final ProfileCard profile;
  final ClinicalProgressSummary summary;
  final List<BadgeCard> badges;
  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    final actionCards = [
      _ExamModeCard(
        icon: Icons.track_changes_rounded,
        title: 'Zayıf Alan Analizi',
        subtitle: 'Eksik başlıkları ve tekrar gerektiren vakaları gör.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WeakAreaAnalysisScreen(repository: repository),
          ),
        ),
      ),
      _ExamModeCard(
        icon: Icons.history_rounded,
        title: 'Vaka Geçmişi',
        subtitle: 'Başlattığın ve tamamladığın istasyonları incele.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CaseHistoryScreen(repository: repository),
          ),
        ),
      ),
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final trendCards = [
          if (summary.recentResults.isNotEmpty)
            _AiResultTrendCard(summary: summary),
          if (summary.feedback.isNotEmpty) _AiFeedbackCard(summary: summary),
          ...actionCards,
        ];
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHero(profile: profile),
              const SizedBox(height: 16),
              _SkillBars(summary: summary),
              if (summary.recentResults.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AiResultTrendCard(summary: summary),
              ],
              if (summary.feedback.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AiFeedbackCard(summary: summary),
              ],
              const SizedBox(height: 16),
              _ProgressMetricGrid(profile: profile, badges: badges),
              const SizedBox(height: 16),
              ...actionCards,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _ProgressHero(profile: profile),
                  const SizedBox(height: 16),
                  _SkillBars(summary: summary),
                  const SizedBox(height: 16),
                  _ProgressMetricGrid(profile: profile, badges: badges),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  for (final card in trendCards) ...[
                    card,
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

IconData _examModeIcon(String key) {
  switch (key) {
    case 'timer':
    case 'single_station':
      return Icons.timer_rounded;
    case 'mini_osce':
    case 'stations':
      return Icons.view_week_rounded;
    case 'weak_areas':
    case 'target':
      return Icons.track_changes_rounded;
    case 'branch':
    case 'hospital':
      return Icons.local_hospital_outlined;
    case 'history':
      return Icons.history_rounded;
    case 'theoretical':
    case 'school':
      return Icons.school_rounded;
    default:
      return Icons.assignment_outlined;
  }
}

String _errorText(Object? error) {
  final text = error?.toString() ?? '';
  if (text.trim().isEmpty) {
    return 'Canlı veri bağlantısı kurulamadı.';
  }
  return text.replaceFirst('Exception: ', '');
}
