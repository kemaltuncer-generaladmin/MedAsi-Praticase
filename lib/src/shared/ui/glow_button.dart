import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/praticase_accent.dart';
import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_motion.dart';
import '../../app/theme/praticase_performance.dart';
import '../../app/theme/praticase_tokens.dart';

/// Premium birincil CTA — spring scale + altında nabız atan glow + label
/// fade animasyonu. AuthPrimaryButton'un üst seviyesi.
///
/// Performans:
/// - Tek bir [AnimationController] kullanır; press / release yönünü scale +
///   glow tween'lerine doğrudan map'ler.
/// - Nabız (pulse) animasyonu yalnızca `pulse: true` iken çalışır ve ayrı
///   bir [AnimationController]'da koşar — pasif buton CPU tüketmez.
/// - `RepaintBoundary` ile dış dünyadan izole edilir; arka plan/scroll
///   sırasında re-paint olmaz.
class GlowButton extends StatefulWidget {
  const GlowButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.expand = true,
    this.height = 56,
    this.pulse = false,
    this.accentOverride,
    this.semanticIdentifier,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final String? loadingLabel;
  final bool expand;
  final double height;

  /// Pasif iken altta soluk bir nabız atması istenir mi (önemli aksiyon).
  final bool pulse;
  final Color? accentOverride;
  final String? semanticIdentifier;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 220),
  );

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse && !PratiCasePerformance.staticWebEffects) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlowButton old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse) {
      if (widget.pulse && !PratiCasePerformance.staticWebEffects) {
        _pulse.repeat();
      } else {
        _pulse.stop();
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleDown(_) {
    if (!_enabled) return;
    _press.forward();
  }

  void _handleCancel() {
    if (!_enabled) return;
    _press.reverse();
  }

  void _handleTap() {
    if (!_enabled) return;
    _press.reverse();
    HapticFeedback.selectionClick();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentOverride ?? PratiCaseAccent.instance.primary;
    final bright = widget.accentOverride == null
        ? PratiCaseAccent.instance.bright
        : accent;
    final lightweightPaint = PratiCasePerformance.lightweightWebPaint;

    final core = RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleDown,
        onTapCancel: _handleCancel,
        onTapUp: (_) => _handleCancel(),
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _pulse]),
          builder: (context, _) {
            final press = Curves.easeOutCubic.transform(_press.value);
            final pulse = widget.pulse && !PratiCasePerformance.staticWebEffects
                ? (1 - (_pulse.value - 0.5).abs() * 2) // 0→1→0 triangle
                : 0.0;

            // Scale: 1.0 idle → 0.965 fully pressed.
            final scale = 1.0 - press * 0.035;
            // Glow alpha: pulse adds gentle baseline; press boosts.
            final glowAlpha = (0.18 + press * 0.20 + pulse * 0.10).clamp(
              0.0,
              0.55,
            );

            return Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Container(
                height: widget.height,
                width: widget.expand ? double.infinity : null,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  gradient: _enabled
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accent, bright],
                        )
                      : null,
                  color: _enabled ? null : PratiCaseColors.border,
                  boxShadow: _enabled
                      ? [
                          BoxShadow(
                            color: accent.withValues(
                              alpha: lightweightPaint ? 0.13 : glowAlpha,
                            ),
                            blurRadius: lightweightPaint ? 10 : 24 + press * 6,
                            spreadRadius: lightweightPaint ? -2 : -6,
                            offset: Offset(
                              0,
                              lightweightPaint ? 5 : 14 - press * 6,
                            ),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: PratiCaseDurations.fast,
                  switchInCurve: PratiCaseCurves.standard,
                  child: widget.loading
                      ? Row(
                          key: ValueKey('loading'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: PratiCaseColors.white,
                              ),
                            ),
                            if (widget.loadingLabel?.trim().isNotEmpty ??
                                false) ...[
                              const SizedBox(width: 10),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.loadingLabel!.trim(),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: PratiCaseColors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          key: ValueKey('label-${widget.label}'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: _enabled
                                    ? PratiCaseColors.white
                                    : PratiCaseColors.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: _enabled
                                        ? PratiCaseColors.white
                                        : PratiCaseColors.muted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.semanticIdentifier == null) return core;
    return Semantics(
      identifier: widget.semanticIdentifier,
      button: true,
      label: widget.label,
      container: true,
      enabled: _enabled,
      child: core,
    );
  }
}
