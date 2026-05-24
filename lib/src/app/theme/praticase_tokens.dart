import 'package:flutter/material.dart';

import 'praticase_colors.dart';

abstract final class PratiCaseSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double pageHorizontal = 20;
  static const double pageTop = 20;
  static const double bottomNavReserve = 132;
}

abstract final class PratiCaseRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double pill = 999;
}

abstract final class PratiCaseShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: PratiCaseColors.navy.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: PratiCaseColors.navy.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}

abstract final class PratiCaseGradients {
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF073844), Color(0xFF006A72)],
  );
}
