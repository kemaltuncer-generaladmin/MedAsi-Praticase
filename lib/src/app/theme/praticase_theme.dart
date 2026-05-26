import 'package:flutter/material.dart';

import 'praticase_colors.dart';
import 'praticase_motion.dart';
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
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: PratiCasePageTransitions(),
          TargetPlatform.android: PratiCasePageTransitions(),
          TargetPlatform.macOS: PratiCasePageTransitions(),
          TargetPlatform.linux: PratiCasePageTransitions(),
          TargetPlatform.windows: PratiCasePageTransitions(),
          TargetPlatform.fuchsia: PratiCasePageTransitions(),
        },
      ),
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
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
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
          backgroundColor: PratiCaseColors.teal,
          foregroundColor: PratiCaseColors.white,
          disabledBackgroundColor:
              PratiCaseColors.teal.withValues(alpha: 0.35),
          disabledForegroundColor:
              PratiCaseColors.white.withValues(alpha: 0.85),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PratiCaseColors.teal,
          side: const BorderSide(color: PratiCaseColors.border, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.1,
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
        labelStyle: const TextStyle(
          color: PratiCaseColors.muted,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: PratiCaseColors.teal,
          fontWeight: FontWeight.w800,
        ),
        prefixIconColor: PratiCaseColors.slateBlue,
        suffixIconColor: PratiCaseColors.slateBlue,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide: const BorderSide(color: PratiCaseColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide:
              const BorderSide(color: PratiCaseColors.errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide:
              const BorderSide(color: PratiCaseColors.errorRed, width: 1.6),
        ),
        errorStyle: const TextStyle(
          color: PratiCaseColors.errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PratiCaseColors.white,
        selectedColor: PratiCaseColors.teal.withValues(alpha: 0.12),
        disabledColor: PratiCaseColors.surfaceContainerHighest,
        side: BorderSide(color: PratiCaseColors.border.withValues(alpha: 0.9)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
        ),
        labelStyle: const TextStyle(
          color: PratiCaseColors.slateBlue,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: const TextStyle(
          color: PratiCaseColors.teal,
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
