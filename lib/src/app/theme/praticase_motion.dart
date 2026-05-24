import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PratiCase hareket sistemi.
///
/// Tüm zamanlama ve eğri sabitleri, ekranlar arası geçişler, kart
/// belirme/kaybolma animasyonları ve haptic geri bildirim deseni burada
/// toplanır. Yeni bir animasyon yazmadan önce buradaki token'ları kullan;
/// magic number eklemeyin.
abstract final class PratiCaseDurations {
  /// 90 ms — kullanıcı yalnızca anlamak için yeterli, hız hissi bozulmaz.
  /// Buton press feedback, küçük renk değişimi.
  static const Duration micro = Duration(milliseconds: 90);

  /// 160 ms — chip/segmented seçim, snackbar fade, küçük expand.
  static const Duration fast = Duration(milliseconds: 160);

  /// 240 ms — kart açılması, modal sheet, list item appear.
  static const Duration standard = Duration(milliseconds: 240);

  /// 360 ms — sayfa geçişi, hero transition, büyük layout shift.
  static const Duration emphasized = Duration(milliseconds: 360);

  /// 480 ms — onboarding, splash → home, ödeme onayı gibi nadir, dikkat
  /// çekici geçişler.
  static const Duration showcase = Duration(milliseconds: 480);
}

abstract final class PratiCaseCurves {
  /// Material 3 emphasized eğrisi — sayfa geçişi, modal, büyük komponentler.
  static const Curve emphasized = Cubic(0.20, 0.00, 0.00, 1.00);

  /// Standart hareket — kart, chip, küçük UI parçaları.
  static const Curve standard = Cubic(0.20, 0.00, 0.00, 1.00);

  /// Hızlı çıkış — element kaybolurken.
  static const Curve exit = Cubic(0.40, 0.00, 1.00, 1.00);

  /// Bouncy onay — başarı, satın alma, "tamamlandı".
  static const Curve overshoot = Cubic(0.22, 1.00, 0.36, 1.00);

  /// Yumuşak ease — fade-in/out, opacity değişimi.
  static const Curve smooth = Curves.easeOutCubic;
}

abstract final class PratiCaseHaptics {
  static Future<void> selection() async => HapticFeedback.selectionClick();
  static Future<void> light() async => HapticFeedback.lightImpact();
  static Future<void> medium() async => HapticFeedback.mediumImpact();
  static Future<void> heavy() async => HapticFeedback.heavyImpact();
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }
  static Future<void> warning() async {
    await HapticFeedback.heavyImpact();
  }
}

/// PratiCase'in marka kimliğine uygun sayfa geçişi.
///
/// iOS varsayılan slide-left yerine alttan hafif yükselen + fade kombinasyonu
/// kullanır; klinik & premium hissi korunur.
class PratiCasePageTransitions extends PageTransitionsBuilder {
  const PratiCasePageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: PratiCaseCurves.emphasized,
      reverseCurve: PratiCaseCurves.exit,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(fade);
    final secondaryFade = CurvedAnimation(
      parent: secondaryAnimation,
      curve: PratiCaseCurves.standard,
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.92).animate(secondaryFade),
          child: child,
        ),
      ),
    );
  }
}

/// Görünüme girdiğinde tek seferlik fade + slide animasyonu çalıştıran sarmal.
///
/// Ana sayfada kart koleksiyonlarını veya sonuç karnesini sahneye aldırmak
/// için kullan. `delay` ile staggered etki sağlanır.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = PratiCaseDurations.standard,
    this.offset = const Offset(0, 0.05),
    this.curve = PratiCaseCurves.standard,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  late final Animation<Offset> _offset = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Liste öğelerine sıralı (staggered) giriş animasyonu uygular.
///
/// ```dart
/// FadeSlideInList(
///   children: [for (final item in items) CaseCard(item: item)],
/// )
/// ```
class FadeSlideInList extends StatelessWidget {
  const FadeSlideInList({
    required this.children,
    this.stagger = const Duration(milliseconds: 60),
    this.initialDelay = Duration.zero,
    super.key,
  });

  final List<Widget> children;
  final Duration stagger;
  final Duration initialDelay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++)
          FadeSlideIn(
            delay: initialDelay + stagger * index,
            child: children[index],
          ),
      ],
    );
  }
}

/// Buton/tile dokunulduğunda hafif scale + opacity feedback'i veren sarmal.
///
/// Kart, vaka tile, sonuç metriği için. `onTap` null ise pasif görünür.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.hapticsOnTap = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool hapticsOnTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PratiCaseDurations.micro,
    lowerBound: 0,
    upperBound: 1,
    value: 0,
  );

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press(bool down) {
    if (!_enabled) return;
    if (down) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleTap() {
    widget.onTap?.call();
    if (widget.hapticsOnTap) {
      unawaited(PratiCaseHaptics.selection().catchError((_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? _handleTap : null,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _press(true),
      onTapCancel: () => _press(false),
      onTapUp: (_) => _press(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (1.0 - widget.scale) * _controller.value;
          return Transform.scale(
            alignment: Alignment.center,
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Splash / loading durumlarında kullanılan tutarlı progress indicator.
class PratiCaseSpinner extends StatelessWidget {
  const PratiCaseSpinner({
    this.size = 28,
    this.color,
    this.strokeWidth = 2.4,
    super.key,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
