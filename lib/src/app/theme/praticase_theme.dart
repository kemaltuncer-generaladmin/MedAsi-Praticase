import 'package:flutter/material.dart';

import 'praticase_colors.dart';

abstract final class PratiCaseTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PratiCaseColors.teal,
      primary: PratiCaseColors.teal,
      secondary: PratiCaseColors.gold,
      surface: PratiCaseColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Plus Jakarta Sans',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PratiCaseColors.softSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: PratiCaseColors.white,
        foregroundColor: PratiCaseColors.navy,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: PratiCaseColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PratiCaseColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PratiCaseColors.white,
        indicatorColor: PratiCaseColors.teal.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? PratiCaseColors.teal
                : PratiCaseColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PratiCaseColors.gradientEnd,
          foregroundColor: PratiCaseColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: PratiCaseColors.navy,
          fontSize: 44,
          height: 42 / 44,
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: TextStyle(
          color: PratiCaseColors.navy,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          color: PratiCaseColors.navy,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: TextStyle(
          color: PratiCaseColors.navy,
          fontSize: 17,
          height: 24 / 17,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: PratiCaseColors.navy,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: PratiCaseColors.ink,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: PratiCaseColors.ink),
        bodySmall: TextStyle(color: PratiCaseColors.muted),
      ),
    );
  }
}
