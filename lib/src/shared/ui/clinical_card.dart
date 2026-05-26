import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_motion.dart';
import '../../app/theme/praticase_tokens.dart';

class ClinicalCard extends StatelessWidget {
  const ClinicalCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = PratiCaseRadius.xl,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? PratiCaseColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? PratiCaseColors.border.withValues(alpha: 0.78),
        width: 1,
      ),
      boxShadow: elevated ? PratiCaseShadows.card : null,
    );

    final inner = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return inner;

    return PressableScale(onTap: onTap, child: inner);
  }
}
