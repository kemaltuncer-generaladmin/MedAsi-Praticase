import 'package:flutter/material.dart';

import 'praticase_colors.dart';
import 'praticase_tokens.dart';

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
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: PratiCaseColors.white,
        foregroundColor: PratiCaseColors.navy,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: PratiCaseColors.navy,
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: PratiCaseColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
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
            fontSize: 11,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PratiCaseColors.gradientEnd,
          foregroundColor: PratiCaseColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PratiCaseColors.teal,
          side: const BorderSide(color: PratiCaseColors.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PratiCaseColors.teal,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: PratiCaseColors.navy,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: PratiCaseColors.white,
        hintStyle: const TextStyle(
          color: PratiCaseColors.muted,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
          borderSide: const BorderSide(color: PratiCaseColors.teal, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PratiCaseColors.white,
        selectedColor: PratiCaseColors.teal,
        disabledColor: PratiCaseColors.surfaceContainerHighest,
        side: const BorderSide(color: PratiCaseColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PratiCaseRadius.sm)),
        labelStyle: const TextStyle(
          color: PratiCaseColors.slateBlue,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: const TextStyle(
          color: PratiCaseColors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PratiCaseColors.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        ),
        contentTextStyle: const TextStyle(
          color: PratiCaseColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PratiCaseColors.white,
        surfaceTintColor: PratiCaseColors.white,
        showDragHandle: true,
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
