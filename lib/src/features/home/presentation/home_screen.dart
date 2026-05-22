import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
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
    this.onOpenProgress,
    this.onOpenNotifications,
    this.onOpenBadges,
    super.key,
  });

  final HomeRepository repository;
  final CasesRepository casesRepository;
  final VoidCallback? onOpenCases;
  final VoidCallback? onOpenExams;
  final VoidCallback? onOpenProgress;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenBadges;

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
                : 'Ana ekran canlı verisi yüklenemedi.',
            onRetry: _refresh,
          );
        }
        final dashboard = snapshot.requireData;
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 132;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding),
            children: [
              _HomeHeader(
                dashboard: dashboard,
                onOpenNotifications: widget.onOpenNotifications,
              ),
              const SizedBox(height: 26),
              _Greeting(user: dashboard.user, onSearch: widget.onOpenCases),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Devam Edilen Vaka',
                onViewAll: widget.onOpenCases,
              ),
              const SizedBox(height: 12),
              _ContinuedCaseCard(
                continuedCase: dashboard.continuedCase,
                onOpenCase: dashboard.continuedCase == null
                    ? null
                    : () => _openCaseDetail(dashboard.continuedCase!.caseId),
              ),
              const SizedBox(height: 24),
              _BannerCarousel(
                banners: dashboard.banners,
                onCta: widget.onOpenCases,
              ),
              const SizedBox(height: 24),
              _QuickActions(
                onSingleStation: widget.onOpenCases,
                onMiniOsce: widget.onOpenExams,
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Genel Bakış',
                onViewAll: widget.onOpenProgress,
              ),
              const SizedBox(height: 12),
              _StatsStrip(stats: dashboard.stats),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Önerilen Vakalar',
                onViewAll: widget.onOpenCases,
              ),
              const SizedBox(height: 12),
              _RecommendedCases(
                cases: dashboard.recommendedCases,
                onOpenCase: _openCaseDetail,
              ),
              const SizedBox(height: 26),
              _BadgePanel(
                summary: dashboard.badgeSummary,
                onOpenBadges: widget.onOpenBadges,
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.dashboard,
    required this.onOpenNotifications,
  });

  final HomeDashboard dashboard;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/branding/praticase.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: RichText(
              maxLines: 1,
              text: const TextSpan(
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 25,
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
        const SizedBox(width: 12),
        _NotificationBell(
          count: dashboard.unreadNotificationCount,
          onTap: onOpenNotifications,
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 21,
          backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.14),
          child: Text(
            dashboard.user.initials,
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user, required this.onSearch});

  final HomeUser user;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba, ${user.firstName}!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bugün pratiğe ne dersin?',
                style: TextStyle(
                  color: Color(0xFF617086),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _SearchPill(onTap: onSearch),
      ],
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, required this.onCta});

  final List<HomeBanner> banners;
  final VoidCallback? onCta;

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
        title: 'Canlı ana ekran içeriği bekleniyor',
        body: 'Yayınlanan ana ekran duyuruları burada görünecek.',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              return _HeroBanner(
                banner: widget.banners[index],
                onCta: widget.onCta,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < widget.banners.length; index++)
              Container(
                width: index == _activeIndex ? 9 : 8,
                height: index == _activeIndex ? 9 : 8,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: index == _activeIndex
                      ? PratiCaseColors.teal
                      : const Color(0xFFD1D8E1),
                  shape: BoxShape.circle,
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
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF043844), Color(0xFF075E6A)],
        ),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            const Positioned(
              right: 12,
              top: 26,
              bottom: 18,
              child: _ClinicalIllustration(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 110, 18),
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
                            fontSize: 19,
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

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const _EmptyPanel(
        icon: Icons.query_stats_rounded,
        title: 'Canlı performans verisi yok',
        body: 'Performans verilerin sınav çözdükçe burada oluşacak.',
      );
    }

    final items = [
      _StatItem(
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF15A3A1),
        value: stats!.solvedCaseCount.toString(),
        label: 'Çözülen Vaka',
        delta: '↗ %${stats!.solvedDeltaPercent}',
      ),
      _StatItem(
        icon: Icons.track_changes_rounded,
        color: PratiCaseColors.gold,
        value: '%${stats!.successRatePercent}',
        label: 'Başarı Oranı',
        delta: '↗ %${stats!.successDeltaPercent}',
      ),
      _StatItem(
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF7867D8),
        value: stats!.totalPoints.toString(),
        label: 'Toplam Puan',
        delta: '↗ %${stats!.pointsDeltaPercent}',
      ),
      _StatItem(
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFEF6767),
        value: stats!.dailyStreak.toString(),
        label: 'Günlük Seri',
        delta: stats!.streakLabel ?? 'Devam!',
      ),
    ];

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _StatCard(item: items[index]),
      ),
    );
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
        title: 'Devam eden canlı oturum yok',
        body: 'Kullanıcının başladığı vaka burada görünecek.',
      );
    }

    return Container(
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
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (item.progressPercent.clamp(0, 100)) / 100,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE8EDF2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      PratiCaseColors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'İlerleme: %${item.progressPercent}',
                  style: const TextStyle(
                    color: Color(0xFF64728A),
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
        title: 'Önerilen canlı vaka yok',
        body: 'Kişisel vaka önerilerin hazır olduğunda burada görünecek.',
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cases.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _RecommendedCaseCard(
          recommendedCase: cases[index],
          onTap: () => onOpenCase(cases[index].caseId),
        ),
      ),
    );
  }
}

