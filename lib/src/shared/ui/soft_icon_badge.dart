import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';

class SoftIconBadge extends StatelessWidget {
  const SoftIconBadge({
    required this.icon,
    this.color = PratiCaseColors.teal,
    this.size = 62,
    this.iconSize = 29,
    this.radius = 18,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
