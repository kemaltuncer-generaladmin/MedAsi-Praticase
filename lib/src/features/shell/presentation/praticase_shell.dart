import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/data/user_facing_error.dart';
import '../../../shared/ui/ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../cases/data/cases_repository.dart';
import '../../cases/presentation/cases_screen.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../oral_exam/data/oral_exam_repository.dart';
import '../../oral_exam/presentation/oral_exam_screens.dart';
import '../../progress/data/progress_repository.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/presentation/progress_screens.dart';
import '../../store/data/store_controller.dart';
import '../../store/presentation/wallet_screen.dart';
import '../../theoretical_exam/data/theoretical_exam_repository.dart';
import '../../theoretical_exam/presentation/theoretical_exam_screen.dart';

class PratiCaseShell extends StatefulWidget {
  const PratiCaseShell({
    required this.authRepository,
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    required this.theoreticalExamRepository,
    required this.oralExamRepository,
    required this.onSignOut,
    super.key,
  });

  final AuthRepository authRepository;
  final HomeRepository homeRepository;
  final CasesRepository casesRepository;
  final ProgressRepository progressRepository;
  final TheoreticalExamRepository theoreticalExamRepository;
  final OralExamRepository oralExamRepository;
  final Future<void> Function() onSignOut;

  @override
  State<PratiCaseShell> createState() => _PratiCaseShellState();
}

class _PratiCaseShellState extends State<PratiCaseShell> {
  int _selectedIndex = 0;
  int? _unreadNotificationCount;
  StoreController? _storeController;
  var _walletTabMounted = false;
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
    final storeController = _storeController;
    if (storeController != null) {
      unawaited(storeController.dispose());
    }
    super.dispose();
  }

  StoreController _storeControllerForWallet() {
    return _storeController ??= StoreController();
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) _walletTabMounted = true;
    });
    if (index == 1 && _storeController?.initialized == true) {
      unawaited(_storeController!.refresh());
    }
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

  void _openCases({CasesScreenMode mode = CasesScreenMode.library}) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CasesScreen(
            repository: widget.casesRepository,
            mode: mode,
            unreadNotificationCount: _unreadNotificationCount ?? 0,
            onOpenNotifications: _openNotifications,
            onOpenProfile: _openProfile,
            onOpenHome: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              _selectTab(0);
            },
          ),
        ),
      ),
    );
  }

  void _openProfile() => _selectTab(4);

  @override
  Widget build(BuildContext context) {
    final useSideNavigation = PratiCaseResponsive.usesSideNavigation(context);
    final pages = [
      HomeScreen(
        repository: widget.homeRepository,
        casesRepository: widget.casesRepository,
        onOpenCases: _openCases,
        onOpenExams: () => _selectTab(2),
        onOpenTheoreticalExam: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TheoreticalExamSetupScreen(
              repository: widget.theoreticalExamRepository,
            ),
          ),
        ),
        onOpenOralExam: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                OralExamSetupScreen(repository: widget.oralExamRepository),
          ),
        ),
        onOpenProgress: () => _selectTab(3),
        unreadNotificationCount: _unreadNotificationCount,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfile,
        onOpenBadges: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BadgesScreen(repository: widget.progressRepository),
          ),
        ),
      ),
      _walletTabMounted
          ? WalletScreen(
              controller: _storeControllerForWallet(),
              unreadNotificationCount: _unreadNotificationCount ?? 0,
              onOpenNotifications: _openNotifications,
              onOpenProfile: _openProfile,
            )
          : const _WalletDormantScreen(),
      _ExamsScreen(
        progressRepository: widget.progressRepository,
        theoreticalExamRepository: widget.theoreticalExamRepository,
        oralExamRepository: widget.oralExamRepository,
        onOpenCases: _openCases,
        onOpenSingleStation: () =>
            _openCases(mode: CasesScreenMode.singleStation),
        unreadNotificationCount: _unreadNotificationCount ?? 0,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfile,
      ),
      _ProgressSummaryScreen(
        repository: widget.progressRepository,
        unreadNotificationCount: _unreadNotificationCount ?? 0,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfile,
      ),
      ProfileScreen(
        authRepository: widget.authRepository,
        repository: widget.progressRepository,
        unreadNotificationCount: _unreadNotificationCount ?? 0,
        onOpenNotifications: _openNotifications,
        onSignOut: widget.onSignOut,
        storeControllerFactory: _storeControllerForWallet,
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
                    onSelected: _selectTab,
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
              onSelected: _selectTab,
            ),
    );
  }
}

