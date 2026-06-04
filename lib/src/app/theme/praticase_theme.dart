import 'package:flutter/material.dart';

import 'praticase_accent.dart';
import 'praticase_colors.dart';
import 'praticase_motion.dart';
import 'praticase_performance.dart';
import 'praticase_tokens.dart';
import 'praticase_typography.dart';

abstract final class PratiCaseTheme {
  /// Aktif accent rengine göre tema üretir. `accent` verilmezse
  /// `PratiCaseAccent.instance.primary` (default teal) kullanılır.
  static ThemeData light({Color? accent}) {
    final primary = accent ?? PratiCaseAccent.instance.primary;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: PratiCaseColors.gold,
      surface: PratiCaseColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Plus Jakarta Sans',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PratiCaseColors.softSurface,
      visualDensity: VisualDensity.standard,
      splashFactory: PratiCasePerformance.web
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final platform in TargetPlatform.values)
            platform: PratiCasePerformance.web
                ? const PratiCaseWebPageTransitions()
                : const PratiCasePageTransitions(),
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
          backgroundColor: primary,
          foregroundColor: PratiCaseColors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: PratiCaseColors.white.withValues(
            alpha: 0.85,
          ),
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
          backgroundColor: PratiCaseColors.white,
          foregroundColor: primary,
          disabledForegroundColor: PratiCaseColors.muted.withValues(
            alpha: 0.65,
          ),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: primary.withValues(alpha: 0.22)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
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
        floatingLabelStyle: TextStyle(
          color: primary,
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
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide: const BorderSide(
            color: PratiCaseColors.errorRed,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
          borderSide: const BorderSide(
            color: PratiCaseColors.errorRed,
            width: 1.6,
          ),
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
        displayLarge: PratiCaseTextStyles.pageTitle,
        headlineLarge: PratiCaseTextStyles.pageTitle,
        headlineMedium: PratiCaseTextStyles.sectionTitle,
        headlineSmall: PratiCaseTextStyles.cardTitle,
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
