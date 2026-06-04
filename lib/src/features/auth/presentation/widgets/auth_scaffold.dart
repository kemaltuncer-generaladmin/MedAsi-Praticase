import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import 'auth_visuals.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.onBack,
    this.bottom,
    this.showFooterText = true,
    this.topPadding = 20,
    this.bottomPadding = 32,
    super.key,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: PratiCaseColors.softSurface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useWebScene =
              constraints.maxWidth >= 980 && constraints.maxHeight >= 620;
          return Stack(
            children: [
              Positioned.fill(
                child: useWebScene
                    ? const _AuthWebBackdrop()
                    : AuthBackground(showFooterText: showFooterText),
              ),
              SafeArea(
                child: useWebScene
                    ? _AuthWebLayout(
                        bottom: bottom,
                        keyboardOpen: keyboardOpen,
                        onBack: onBack,
                        showFooterText: showFooterText,
                        topPadding: topPadding,
                        bottomPadding: bottomPadding,
                        child: child,
                      )
                    : _AuthMobileLayout(
                        bottom: bottom,
                        keyboardOpen: keyboardOpen,
                        onBack: onBack,
                        showFooterText: showFooterText,
                        topPadding: topPadding,
                        bottomPadding: bottomPadding,
                        child: child,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuthMobileLayout extends StatelessWidget {
  const _AuthMobileLayout({
    required this.child,
    required this.keyboardOpen,
    required this.showFooterText,
    required this.topPadding,
    required this.bottomPadding,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool keyboardOpen;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 900
            ? 520.0
            : constraints.maxWidth >= 720
            ? 460.0
            : double.infinity;
        final horizontalPadding = constraints.maxWidth < 380 ? 16.0 : 20.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                SizedBox(
                  height: onBack == null ? 8 : 58,
                  child: onBack == null
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: _AuthBackButton(onBack: onBack),
                          ),
                        ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        child,
                        if (showFooterText && !keyboardOpen) ...[
                          const SizedBox(height: 28),
                          const _AuthTrustFooter(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: bottom,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuthWebLayout extends StatelessWidget {
  const _AuthWebLayout({
    required this.child,
    required this.keyboardOpen,
    required this.showFooterText,
    required this.topPadding,
    required this.bottomPadding,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool keyboardOpen;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PratiCaseColors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: PratiCaseColors.white.withValues(alpha: 0.62),
              ),
              boxShadow: [
                BoxShadow(
                  color: PratiCaseColors.navy.withValues(alpha: 0.20),
                  blurRadius: 44,
                  spreadRadius: -16,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: _AuthWebStoryPanel(showFooterText: showFooterText),
                  ),
                  Expanded(
                    flex: 9,
                    child: _AuthWebFormPanel(
                      bottom: bottom,
                      bottomPadding: bottomPadding,
                      keyboardOpen: keyboardOpen,
                      onBack: onBack,
                      showFooterText: showFooterText,
                      topPadding: topPadding,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PratiCaseShadows.card,
      ),
      child: IconButton(
        onPressed: onBack,
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: PratiCaseColors.navy,
          size: 25,
        ),
      ),
    );
  }
}

class _AuthWebBackdrop extends StatelessWidget {
  const _AuthWebBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PratiCaseColors.navy.withValues(alpha: 0.98),
            PratiCaseColors.gradientStart,
            PratiCaseColors.teal.withValues(alpha: 0.82),
            PratiCaseColors.softSurface,
          ],
          stops: const [0.0, 0.44, 0.72, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -90,
            child: _AuthGlowOrb(
              size: 360,
              color: PratiCaseColors.tealBright.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            right: -90,
            bottom: -120,
            child: _AuthGlowOrb(
              size: 420,
              color: PratiCaseColors.gold.withValues(alpha: 0.18),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _AuthWebGridPainter())),
        ],
      ),
    );
  }
}

class _AuthGlowOrb extends StatelessWidget {
  const _AuthGlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _AuthWebStoryPanel extends StatelessWidget {
  const _AuthWebStoryPanel({required this.showFooterText});

  final bool showFooterText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF081822),
            PratiCaseColors.navy,
            PratiCaseColors.gradientStart,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _AuthWebGridPainter())),
          Positioned(
            right: -36,
            bottom: -26,
            child: Opacity(
              opacity: 0.92,
              child: Image.asset(
                'assets/auth/onboarding_clinical_tablet.png',
                width: 330,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 40, 42, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/auth/praticase_icon.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Prati'),
                          TextSpan(
                            text: 'Case',
                            style: TextStyle(color: PratiCaseColors.tealBright),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: PratiCaseColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 46),
                const Text(
                  'Klinik Akıl Yürütmeni\nGüvenle Geliştir',
                  style: TextStyle(
                    color: PratiCaseColors.white,
                    fontSize: 44,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gerçekçi OSCE vakaları, anamnezden yönetim planına kadar süreli ve rubrik tabanlı pratik akışı.',
                  style: TextStyle(
                    color: PratiCaseColors.white.withValues(alpha: 0.78),
                    fontSize: 16,
                    height: 1.48,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 30),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AuthStoryFeature(
                      icon: Icons.timer_rounded,
                      label: 'Süreli istasyon',
                    ),
                    _AuthStoryFeature(
                      icon: Icons.forum_rounded,
                      label: 'Sanal hasta',
                    ),
                    _AuthStoryFeature(
                      icon: Icons.fact_check_rounded,
                      label: 'Rubrik karne',
                    ),
                  ],
                ),
                const Spacer(),
                const _AuthWebPreviewCard(),
                if (showFooterText) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Güvenli Medasi hesabınla devam et',
                    style: TextStyle(
                      color: PratiCaseColors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthStoryFeature extends StatelessWidget {
  const _AuthStoryFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          Icon(icon, color: PratiCaseColors.goldBright, size: 16),
          const SizedBox(width: 7),
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

class _AuthWebPreviewCard extends StatelessWidget {
  const _AuthWebPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.18),
        ),
      ),
      child: const Row(
        children: [
          _AuthStoryMetric(value: '100', label: 'puanlık karne'),
          SizedBox(width: 12),
          _AuthStoryMetric(value: '7 dk', label: 'istasyon ritmi'),
          SizedBox(width: 12),
          _AuthStoryMetric(value: 'OSCE', label: 'simülasyon'),
        ],
      ),
    );
  }
}

class _AuthStoryMetric extends StatelessWidget {
  const _AuthStoryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PratiCaseColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.66),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthWebFormPanel extends StatelessWidget {
  const _AuthWebFormPanel({
    required this.child,
    required this.keyboardOpen,
    required this.showFooterText,
    required this.topPadding,
    required this.bottomPadding,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool keyboardOpen;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PratiCaseColors.softSurface.withValues(alpha: 0.96),
      ),
      child: Column(
        children: [
          SizedBox(
            height: onBack == null ? 22 : 70,
            child: onBack == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: _AuthBackButton(onBack: onBack),
                    ),
                  ),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(40, topPadding, 40, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  if (showFooterText && !keyboardOpen) ...[
                    const SizedBox(height: 24),
                    const _AuthTrustFooter(),
                  ],
                ],
              ),
            ),
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

class _AuthWebGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = PratiCaseColors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const gap = 36.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }
    final dotPaint = Paint()
      ..color = PratiCaseColors.tealBright.withValues(alpha: 0.08);
    for (var y = 28.0; y < size.height; y += gap * 1.5) {
      for (var x = 22.0; x < size.width; x += gap * 2) {
        canvas.drawCircle(Offset(x, y), 1.4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuthWebGridPainter oldDelegate) => false;
}

class _AuthTrustFooter extends StatelessWidget {
  const _AuthTrustFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PratiCaseColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: PratiCaseColors.teal,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Güvenli Medasi hesabınla devam et',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
