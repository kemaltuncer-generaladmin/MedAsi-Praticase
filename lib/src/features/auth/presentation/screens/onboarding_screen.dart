import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_accent.dart';
import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_motion.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../../../shared/ui/animated_mesh_background.dart';
import '../../../../shared/ui/glass_card.dart';
import '../../../../shared/ui/glow_button.dart';

/// PratiCase Onboarding — 3 sayfa, glassmorphism + canlı mesh background +
/// staggered intro animasyonları + spring CTA.
///
/// Performans:
/// - Tek bir [PageController] + 2 [AnimationController] (intro + bg).
/// - Mesh background ayrı bir `RepaintBoundary` içinde; sayfa değişiminde
///   yeniden çizilmez.
/// - Her sayfa, [PageView] tarafından sağlanan offset'i kullanarak
///   parallax + alpha hesaplar (rebuild yok — `AnimatedBuilder`).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onCreateAccount,
    required this.onLogin,
    super.key,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      tag: 'KLİNİK SİMÜLASYON',
      title: 'Klinik Akıl Yürütmeni\nGüvenle Geliştir',
      subtitle:
          'Gerçekçi OSCE vakaları, anamnezden tanıya kadar adım adım pratik fırsatı.',
      icon: Icons.medical_services_rounded,
      accentTone: _AccentTone.teal,
    ),
    _OnboardingSlide(
      tag: 'SÖZLÜ SINAV',
      title: 'Hoca Karşısı\nProvayı Şimdi Yap',
      subtitle:
          'AI panel üyeleri seni sözlü sınav tonunda dinler, takip sorularıyla zorlar.',
      icon: Icons.record_voice_over_rounded,
      accentTone: _AccentTone.navy,
    ),
    _OnboardingSlide(
      tag: 'GELİŞİM TAKİBİ',
      title: 'Zayıf Alanlarını\nGerçek Veriyle Gör',
      subtitle:
          'Anamnez, fizik muayene, tanı ve yönetim becerin canlı karnelerle takipte.',
      icon: Icons.insights_rounded,
      accentTone: _AccentTone.gold,
    ),
  ];

  final PageController _pageController = PageController();
  late final AnimationController _introController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _next() {
    if (_activeIndex >= _slides.length - 1) {
      widget.onCreateAccount();
      return;
    }
    _pageController.nextPage(
      duration: PratiCaseDurations.emphasized,
      curve: PratiCaseCurves.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = PratiCaseAccent.instance;
    final mediaPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      body: Stack(
        children: [
          // 1. Canlı mesh background — alttaki en kalın katman.
          Positioned.fill(
            child: AnimatedMeshBackground(
              colors: [
                accent.bright,
                accent.primary,
                PratiCaseColors.gold,
                PratiCaseColors.navy,
              ],
              opacity: 1.0,
              speed: 0.6,
            ),
          ),

          // 2. Subtle white veil — okunabilirlik için.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    PratiCaseColors.softSurface.withValues(alpha: 0.55),
                    PratiCaseColors.softSurface.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),

          // 3. İçerik.
          SafeArea(
            child: Column(
              children: [
                // Üst sıra: logo + skip.
                _OnboardingTopBar(
                  onSkip: widget.onLogin,
                  introController: _introController,
                ),
                // PageView içeriği.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _activeIndex = i),
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        slide: _slides[index],
                        pageController: _pageController,
                        index: index,
                        introController: _introController,
                      );
                    },
                  ),
                ),
                // Alt: dot indicator + CTA.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    mediaPadding.bottom < 16 ? 16 : mediaPadding.bottom,
                  ),
                  child: Column(
                    children: [
                      _OnboardingDots(
                        count: _slides.length,
                        activeIndex: _activeIndex,
                      ),
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: _introController,
                        builder: (context, child) {
                          final t = Curves.easeOutCubic
                              .transform(_introController.value);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, (1 - t) * 24),
                              child: child,
                            ),
                          );
                        },
                        child: GlowButton(
                          label: _activeIndex == _slides.length - 1
                              ? 'Hesap Oluştur'
                              : 'Devam',
                          icon: Icons.arrow_forward_rounded,
                          pulse: _activeIndex == _slides.length - 1,
                          onPressed: _next,
                          semanticIdentifier: 'cta.onboarding-next',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hesabın var mı?',
                            style: TextStyle(
                              color: PratiCaseColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onLogin,
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/* ───────────────────────── Slide model ───────────────────────── */

enum _AccentTone { teal, navy, gold }

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentTone,
  });

  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final _AccentTone accentTone;

  Color get accent {
    switch (accentTone) {
      case _AccentTone.teal:
        return PratiCaseColors.teal;
      case _AccentTone.navy:
        return PratiCaseColors.slateBlue;
      case _AccentTone.gold:
        return PratiCaseColors.gold;
    }
  }

  Color get accentBright {
    switch (accentTone) {
      case _AccentTone.teal:
        return PratiCaseColors.tealBright;
      case _AccentTone.navy:
        return const Color(0xFF6A85A8);
      case _AccentTone.gold:
        return const Color(0xFFFFC55C);
    }
  }
}

