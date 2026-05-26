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
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 30;
  static const double pill = 999;
}

abstract final class PratiCaseShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: PratiCaseColors.navy.withValues(alpha: 0.06),
      blurRadius: 22,
      spreadRadius: -8,
      offset: const Offset(0, 14),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: PratiCaseColors.navy.withValues(alpha: 0.14),
      blurRadius: 28,
      spreadRadius: -10,
      offset: const Offset(0, 18),
    ),
  ];
}

abstract final class PratiCaseGradients {
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF073844), Color(0xFF006A72)],
  );

  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF087D74), Color(0xFF00A090)],
  );
}