class _WalletDormantScreen extends StatelessWidget {
  const _WalletDormantScreen();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: Text('Cüzdan'),
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = PratiCaseResponsive.isCompactPhone(context);
    final navHeight = PratiCaseResponsive.bottomNavigationHeightForWidth(width);
    final horizontalInset = compact ? 10.0 : 16.0;
    final bottomInset =
        PratiCaseResponsive.bottomNavigationOuterPaddingForWidth(width);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          bottomInset,
        ),
        child: Container(
          height: navHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
            border: Border.all(
              color: PratiCaseColors.border.withValues(alpha: 0.60),
            ),
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
                identifier: 'nav.wallet',
                selected: selectedIndex == 1,
                icon: selectedIndex == 1
                    ? Icons.account_balance_wallet_rounded
                    : Icons.account_balance_wallet_outlined,
                label: 'Cüzdan',
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
                icon: selectedIndex == 4
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
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
    final compact = PratiCaseResponsive.isCompactPhone(context);
    final itemHeight =
        (PratiCaseResponsive.bottomNavigationHeightForWidth(
                  MediaQuery.sizeOf(context).width,
                ) -
                20)
            .clamp(54.0, 62.0)
            .toDouble();
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
            height: itemHeight,
            margin: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
            decoration: BoxDecoration(
              color: selected
                  ? PratiCaseColors.teal.withValues(alpha: 0.11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
              border: selected
                  ? Border.all(
                      color: PratiCaseColors.teal.withValues(alpha: 0.10),
                    )
                  : null,
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
                        scale: Tween<double>(
                          begin: 0.86,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    icon,
                    key: ValueKey(selected),
                    color: color,
                    size: compact ? 22 : 24,
                  ),
                ),
                SizedBox(height: compact ? 3 : PratiCaseSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: compact ? 10.5 : 11,
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
    required this.oralExamRepository,
    required this.onOpenCases,
    required this.onOpenSingleStation,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.unreadNotificationCount,
  });

  final ProgressRepository progressRepository;
  final TheoreticalExamRepository theoreticalExamRepository;
  final OralExamRepository oralExamRepository;
  final VoidCallback onOpenCases;
  final VoidCallback onOpenSingleStation;
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
                const PratiCaseInlineSkeleton(heroHeight: 160, cardCount: 3)
              else if (snapshot.hasError)
                _ShellStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Sınavlar açılamadı',
                  body: _errorText(snapshot.error),
                )
              else if (modes.isEmpty)
                const _ShellStateCard(
                  icon: Icons.assignment_outlined,
                  title: 'Sınav modu bulunamadı',
                  body: 'Sınav seçenekleri hazır olduğunda burada görünecek.',
                )
              else ...[
                _ExamFocusHero(modes: modes),
                const SizedBox(height: 18),
                _ExamQuickStart(
                  modes: modes,
                  onOpenMode: (mode) => _openExamMode(context, mode.actionKey),
                ),
                const SizedBox(height: 22),
                _ExamModeGrid(
                  modes: modes,
                  onOpenMode: (mode) => _openExamMode(context, mode.actionKey),
                ),
              ],
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
      case 'oral_exam':
      case 'sozlu_sinav':
      case 'oral_exam_committee':
      case 'komite_sinav':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                OralExamSetupScreen(repository: widget.oralExamRepository),
          ),
        );
        return;
      case 'single_station':
        widget.onOpenSingleStation();
        return;
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
  const _ProgressSummaryScreen({
    required this.repository,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.unreadNotificationCount,
  });

  final ProgressRepository repository;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final int unreadNotificationCount;

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
              _ShellBrandHeader(
                onOpenNotifications: widget.onOpenNotifications,
                onOpenProfile: widget.onOpenProfile,
                unreadNotificationCount: widget.unreadNotificationCount,
              ),
              const SizedBox(height: 34),
              const _ShellTitle(
                title: 'Gelişim',
                subtitle:
                    'OSCE performansını, zayıf alanlarını ve son karnelerini tek yerde izle.',
              ),
              const SizedBox(height: 24),
              if (snapshot.connectionState != ConnectionState.done)
                const PratiCaseInlineSkeleton(heroHeight: 182, cardCount: 3)
              else if (snapshot.hasError)
                const _ShellStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Gelişim açılamadı',
                  body:
                      'Bir bağlantı sorunu oluştu. Sayfayı aşağı çekerek tekrar dene.',
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
    final osce = modes
        .where(
          (mode) => {
            'single_station',
            'mini_osce',
            'branch_package',
            'cases',
          }.contains(mode.actionKey),
        )
        .toList();
    final study = modes
        .where(
          (mode) => {
            'oral_exam',
            'sozlu_sinav',
            'oral_exam_committee',
            'komite_sinav',
            'theoretical_exam',
            'kuramsal_sinav',
          }.contains(mode.actionKey),
        )
        .toList();
    final repeat = modes
        .where((mode) => mode.actionKey == 'weak_areas')
        .toList();
    final used = {...osce, ...study, ...repeat};
    final other = modes.where((mode) => !used.contains(mode)).toList();
    return FadeSlideInList(
      stagger: const Duration(milliseconds: 70),
      children: [
        if (osce.isNotEmpty)
          _ExamModeSection(
            title: 'OSCE Pratiği',
            subtitle: 'Süreli istasyon ve paket seçimi.',
            icon: Icons.assignment_ind_rounded,
            accent: PratiCaseColors.teal,
            modes: osce,
            onOpenMode: onOpenMode,
          ),
        if (study.isNotEmpty)
          _ExamModeSection(
            title: 'Sözlü ve Teori',
            subtitle: 'Hoca karşısı prova ve Medasi soru havuzu.',
            icon: Icons.school_rounded,
            accent: PratiCaseColors.slateBlue,
            modes: study,
            onOpenMode: onOpenMode,
          ),
        if (repeat.isNotEmpty)
          _ExamModeSection(
            title: 'Hedefli Tekrar',
            subtitle: 'Zayıf başlıkları sınav planına dönüştür.',
            icon: Icons.track_changes_rounded,
            accent: PratiCaseColors.gold,
            modes: repeat,
            onOpenMode: onOpenMode,
          ),
        if (other.isNotEmpty)
          _ExamModeSection(
            title: 'Diğer Sınavlar',
            accent: PratiCaseColors.slateBlue,
            modes: other,
            onOpenMode: onOpenMode,
          ),
      ],
    );
  }
}