class _RecommendedCaseCard extends StatelessWidget {
  const _RecommendedCaseCard({
    required this.recommendedCase,
    required this.onTap,
  });

  final RecommendedCase recommendedCase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 178,
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
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendedCase.branch,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF617086),
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
                      color: Color(0xFF42526B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  recommendedCase.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: const Color(0xFF5B6A84),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onSingleStation,
    required this.onMiniOsce,
  });

  final VoidCallback? onSingleStation;
  final VoidCallback? onMiniOsce;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.08,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _QuickActionCard(
          icon: Icons.assignment_ind_rounded,
          title: 'Tek İstasyon',
          subtitle: 'Odaklanmış senaryo',
          onTap: onSingleStation,
        ),
        _QuickActionCard(
          icon: Icons.view_kanban_rounded,
          title: 'Mini OSCE',
          subtitle: '3 istasyonlu deneme',
          onTap: onMiniOsce,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SoftIcon(icon: icon, color: PratiCaseColors.teal, size: 48),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF68768E),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
        color: const Color(0xFFEAF6F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
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
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  summary!.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF33465C),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onOpenBadges,
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(summary!.actionLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: PratiCaseColors.teal),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          color: PratiCaseColors.teal,
          size: 52,
        ),
        const SizedBox(height: 18),
        const Text(
          'Canlı veri bağlantısı gerekli',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF5F6D7E),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar Dene'),
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
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF64728A),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: PratiCaseColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: PratiCaseColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF68768E)),
            SizedBox(width: 8),
            Text(
              'Arama',
              style: TextStyle(
                color: Color(0xFF68768E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        _IconButtonShell(icon: Icons.notifications_none_rounded, onTap: onTap),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SoftIcon(icon: item.icon, color: item.color, size: 38),
          const SizedBox(height: 8),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7B8798),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.delta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.teal,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [PratiCaseColors.teal, Color(0xFF004D5C)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
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
        borderRadius: BorderRadius.circular(8),
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
      width: 122,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 12,
            left: 0,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 84,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF7BC8C2),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 22,
            child: Container(
              width: 86,
              height: 126,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4ED),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFB5DDD8), width: 6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _CheckLine(),
                  SizedBox(height: 12),
                  _CheckLine(),
                  SizedBox(height: 12),
                  _CheckLine(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: Container(
              width: 48,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF384E62),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 0,
            child: Container(
              width: 44,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFF2EEE4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20384A),
                    borderRadius: BorderRadius.circular(9),
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

class _CheckLine extends StatelessWidget {
  const _CheckLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_rounded, color: PratiCaseColors.teal, size: 18),
        const SizedBox(width: 6),
        Container(
          width: 34,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD9D5CF),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.delta,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String delta;
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: PratiCaseColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: PratiCaseColors.border),
    boxShadow: [
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
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
      return const Color(0xFF2AA765);
    case CaseDifficulty.medium:
      return PratiCaseColors.gold;
    case CaseDifficulty.hard:
      return const Color(0xFFE04F5F);
  }
}
