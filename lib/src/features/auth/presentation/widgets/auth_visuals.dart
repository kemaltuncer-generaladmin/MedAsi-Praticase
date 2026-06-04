import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({required this.showFooterText, super.key});

  final bool showFooterText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _AuthBackgroundPainter(compactWave: !showFooterText),
          ),
        ),
      ],
    );
  }
}

class AuthLogoBlock extends StatelessWidget {
  const AuthLogoBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/auth/praticase_icon.png', width: 104, height: 104),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 0.95,
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
        const SizedBox(height: 6),
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _GoldLine(),
              SizedBox(width: 8),
              Text(
                'OSCE PRATİK PLATFORMU',
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(width: 8),
              _GoldLine(),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({this.width = 260, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/auth/praticase_wordmark.png',
        width: width,
        fit: BoxFit.contain,
      ),
    );
  }
}

class AuthHeroIllustration extends StatelessWidget {
  const AuthHeroIllustration({required this.type, this.size = 190, super.key});

  final AuthHeroType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _ConfettiPainter())),
          Center(
            child: _HeroCircle(
              size: size * 0.76,
              child: switch (type) {
                AuthHeroType.profile => const _ProfileCardIcon(),
                AuthHeroType.envelope => const _EnvelopeIcon(),
                AuthHeroType.lock => const _LockIcon(),
                AuthHeroType.success => const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 96,
                  weight: 900,
                ),
              },
            ),
          ),
          if (type == AuthHeroType.profile)
            Positioned(
              right: size * 0.12,
              bottom: size * 0.22,
              child: const _FloatingBadge(icon: Icons.add_rounded),
            ),
          if (type == AuthHeroType.envelope)
            Positioned(
              right: size * 0.12,
              bottom: size * 0.18,
              child: const _FloatingBadge(icon: Icons.check_rounded),
            ),
          if (type == AuthHeroType.lock)
            Positioned(
              right: size * 0.1,
              bottom: size * 0.18,
              child: const _LightBadge(icon: Icons.check_rounded),
            ),
        ],
      ),
    );
  }
}

enum AuthHeroType { profile, envelope, lock, success }

class _GoldLine extends StatelessWidget {
  const _GoldLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Divider(color: PratiCaseColors.gold, thickness: 2),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PratiCaseColors.teal, PratiCaseColors.navy],
        ),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [PratiCaseColors.tealBright, PratiCaseColors.navy],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 34),
    );
  }
}

class _LightBadge extends StatelessWidget {
  const _LightBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: PratiCaseColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: PratiCaseColors.teal, size: 38),
    );
  }
}

class _ProfileCardIcon extends StatelessWidget {
  const _ProfileCardIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 126,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 18, backgroundColor: PratiCaseColors.teal),
              SizedBox(height: 9),
              Icon(Icons.person_rounded, color: PratiCaseColors.teal, size: 50),
              SizedBox(height: 8),
              _MiniLine(width: 55),
              SizedBox(height: 7),
              _MiniLine(width: 42),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvelopeIcon extends StatelessWidget {
  const _EnvelopeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(painter: _EnvelopePainter()),
    );
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.lock_rounded, color: Colors.white, size: 76);
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: PratiCaseColors.border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  _AuthBackgroundPainter({required this.compactWave});

  final bool compactWave;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = PratiCaseColors.border.withValues(alpha: 0.5);
    for (var i = 0; i < 7; i++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width * 1.04, -18),
          radius: 128 + i * 17,
        ),
        math.pi * 0.72,
        math.pi * 0.44,
        false,
        arcPaint,
      );
    }

    final waveTop = size.height * (compactWave ? 0.92 : 0.84);
    final softWave = Path()
      ..moveTo(0, waveTop - 22)
      ..cubicTo(
        size.width * 0.2,
        waveTop + 28,
        size.width * 0.38,
        waveTop - 34,
        size.width * 0.58,
        waveTop,
      )
      ..cubicTo(
        size.width * 0.75,
        waveTop + 30,
        size.width * 0.84,
        waveTop - 26,
        size.width,
        waveTop - 40,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      softWave,
      Paint()..color = PratiCaseColors.authWave.withValues(alpha: 0.72),
    );

    final darkWave = Path()
      ..moveTo(0, waveTop + 44)
      ..cubicTo(
        size.width * 0.22,
        waveTop + 92,
        size.width * 0.38,
        waveTop + 28,
        size.width * 0.59,
        waveTop + 44,
      )
      ..cubicTo(
        size.width * 0.76,
        waveTop + 58,
        size.width * 0.86,
        waveTop + 10,
        size.width,
        waveTop - 4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      darkWave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PratiCaseColors.teal, PratiCaseColors.navy],
        ).createShader(Offset.zero & size),
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = PratiCaseColors.authWaveLine.withValues(alpha: 0.58);
    for (var i = 0; i < 8; i++) {
      final y = waveTop + 10 + i * 7;
      final p = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * 0.22,
          y - 24,
          size.width * 0.34,
          y + 22,
          size.width * 0.58,
          y - 4,
        )
        ..cubicTo(
          size.width * 0.75,
          y - 24,
          size.width * 0.88,
          y + 10,
          size.width,
          y - 14,
        );
      canvas.drawPath(p, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthBackgroundPainter oldDelegate) =>
      oldDelegate.compactWave != compactWave;
}

class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      (Offset(size.width * 0.16, size.height * 0.36), PratiCaseColors.teal),
      (Offset(size.width * 0.22, size.height * 0.72), PratiCaseColors.gold),
      (Offset(size.width * 0.74, size.height * 0.2), PratiCaseColors.gold),
      (Offset(size.width * 0.84, size.height * 0.56), PratiCaseColors.teal),
      (Offset(size.width * 0.54, size.height * 0.1), PratiCaseColors.teal),
    ];
    for (final item in points) {
      canvas.save();
      canvas.translate(item.$1.dx, item.$1.dy);
      canvas.rotate(math.pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -4, 8, 8),
          const Radius.circular(2),
        ),
        Paint()..color = item.$2,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = PratiCaseColors.authIllustrationStroke;
    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * 0.58)
      ..lineTo(size.width, 0);
    canvas.drawPath(flap, line);
    final lower = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.42, size.height * 0.44)
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.58, size.height * 0.44);
    canvas.drawPath(lower, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