class _ExamFocusHero extends StatelessWidget {
  const _ExamFocusHero({required this.modes});

  final List<ExamModeItem> modes;

  int _count(Set<String> keys) =>
      modes.where((m) => keys.contains(m.actionKey)).length;

  @override
  Widget build(BuildContext context) {
    final osceCount = _count(const {
      'single_station',
      'mini_osce',
      'branch_package',
      'cases',
    });
    final oralCount = _count(const {
      'oral_exam',
      'sozlu_sinav',
      'oral_exam_committee',
      'komite_sinav',
    });
    final theoreticalCount = _count(const {
      'theoretical_exam',
      'kuramsal_sinav',
    });

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
              child: CustomPaint(painter: _ExamHeroPatternPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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
                          Icons.fact_check_rounded,
                          size: 13,
                          color: PratiCaseColors.tealBright,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Sınav Merkezi',
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
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PratiCaseColors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                      border: Border.all(
                        color: PratiCaseColors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: PratiCaseColors.tealBright,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Bugün hangi sınav modunda pratik?',
                maxLines: 2,
                style: TextStyle(
                  color: PratiCaseColors.white,
                  fontSize: 22,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Önce hedefini seç, sonra istasyona ya da soru havuzuna gir.',
                style: TextStyle(
                  color: PratiCaseColors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExamHeroChip(
                    icon: Icons.assignment_ind_rounded,
                    label: 'OSCE',
                    count: osceCount,
                  ),
                  _ExamHeroChip(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Sözlü',
                    count: oralCount,
                  ),
                  _ExamHeroChip(
                    icon: Icons.school_rounded,
                    label: 'Teorik',
                    count: theoreticalCount,
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

class _ExamHeroChip extends StatelessWidget {
  const _ExamHeroChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: PratiCaseColors.white.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: PratiCaseColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: PratiCaseColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamHeroPatternPainter extends CustomPainter {
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

class _ExamQuickStart extends StatelessWidget {
  const _ExamQuickStart({required this.modes, required this.onOpenMode});

  final List<ExamModeItem> modes;
  final ValueChanged<ExamModeItem> onOpenMode;

  ExamModeItem? _byKey(Set<String> keys) {
    for (final mode in modes) {
      if (keys.contains(mode.actionKey)) return mode;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = <_QuickStartItem>[];
    final single = _byKey(const {'single_station'});
    final miniOsce = _byKey(const {'mini_osce'});
    final theoretical = _byKey(const {'theoretical_exam', 'kuramsal_sinav'});
    final oral = _byKey(const {
      'oral_exam',
      'sozlu_sinav',
      'oral_exam_committee',
    });

    if (single != null) {
      items.add(
        _QuickStartItem(
          mode: single,
          label: 'Tek İstasyon',
          helper: 'Tek senaryo, hızlı başla',
          icon: Icons.timer_rounded,
          accent: PratiCaseColors.teal,
        ),
      );
    }
    if (miniOsce != null) {
      items.add(
        _QuickStartItem(
          mode: miniOsce,
          label: 'Mini OSCE',
          helper: 'Çoklu istasyon paketi',
          icon: Icons.view_week_rounded,
          accent: PratiCaseColors.slateBlue,
        ),
      );
    }
    if (theoretical != null) {
      items.add(
        _QuickStartItem(
          mode: theoretical,
          label: 'Teorik Sınav',
          helper: 'Soru havuzundan dene',
          icon: Icons.school_rounded,
          accent: PratiCaseColors.gold,
        ),
      );
    } else if (oral != null) {
      items.add(
        _QuickStartItem(
          mode: oral,
          label: 'Sözlü Sınav',
          helper: 'Hoca karşısı prova',
          icon: Icons.record_voice_over_rounded,
          accent: PratiCaseColors.gold,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Hızlı Başla',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            const spacing = 10.0;
            final columns = wide ? items.length.clamp(1, 3) : 1;
            if (columns <= 1) {
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _QuickStartCard(
                      item: items[i],
                      onTap: () => onOpenMode(items[i].mode),
                    ),
                    if (i != items.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final it in items)
                  SizedBox(
                    width: width,
                    child: _QuickStartCard(
                      item: it,
                      onTap: () => onOpenMode(it.mode),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickStartItem {
  const _QuickStartItem({
    required this.mode,
    required this.label,
    required this.helper,
    required this.icon,
    required this.accent,
  });

  final ExamModeItem mode;
  final String label;
  final String helper;
  final IconData icon;
  final Color accent;
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard({required this.item, required this.onTap});

  final _QuickStartItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PratiCaseColors.white,
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          border: Border.all(color: item.accent.withValues(alpha: 0.22)),
          boxShadow: PratiCaseShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: item.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ExamModeSection extends StatelessWidget {
  const _ExamModeSection({
    required this.title,
    required this.modes,
    required this.onOpenMode,
    required this.accent,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final List<ExamModeItem> modes;
  final ValueChanged<ExamModeItem> onOpenMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PratiCaseGroupedSection(
        title: title,
        subtitle: subtitle,
        icon: icon,
        children: [
          for (final mode in modes)
            _ExamModeCompactTile(
              icon: _examModeIcon(mode.iconKey),
              title: _examModeTitle(mode),
              subtitle: _examModeSubtitle(mode),
              accent: accent,
              onTap: () => onOpenMode(mode),
            ),
        ],
      ),
    );
  }
}

class _ExamModeCompactTile extends StatelessWidget {
  const _ExamModeCompactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      height: 1.32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: accent),
          ],
        ),
      ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
  const _ProgressHero({required this.profile, required this.summary});

  final ProfileCard profile;
  final ClinicalProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final liveAverage = summary.recentResults.isEmpty
        ? profile.successRatePercent
        : (summary.recentResults
                      .map((item) => item.score)
                      .reduce((a, b) => a + b) /
                  summary.recentResults.length)
              .round();
    final weakestScores = [...summary.categoryScores]
      ..sort((a, b) => a.percent.compareTo(b.percent));
    final weakest = weakestScores.isEmpty ? null : weakestScores.first;
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
              child: CustomPaint(painter: _ProgressHeroPatternPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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
                          Icons.trending_up_rounded,
                          size: 13,
                          color: PratiCaseColors.tealBright,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Performans Özeti',
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
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PratiCaseColors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                      border: Border.all(
                        color: PratiCaseColors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: PratiCaseColors.tealBright,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '%$liveAverage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      height: 0.96,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'ortalama',
                      style: TextStyle(
                        color: PratiCaseColors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary.sessionCount == 0
                    ? 'Tamamlanan sınav karnesi oluştuğunda trendin burada görünür.'
                    : '${summary.sessionCount} oturumdan gelen klinik beceri ortalaması.',
                style: TextStyle(
                  color: PratiCaseColors.white.withValues(alpha: 0.76),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ProgressHeroMetric(
                      label: 'Hedef',
                      value: profile.target.isEmpty
                          ? 'Belirlenmedi'
                          : profile.target,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProgressHeroMetric(
                      label: 'Seri',
                      value: '${profile.dailyStreak} gün',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProgressHeroMetric(
                      label: 'Odak',
                      value: weakest?.label ?? '-',
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

class _ProgressHeroPatternPainter extends CustomPainter {
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

class _ProgressHeroMetric extends StatelessWidget {
  const _ProgressHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.1),
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
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
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

class _SkillBars extends StatelessWidget {
  const _SkillBars({required this.summary});

  final ClinicalProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Anamnez', summary.percentFor('history'), PratiCaseColors.teal),
      (
        'İletişim',
        summary.percentFor('communication'),
        PratiCaseColors.tealBright,
      ),
      ('Fizik Muayene', summary.percentFor('physical'), PratiCaseColors.teal),
      ('Tetkik İnceleme', summary.percentFor('tests'), PratiCaseColors.teal),
      (
        'Ayırıcı Tanı',
        summary.percentFor('diagnosis'),
        PratiCaseColors.tealBright,
      ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: PratiCaseCurves.overshoot,
              builder: (context, v, _) => Text(
                '%${v.round()}',
                style: const TextStyle(
                  color: PratiCaseColors.slateBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 900),
            curve: PratiCaseCurves.overshoot,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: color,
              backgroundColor: PratiCaseColors.surfaceContainerHighest,
            ),
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
            title: 'Klinik Sonuç Trendi',
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
            title: 'Klinik Geri Bildirim',
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
              _ProgressHero(profile: profile, summary: summary),
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
                  _ProgressHero(profile: profile, summary: summary),
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
    case 'oral_exam':
    case 'voice':
      return Icons.record_voice_over_rounded;
    default:
      return Icons.assignment_outlined;
  }
}

String _examModeTitle(ExamModeItem mode) {
  if (mode.actionKey == 'mini_osce') return 'Mini OSCE Planı';
  return mode.title;
}

String _examModeSubtitle(ExamModeItem mode) {
  if (mode.actionKey == 'mini_osce') {
    return 'Çoklu istasyon paketi; seçimden sonra tek istasyonla başlar.';
  }
  if ({
    'oral_exam',
    'sozlu_sinav',
    'oral_exam_committee',
    'komite_sinav',
  }.contains(mode.actionKey)) {
    return 'Gerçek sınav tonu; kısa takip soruları ve rubrik karne.';
  }
  return mode.subtitle;
}

String _errorText(Object? error) {
  return PratiCaseUserMessage.from(error);
}
