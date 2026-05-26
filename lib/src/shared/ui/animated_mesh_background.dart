import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/praticase_accent.dart';
import '../../app/theme/praticase_colors.dart';

/// Yavaş hareket eden organik gradient mesh.
///
/// 3 büyük radyal blob, sin/cos ile periyodik olarak drift eder.
/// Performans için:
/// - Tek bir [AnimationController] kullanır.
/// - `RepaintBoundary` ile sarılır; üst ağaç tekrar boyanmaz.
/// - `CustomPainter.shouldRepaint` her frame `true` döner ama yalnızca
///   bu izole katman repaint edilir.
class AnimatedMeshBackground extends StatefulWidget {
  const AnimatedMeshBackground({
    this.colors,
    this.opacity = 1.0,
    this.speed = 1.0,
    super.key,
  });

  /// 2-4 arası blob rengi. Verilmezse marka teması accent + navy + gold.
  final List<Color>? colors;
  final double opacity;
  final double speed;

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (16000 / widget.speed).round()),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = PratiCaseAccent.instance;
    final palette = widget.colors ??
        [
          accent.primary,
          accent.bright,
          PratiCaseColors.gold,
          PratiCaseColors.navy,
        ];
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _MeshPainter(
              time: _controller.value,
              colors: palette,
              opacity: widget.opacity,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.time,
    required this.colors,
    required this.opacity,
  });

  final double time;
  final List<Color> colors;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 1. Base wash (üst-sol → alt-sağ).
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.first.withValues(alpha: 0.06 * opacity),
          colors.last.withValues(alpha: 0.04 * opacity),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // 2. 3 drift eden radyal blob.
    final w = size.width;
    final h = size.height;
    final radius = math.max(w, h) * 0.62;

    final blobs = <_Blob>[
      _Blob(
        center: Offset(
          w * (0.20 + 0.10 * math.sin(time * 2 * math.pi)),
          h * (0.20 + 0.08 * math.cos(time * 2 * math.pi)),
        ),
        color: colors[0],
        radius: radius * 0.85,
        intensity: 0.30,
      ),
      _Blob(
        center: Offset(
          w * (0.85 + 0.10 * math.cos(time * 2 * math.pi + 1.4)),
          h * (0.30 + 0.12 * math.sin(time * 2 * math.pi + 0.7)),
        ),
        color: colors.length > 1 ? colors[1] : colors[0],
        radius: radius * 0.75,
        intensity: 0.22,
      ),
      _Blob(
        center: Offset(
          w * (0.50 + 0.18 * math.sin(time * 2 * math.pi + 2.3)),
          h * (0.85 + 0.10 * math.cos(time * 2 * math.pi + 1.8)),
        ),
        color: colors.length > 2 ? colors[2] : colors.last,
        radius: radius * 0.95,
        intensity: 0.18,
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withValues(alpha: blob.intensity * opacity),
            blob.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(
          Rect.fromCircle(center: blob.center, radius: blob.radius),
        );
      canvas.drawCircle(blob.center, blob.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) {
    return old.time != time ||
        old.colors != colors ||
        old.opacity != opacity;
  }
}

class _Blob {
  const _Blob({
    required this.center,
    required this.color,
    required this.radius,
    required this.intensity,
  });

  final Offset center;
  final Color color;
  final double radius;
  final double intensity;
}
