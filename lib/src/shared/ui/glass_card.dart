import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_tokens.dart';

/// Premium glassmorphism kart.
///
/// [BackdropFilter] ile arka planı bulanıklaştırır, üzerine ince translucent
/// yüzey + ışıklı border ekler. iOS / macOS varsayılan "frosted glass"
/// hissine yakın görünür ama PratiCase marka renkleriyle uyumludur.
///
/// Performans: `RepaintBoundary` ile sarılır — alt-ağaç tek bir layer'da
/// rasterize edilir, scroll sırasında re-rasterize edilmez.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = PratiCaseRadius.xxl,
    this.tint,
    this.borderColor,
    this.blurSigma = 18,
    this.surfaceOpacity = 0.78,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Tonlama rengi (örn. teal veya navy alpha). Verilmezse beyaz alpha.
  final Color? tint;
  final Color? borderColor;
  final double blurSigma;
  final double surfaceOpacity;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? PratiCaseColors.white;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: surfaceOpacity),
                  base.withValues(alpha: surfaceOpacity * 0.78),
                ],
              ),
              border: Border.all(
                color: borderColor ??
                    PratiCaseColors.white.withValues(alpha: 0.55),
                width: 1.1,
              ),
              boxShadow: elevated ? PratiCaseShadows.card : null,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Koyu / hero arka plan üzerinde kullanılan glass card varyantı.
/// İçeriği beyaz alpha tonlarıyla çerçeveler.
class GlassCardDark extends StatelessWidget {
  const GlassCardDark({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = PratiCaseRadius.xxl,
    this.blurSigma = 22,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PratiCaseColors.white.withValues(alpha: 0.16),
                  PratiCaseColors.white.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: PratiCaseColors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