/* ───────────────────────── Top bar ───────────────────────── */

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.onSkip,
    required this.introController,
  });

  final VoidCallback onSkip;
  final AnimationController introController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: introController,
      builder: (context, _) {
        final t =
            Curves.easeOutCubic.transform(introController.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                    child: Image.asset(
                      'assets/auth/praticase_icon.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: PratiCaseColors.muted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    child: const Text('Atla'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ───────────────────────── Single page ───────────────────────── */

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.slide,
    required this.pageController,
    required this.index,
    required this.introController,
  });

  final _OnboardingSlide slide;
  final PageController pageController;
  final int index;
  final AnimationController introController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: pageController,
          builder: (context, _) {
            // Parallax: aktif sayfada 0, kayarken ±1.
            final page = pageController.hasClients &&
                    pageController.position.haveDimensions
                ? pageController.page ?? pageController.initialPage.toDouble()
                : pageController.initialPage.toDouble();
            final delta = (index - page).clamp(-1.0, 1.0);
            return AnimatedBuilder(
              animation: introController,
              builder: (context, _) {
                // Intro phase ilk renderda; sonra delta'ya göre güncellenir.
                final intro =
                    Curves.easeOutCubic.transform(introController.value);
                return _PageContent(
                  slide: slide,
                  delta: delta,
                  intro: intro,
                  height: constraints.maxHeight,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.slide,
    required this.delta,
    required this.intro,
    required this.height,
  });

  final _OnboardingSlide slide;
  final double delta;
  final double intro;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Parallax derecesi: arka illustrasyon delta * 60, ön içerik delta * 28.
    final illustrationOffset = Offset(delta * 0.18 * 280, 0);
    final contentOffset = Offset(delta * 0.08 * 280, 0);
    final fade = (1 - delta.abs()).clamp(0.0, 1.0);
    final introFade = intro;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero illustration with parallax.
              Transform.translate(
                offset: illustrationOffset,
                child: Opacity(
                  opacity: fade * introFade,
                  child: _HeroIllustration(slide: slide, intro: intro),
                ),
              ),
              const SizedBox(height: 28),
              // Glass card with text.
              Transform.translate(
                offset: contentOffset,
                child: Opacity(
                  opacity: fade,
                  child: GlassCard(
                    radius: PratiCaseRadius.xxl,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    surfaceOpacity: 0.86,
                    tint: PratiCaseColors.white,
                    borderColor:
                        slide.accent.withValues(alpha: 0.16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Reveal(
                          delay: 0.0,
                          intro: intro,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: slide.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  PratiCaseRadius.pill),
                            ),
                            child: Text(
                              slide.tag,
                              style: TextStyle(
                                color: slide.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Reveal(
                          delay: 0.15,
                          intro: intro,
                          child: Text(
                            slide.title,
                            style: const TextStyle(
                              color: PratiCaseColors.navy,
                              fontSize: 26,
                              height: 1.18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Reveal(
                          delay: 0.30,
                          intro: intro,
                          child: Text(
                            slide.subtitle,
                            style: const TextStyle(
                              color: PratiCaseColors.muted,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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

/* ───────────────────────── Reveal (staggered intro) ───────────────────────── */

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.child,
    required this.intro,
    required this.delay,
  });

  final Widget child;
  final double intro;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final local = ((intro - delay) / (1 - delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 16),
        child: child,
      ),
    );
  }
}

/* ───────────────────────── Hero illustration ───────────────────────── */

class _HeroIllustration extends StatefulWidget {
  const _HeroIllustration({required this.slide, required this.intro});

  final _OnboardingSlide slide;
  final double intro;

  @override
  State<_HeroIllustration> createState() => _HeroIllustrationState();
}

class _HeroIllustrationState extends State<_HeroIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9000),
  )..repeat();

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: AnimatedBuilder(
        animation: _orbit,
        builder: (context, _) {
          return CustomPaint(
            painter: _HeroPainter(
              orbit: _orbit.value,
              accent: widget.slide.accent,
              bright: widget.slide.accentBright,
            ),
            child: Center(
              child: Transform.scale(
                scale: 0.85 + Curves.easeOutCubic.transform(widget.intro) * 0.15,
                child: GlassCardDark(
                  padding: const EdgeInsets.all(22),
                  radius: 32,
                  child: Icon(
                    widget.slide.icon,
                    color: PratiCaseColors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter({
    required this.orbit,
    required this.accent,
    required this.bright,
  });

  final double orbit;
  final Color accent;
  final Color bright;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer soft glow halo.
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.35),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, haloPaint);

    // Orbital rings (2).
    for (var ring = 0; ring < 2; ring++) {
      final r = radius * (0.62 + ring * 0.20);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = bright.withValues(alpha: 0.18 - ring * 0.06);
      canvas.drawCircle(center, r, ringPaint);
    }

    // Orbiting dots.
    final dotPaint = Paint()..color = bright.withValues(alpha: 0.85);
    for (var i = 0; i < 3; i++) {
      final angle = orbit * 2 * math.pi + i * (2 * math.pi / 3);
      final r = radius * 0.78;
      final dot = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      canvas.drawCircle(dot, 4.5, dotPaint);
    }

    // Inner glow ring.
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = PratiCaseColors.white.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius * 0.42, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) {
    return old.orbit != orbit ||
        old.accent != accent ||
        old.bright != bright;
  }
}

/* ───────────────────────── Dots ───────────────────────── */

class _OnboardingDots extends StatelessWidget {
  const _OnboardingDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final accent = PratiCaseAccent.instance.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == activeIndex ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? accent
                  : PratiCaseColors.border.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
              boxShadow: i == activeIndex
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 12,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}
