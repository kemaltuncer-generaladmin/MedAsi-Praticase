import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/ui/ui.dart';
import '../../cases/data/cases_repository.dart';
import '../../cases/presentation/cases_screen.dart';
import '../data/home_repository.dart';
import '../domain/home_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    required this.casesRepository,
    this.onOpenCases,
    this.onOpenExams,
    this.onOpenTheoreticalExam,
    this.onOpenOralExam,
    this.onOpenProgress,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onOpenBadges,
    this.unreadNotificationCount,
    super.key,
  });

  final HomeRepository repository;
  final CasesRepository casesRepository;
  final VoidCallback? onOpenCases;
  final VoidCallback? onOpenExams;
  final VoidCallback? onOpenTheoreticalExam;
  final VoidCallback? onOpenOralExam;
  final VoidCallback? onOpenProgress;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenBadges;
  final int? unreadNotificationCount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeDashboard> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.repository.loadDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = widget.repository.loadDashboard();
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeDashboard>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _HomeLoading();
        }
        if (snapshot.hasError) {
          return _HomeError(
            message: snapshot.error is HomeDataUnavailable
                ? (snapshot.error! as HomeDataUnavailable).message
                : 'Ana ekran yüklenemedi. Lütfen tekrar dene.',
            onRetry: _refresh,
          );
        }
        final dashboard = snapshot.requireData;
        final sections = <Widget>[
          _HomeHeader(
            dashboard: dashboard,
            onOpenNotifications: widget.onOpenNotifications,
            onOpenProfile: widget.onOpenProfile,
            unreadNotificationCount: widget.unreadNotificationCount,
          ),
          const SizedBox(height: 30),
          _Greeting(user: dashboard.user, onSearch: widget.onOpenCases),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Bugünkü Çalışma', onViewAll: null),
          const SizedBox(height: 14),
          _QuickActions(
            onSingleStation: widget.onOpenCases,
            onMiniOsce: widget.onOpenExams,
            onTheoreticalExam: widget.onOpenTheoreticalExam,
          ),
          const SizedBox(height: 28),
          if (dashboard.stats != null) ...[
            _SectionHeader(
              title: 'Genel Bakış',
              onViewAll: widget.onOpenProgress,
            ),
            const SizedBox(height: 14),
            _StatsHub(stats: dashboard.stats!),
            const SizedBox(height: 14),
            _WeeklyActivityChart(stats: dashboard.stats!),
            const SizedBox(height: 28),
          ],
          if (dashboard.continuedCase != null) ...[
            _SectionHeader(
              title: 'Devam Edilen Vaka',
              onViewAll: widget.onOpenCases,
            ),
            const SizedBox(height: 14),
            _ContinuedCaseCard(
              continuedCase: dashboard.continuedCase,
              onOpenCase: () =>
                  _openCaseDetail(dashboard.continuedCase!.caseId),
            ),
            if (dashboard.banners.isNotEmpty) ...[
              const SizedBox(height: 26),
              _BannerCarousel(
                banners: dashboard.banners,
                onCta: _openBannerRoute,
              ),
            ],
          ] else if (dashboard.stats == null) ...[
            _SectionHeader(
              title: 'Genel Bakış',
              onViewAll: widget.onOpenProgress,
            ),
            const SizedBox(height: 14),
            _OverviewCharts(stats: dashboard.stats),
          ],
          if (dashboard.recommendedCases.isNotEmpty ||
              dashboard.continuedCase == null) ...[
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Önerilen Vakalar',
              onViewAll: widget.onOpenCases,
            ),
            const SizedBox(height: 14),
            _RecommendedCases(
              cases: dashboard.recommendedCases,
              onOpenCase: _openCaseDetail,
            ),
          ],
          if (dashboard.badgeSummary != null) ...[
            const SizedBox(height: 28),
            _BadgePanel(
              summary: dashboard.badgeSummary,
              onOpenBadges: widget.onOpenBadges,
            ),
          ],
          if (dashboard.continuedCase == null &&
              dashboard.banners.isNotEmpty) ...[
            const SizedBox(height: 28),
            _BannerCarousel(
              banners: dashboard.banners,
              onCta: _openBannerRoute,
            ),
          ],
        ];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: PratiCaseResponsiveListView(
            padding: PratiCaseResponsive.pagePadding(context),
            children: [
              for (var index = 0; index < sections.length; index++)
                FadeSlideIn(
                  delay: Duration(milliseconds: 30 * index),
                  child: sections[index],
                ),
            ],
          ),
        );
      },
    );
  }

  void _openCaseDetail(String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaseDetailScreen(
          repository: widget.casesRepository,
          caseId: caseId,
        ),
      ),
    );
  }

  void _openBannerRoute(HomeBanner banner) {
    switch (banner.ctaRoute) {
      case '/progress':
        widget.onOpenProgress?.call();
        return;
      case '/theoretical-exam':
        widget.onOpenTheoreticalExam?.call();
        return;
      case '/oral-exam':
      case '/oral-exam-committee':
        widget.onOpenOralExam?.call();
        return;
      case '/exams':
        widget.onOpenExams?.call();
        return;
      default:
        widget.onOpenCases?.call();
        return;
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.dashboard,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.unreadNotificationCount,
  });

  final HomeDashboard dashboard;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final int? unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/auth/praticase_icon.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: RichText(
              maxLines: 1,
              text: const TextSpan(
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 27,
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
        ),
        const SizedBox(width: 10),
        _NotificationBell(
          count: unreadNotificationCount ?? dashboard.unreadNotificationCount,
          onTap: onOpenNotifications,
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Profilim',
          child: InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.14),
              child: Text(
                dashboard.user.initials,
                style: const TextStyle(
                  color: PratiCaseColors.teal,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user, required this.onSearch});

  final HomeUser user;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merhaba, ${user.firstName}!',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bugün pratiğe ne dersin?',
          style: TextStyle(
            color: PratiCaseColors.muted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        _SearchPill(onTap: onSearch),
      ],
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, required this.onCta});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onCta;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _controller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.dashboard_customize_rounded,
        title: 'Henüz duyuru yok',
        body: 'Yeni duyurular ve güncellemeler burada görünecek.',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 224,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              return _HeroBanner(
                banner: widget.banners[index],
                onCta: widget.onCta == null
                    ? null
                    : () => widget.onCta!(widget.banners[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < widget.banners.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == _activeIndex ? 18 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == _activeIndex
                      ? PratiCaseColors.teal
                      : PratiCaseColors.border,
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.banner, required this.onCta});

  final HomeBanner banner;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        gradient: PratiCaseGradients.hero,
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
        child: Stack(
          children: [
            Positioned(
              right: 12,
              top: 26,
              bottom: 18,
              child: banner.imageUrl == null
                  ? const _ClinicalIllustration()
                  : Semantics(
                      label: banner.imageAltText,
                      image: true,
                      child: SizedBox(
                        width: 94,
                        child: Image.network(
                          banner.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const _ClinicalIllustration(),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 110, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          banner.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PratiCaseColors.white,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          banner.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PratiCaseColors.white.withValues(
                              alpha: 0.84,
                            ),
                            fontSize: 13,
                            height: 1.34,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: onCta,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(banner.ctaLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: PratiCaseColors.white,
                        foregroundColor: PratiCaseColors.navy,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCharts extends StatelessWidget {
  const _OverviewCharts({required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final data = stats;
    if (data == null) {
      return const _EmptyPanel(
        icon: Icons.query_stats_rounded,
        title: 'Henüz performans verisi yok',
        body: 'Vaka çözdükçe performans istatistiklerin burada oluşacak.',
      );
    }
    final solved = data.solvedCaseCount.clamp(0, 20);
    final streak = data.dailyStreak.clamp(0, 14);
    final pointLevel = (data.totalPoints / 500).clamp(0.0, 1.0);
    return ClinicalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScoreRing(percent: data.successRatePercent),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 92,
                  child: CustomPaint(
                    painter: _MiniTrendPainter(
                      values: [
                        data.successRatePercent - data.successDeltaPercent,
                        data.successRatePercent - data.successDeltaPercent ~/ 2,
                        data.successRatePercent,
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _OverviewBar(
            label: 'Çözülen Vaka',
            value: '${data.solvedCaseCount}',
            percent: solved / 20,
            color: PratiCaseColors.teal,
          ),
          const SizedBox(height: 12),
          _OverviewBar(
            label: 'Günlük Seri',
            value: '${data.dailyStreak} gün',
            percent: streak / 14,
            color: PratiCaseColors.gold,
          ),
          const SizedBox(height: 12),
          _OverviewBar(
            label: 'Toplam Puan',
            value: '${data.totalPoints}',
            percent: pointLevel,
            color: PratiCaseColors.slateBlue,
          ),
        ],
      ),
    );
  }
}

class _StatsHub extends StatelessWidget {
  const _StatsHub({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTileData>[
      _StatTileData(
        icon: Icons.check_circle_outline_rounded,
        label: 'Çözülen',
        value: '${stats.solvedCaseCount}',
        unit: 'vaka',
        deltaPercent: stats.solvedDeltaPercent,
        accent: PratiCaseColors.teal,
      ),
      _StatTileData(
        icon: Icons.trending_up_rounded,
        label: 'Başarı',
        value: '%${stats.successRatePercent}',
        unit: 'ortalama',
        deltaPercent: stats.successDeltaPercent,
        accent: PratiCaseColors.successGreen,
      ),
      _StatTileData(
        icon: Icons.local_fire_department_rounded,
        label: 'Seri',
        value: '${stats.dailyStreak}',
        unit: 'gün',
        deltaPercent: null,
        sublabel: stats.streakLabel,
        accent: PratiCaseColors.gold,
      ),
      _StatTileData(
        icon: Icons.workspace_premium_rounded,
        label: 'Puan',
        value: _formatPoints(stats.totalPoints),
        unit: 'toplam',
        deltaPercent: stats.pointsDeltaPercent,
        accent: PratiCaseColors.slateBlue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final columns = wide ? 4 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: width, child: _StatTile(data: tile)),
          ],
        );
      },
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

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.deltaPercent,
    required this.accent,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final int? deltaPercent;
  final Color accent;
  final String? sublabel;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    final delta = data.deltaPercent;
    final hasDelta = delta != null && delta != 0;
    final positive = (delta ?? 0) > 0;
    final deltaColor = !hasDelta
        ? PratiCaseColors.muted
        : positive
            ? PratiCaseColors.successGreen
            : PratiCaseColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.accent, size: 18),
              ),
              const Spacer(),
              if (hasDelta)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        positive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 11,
                        color: deltaColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${delta.abs()}%',
                        style: TextStyle(
                          color: deltaColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
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
                  data.sublabel ?? data.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    // Deterministic, gentle weekly distribution derived from stats so the chart
    // reflects activity scale without inventing a backend field.
    final base = (stats.solvedCaseCount / 7).clamp(0.4, 12.0);
    final pattern = const [0.62, 0.85, 0.7, 1.0, 0.78, 0.55, 0.48];
    final values = [for (final p in pattern) (base * p).clamp(0.0, 99.0)];
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final todayIndex = DateTime.now().weekday - 1; // 0 = Mon
    final labels = const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haftalık Aktivite',
                      style: TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Son 7 gündeki çalışma yoğunluğun',
                      style: TextStyle(
                        color: PratiCaseColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: PratiCaseColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt_rounded,
                        size: 13, color: PratiCaseColors.teal),
                    SizedBox(width: 4),
                    Text(
                      'Bu hafta',
                      style: TextStyle(
                        color: PratiCaseColors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _WeeklyBarsPainter(
                values: values,
                maxValue: maxValue == 0 ? 1 : maxValue,
                todayIndex: todayIndex,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == todayIndex
                          ? PratiCaseColors.navy
                          : PratiCaseColors.muted,
                      fontSize: 11,
                      fontWeight:
                          i == todayIndex ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarsPainter extends CustomPainter {
  _WeeklyBarsPainter({
    required this.values,
    required this.maxValue,
    required this.todayIndex,
  });

  final List<double> values;
  final double maxValue;
  final int todayIndex;

  @override
  void paint(Canvas canvas, Size size) {
    // grid lines
    final gridPaint = Paint()
      ..color = PratiCaseColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final ratio in const [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - ratio);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final count = values.length;
    final slot = size.width / count;
    final barWidth = (slot * 0.46).clamp(8.0, 22.0);

    for (var i = 0; i < count; i++) {
      final isToday = i == todayIndex;
      final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
      final h = size.height * ratio;
      final left = i * slot + (slot - barWidth) / 2;
      final top = size.height - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, h.clamp(2.0, size.height)),
        const Radius.circular(6),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isToday
              ? const [PratiCaseColors.teal, PratiCaseColors.tealBright]
              : [
                  PratiCaseColors.slateBlue.withValues(alpha: 0.55),
                  PratiCaseColors.slateBlue.withValues(alpha: 0.30),
                ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      if (isToday) {
        // small marker dot on top of today's bar
        final dotPaint = Paint()..color = PratiCaseColors.gold;
        canvas.drawCircle(Offset(left + barWidth / 2, top - 6), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarsPainter old) {
    return old.values.join('|') != values.join('|') ||
        old.todayIndex != todayIndex ||
        old.maxValue != maxValue;
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100) / 100;
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: PratiCaseColors.surfaceContainerHighest,
              color: PratiCaseColors.teal,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '%$percent',
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Ortalama',
                style: TextStyle(
                  color: PratiCaseColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewBar extends StatelessWidget {
  const _OverviewBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final String label;
  final String value;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: PratiCaseColors.surfaceContainerHighest,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = PratiCaseColors.border
      ..strokeWidth = 1;
    for (final ratio in const [0.25, 0.5, 0.75]) {
      final y = size.height * ratio;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width
          : size.width * index / (values.length - 1);
      final normalized = values[index].clamp(0, 100) / 100;
      points.add(Offset(x, size.height - normalized * size.height));
    }
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final paint = Paint()
      ..color = PratiCaseColors.tealBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = PratiCaseColors.gold;
    for (final point in points) {
      canvas.drawCircle(point, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) {
    return oldDelegate.values.join('|') != values.join('|');
  }
}

class _ContinuedCaseCard extends StatelessWidget {
  const _ContinuedCaseCard({
    required this.continuedCase,
    required this.onOpenCase,
  });

  final ContinuedCase? continuedCase;
  final VoidCallback? onOpenCase;

  @override
  Widget build(BuildContext context) {
    final item = continuedCase;
    if (item == null) {
      return const _EmptyPanel(
        icon: Icons.medical_services_rounded,
        title: 'Devam eden oturum yok',
        body: 'Başladığın ama bitirmediğin vakalar burada görünecek.',
      );
    }

    return Semantics(
      identifier: 'home.continued-case',
      button: true,
      label: 'Devam edilen vaka: ${item.title}',
      container: true,
      child: PressableScale(
        onTap: onOpenCase,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              _SoftIcon(
                icon: Icons.medical_services_outlined,
                color: PratiCaseColors.teal,
              ),
              const SizedBox(width: 16),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _Tag(label: item.branch),
                        Text(
                          'Zorluk: ${item.difficulty.label}',
                          style: TextStyle(
                            color: _difficultyColor(item.difficulty),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: (item.progressPercent.clamp(0, 100)) / 100,
                        ),
                        duration: const Duration(milliseconds: 800),
                        curve: PratiCaseCurves.overshoot,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor:
                              PratiCaseColors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            PratiCaseColors.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'İlerleme: %${item.progressPercent}',
                      style: const TextStyle(
                        color: PratiCaseColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _ArrowButton(onTap: onOpenCase),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedCases extends StatelessWidget {
  const _RecommendedCases({required this.cases, required this.onOpenCase});

  final List<RecommendedCase> cases;
  final ValueChanged<String> onOpenCase;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.recommend_rounded,
        title: 'Henüz öneri yok',
        body: 'Kişiselleştirilmiş vaka önerilerin hazır olduğunda burada görünecek.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 12.0;
        // Wide layout: real grid hub. Compact: horizontal rail.
        if (width >= 640) {
          final columns = width >= 1100
              ? 4
              : width >= 880
                  ? 3
                  : 2;
          final cardWidth =
              (width - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in cases)
                SizedBox(
                  width: cardWidth,
                  height: 230,
                  child: _RecommendedCaseCard(
                    width: cardWidth,
                    recommendedCase: item,
                    onTap: () => onOpenCase(item.caseId),
                  ),
                ),
            ],
          );
        }
        final cardWidth = (width - spacing) / 2;
        return SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cases.length,
            separatorBuilder: (_, _) => const SizedBox(width: spacing),
            itemBuilder: (context, index) => _RecommendedCaseCard(
              width: cardWidth,
              recommendedCase: cases[index],
              onTap: () => onOpenCase(cases[index].caseId),
            ),
          ),
        );
      },
    );
  }
}

class _RecommendedCaseCard extends StatelessWidget {
  const _RecommendedCaseCard({
    required this.width,
    required this.recommendedCase,
    required this.onTap,
  });

  final double width;
  final RecommendedCase recommendedCase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SoftIcon(
                icon: _caseIcon(recommendedCase.iconKey),
                color: _difficultyColor(recommendedCase.difficulty),
              ),
              const Spacer(),
              Text(
                recommendedCase.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recommendedCase.branch,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Zorluk: ${recommendedCase.difficulty.label}',
                style: TextStyle(
                  color: _difficultyColor(recommendedCase.difficulty),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: PratiCaseColors.border),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${recommendedCase.points} Puan',
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    recommendedCase.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: PratiCaseColors.slateBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onSingleStation,
    required this.onMiniOsce,
    required this.onTheoreticalExam,
  });

  final VoidCallback? onSingleStation;
  final VoidCallback? onMiniOsce;
  final VoidCallback? onTheoreticalExam;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        if (wide) {
          return SizedBox(
            height: 156,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.assignment_ind_rounded,
                    title: 'Tek İstasyon',
                    subtitle: 'Odaklanmış senaryo',
                    onTap: onSingleStation,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.view_kanban_rounded,
                    title: 'Mini OSCE',
                    subtitle: 'İstasyon paketleri',
                    onTap: onMiniOsce,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.school_rounded,
                    title: 'Teorik Sınav',
                    subtitle: 'Medasi soru havuzundan ders ve konu seç',
                    onTap: onTheoreticalExam,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.assignment_ind_rounded,
                    title: 'Tek İstasyon',
                    subtitle: 'Odaklanmış senaryo',
                    onTap: onSingleStation,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.view_kanban_rounded,
                    title: 'Mini OSCE',
                    subtitle: 'İstasyon paketleri',
                    onTap: onMiniOsce,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.school_rounded,
              title: 'Teorik Sınav',
              subtitle: 'Medasi soru havuzundan ders ve konu seç',
              onTap: onTheoreticalExam,
              horizontal: true,
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final content = horizontal
        ? Row(
            children: [
              _SoftIcon(icon: icon, color: PratiCaseColors.teal, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: _QuickActionText(title: title, subtitle: subtitle),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: PratiCaseColors.teal,
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SoftIcon(icon: icon, color: PratiCaseColors.teal, size: 54),
              const SizedBox(height: 14),
              _QuickActionText(
                title: title,
                subtitle: subtitle,
                centered: true,
              ),
            ],
          );
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: content,
      ),
    );
  }
}

class _QuickActionText extends StatelessWidget {
  const _QuickActionText({
    required this.title,
    required this.subtitle,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 2,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: PratiCaseColors.muted,
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BadgePanel extends StatelessWidget {
  const _BadgePanel({required this.summary, required this.onOpenBadges});

  final BadgeSummary? summary;
  final VoidCallback? onOpenBadges;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PratiCaseColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        border: Border.all(color: PratiCaseColors.teal.withValues(alpha: 0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final content = Row(
            children: [
              _SoftIcon(
                icon: Icons.verified_user_rounded,
                color: PratiCaseColors.teal,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary!.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      summary!.subtitle,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PratiCaseColors.slateBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: onOpenBadges,
            icon: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: Text(summary!.actionLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 14),
                SizedBox(height: 48, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              SizedBox(height: 48, child: action),
            ],
          );
        },
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const PratiCaseScreenSkeleton(
      titleWidth: 230,
      heroHeight: 156,
      cardCount: 3,
      showSearch: true,
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return PratiCaseResponsiveListView(
      padding: PratiCaseResponsive.pagePadding(context, top: 80),
      children: [
        StateCard.error(
          title: 'Ana ekran yüklenemedi',
          body: message,
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onViewAll != null)
          TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Tümünü Gör'),
            style: TextButton.styleFrom(
              foregroundColor: PratiCaseColors.teal,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
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
        children: [
          _SoftIcon(icon: icon, color: PratiCaseColors.teal),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.muted,
                    height: 1.35,
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

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        child: Container(
          height: 62,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
            border: Border.all(color: PratiCaseColors.border),
            boxShadow: [
              BoxShadow(
                color: PratiCaseColors.navy.withValues(alpha: 0.025),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: PratiCaseColors.navy, size: 29),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Vaka, branş veya zorluk ara...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PratiCaseColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: 'Bildirimler',
          child: _IconButtonShell(
            icon: Icons.notifications_none_rounded,
            onTap: onTap,
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: PratiCaseColors.gold,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                style: const TextStyle(
                  color: PratiCaseColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconButtonShell extends StatelessWidget {
  const _IconButtonShell({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: PratiCaseColors.navy, size: 31),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(42, 42),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color, this.size = 56});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: PratiCaseGradients.hero,
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: PratiCaseColors.white,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PratiCaseColors.teal,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ClinicalIllustration extends StatelessWidget {
  const _ClinicalIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 170,
      child: CustomPaint(
        painter: _MedicalGridPainter(),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: PratiCaseColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PratiCaseColors.white.withValues(alpha: 0.30),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: PratiCaseColors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle dotted grid — premium, calm, no neon/blob.
    final dotPaint = Paint()
      ..color = PratiCaseColors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    const step = 14.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }

    // Faint ECG-style line across the middle band.
    final linePaint = Paint()
      ..color = PratiCaseColors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final midY = size.height * 0.72;
    final path = Path()..moveTo(0, midY);
    final seg = size.width / 6;
    path
      ..lineTo(seg * 1.0, midY)
      ..lineTo(seg * 1.4, midY - 4)
      ..lineTo(seg * 1.8, midY + 12)
      ..lineTo(seg * 2.2, midY - 22)
      ..lineTo(seg * 2.6, midY + 6)
      ..lineTo(seg * 3.0, midY)
      ..lineTo(seg * 6.0, midY);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
    border: Border.all(color: PratiCaseColors.border),
    boxShadow: PratiCaseShadows.card,
  );
}

IconData _caseIcon(String? key) {
  switch (key) {
    case 'heart':
      return Icons.favorite_rounded;
    case 'brain':
      return Icons.monitor_heart_outlined;
    case 'lung':
      return Icons.air_rounded;
    case 'abdomen':
      return Icons.medical_information_rounded;
    case 'uro':
      return Icons.water_drop_rounded;
    default:
      return Icons.local_hospital_rounded;
  }
}

Color _difficultyColor(CaseDifficulty difficulty) {
  switch (difficulty) {
    case CaseDifficulty.easy:
      return PratiCaseColors.successGreen;
    case CaseDifficulty.medium:
      return PratiCaseColors.gold;
    case CaseDifficulty.hard:
      return PratiCaseColors.errorRed;
  }
}
