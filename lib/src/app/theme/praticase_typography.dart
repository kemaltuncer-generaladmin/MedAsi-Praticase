import 'package:flutter/material.dart';

import 'praticase_colors.dart';

/// Semantic text roles used by PratiCase screens.
///
/// Keep screen-level copy on these roles first; local `fontSize` overrides
/// should be reserved for genuinely unique artwork or data visualizations.
abstract final class PratiCaseTextStyles {
  static const TextStyle brand = TextStyle(
    color: PratiCaseColors.navy,
    fontSize: 27,
    height: 1.05,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle pageTitle = TextStyle(
    color: PratiCaseColors.navy,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle pageSubtitle = TextStyle(
    color: PratiCaseColors.muted,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: PratiCaseColors.navy,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    color: PratiCaseColors.muted,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle cardTitle = TextStyle(
    color: PratiCaseColors.navy,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle cardBody = TextStyle(
    color: PratiCaseColors.slateBlue,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: PratiCaseColors.ink,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyMuted = TextStyle(
    color: PratiCaseColors.muted,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    color: PratiCaseColors.muted,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle pill = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle metricValue = TextStyle(
    color: PratiCaseColors.navy,
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle cta = TextStyle(
    fontSize: 15,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.1,
  );
}
