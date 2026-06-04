import 'package:flutter/material.dart';

import 'praticase_colors.dart';
import 'praticase_performance.dart';

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
  /// Premium iki katmanlı kart gölgesi: yumuşak ambient + ince key.
  /// Tek katmanlı gölgeye göre belirgin biçimde daha derin görünür.
  static List<BoxShadow> get card => [
    if (PratiCasePerformance.lightweightWebPaint)
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.030),
        blurRadius: 8,
        spreadRadius: -3,
        offset: const Offset(0, 3),
      )
    else ...[
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.055),
        blurRadius: 22,
        spreadRadius: -8,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.025),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ],
  ];

  /// Hafif kart yükselmesi (seçili tile, hover hissi).
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: PratiCaseColors.navy.withValues(
        alpha: PratiCasePerformance.lightweightWebPaint ? 0.018 : 0.025,
      ),
      blurRadius: PratiCasePerformance.lightweightWebPaint ? 5 : 10,
      spreadRadius: PratiCasePerformance.lightweightWebPaint ? -1 : -2,
      offset: Offset(0, PratiCasePerformance.lightweightWebPaint ? 2 : 4),
    ),
  ];

  /// Hero ve floating action elementleri için derin iki katmanlı gölge.
  static List<BoxShadow> get floating => [
    if (PratiCasePerformance.lightweightWebPaint)
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.055),
        blurRadius: 12,
        spreadRadius: -4,
        offset: const Offset(0, 6),
      )
    else ...[
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.12),
        blurRadius: 30,
        spreadRadius: -8,
        offset: const Offset(0, 18),
      ),
      BoxShadow(
        color: PratiCaseColors.navy.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ];

  /// Birincil CTA altında ince teal glow — pahalı değil ama
  /// "tıklanabilir" hissi pekişir.
  static List<BoxShadow> get primaryCta => [
    BoxShadow(
      color: PratiCaseColors.teal.withValues(
        alpha: PratiCasePerformance.lightweightWebPaint ? 0.12 : 0.20,
      ),
      blurRadius: PratiCasePerformance.lightweightWebPaint ? 8 : 18,
      spreadRadius: PratiCasePerformance.lightweightWebPaint ? -2 : -4,
      offset: Offset(0, PratiCasePerformance.lightweightWebPaint ? 4 : 8),
    ),
  ];
}

abstract final class PratiCaseGradients {
  /// Marka hero gradienti — koyu navy → derin teal.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PratiCaseColors.gradientStart, PratiCaseColors.gradientEnd],
  );

  /// Birincil aksiyon butonu gradienti.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [PratiCaseColors.actionStart, PratiCaseColors.actionEnd],
  );

  /// Yumuşak yüzey dokusu — beyaz arka plan üzerinde sezilmeyecek
  /// kadar ince bir varyasyon (paket kartları, info panelleri).
  static const LinearGradient mutedSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PratiCaseColors.white, PratiCaseColors.mutedSurfaceEnd],
  );

  /// Başarı / pozitif durum vurgusu için ince yeşil-teal wash.
  static const LinearGradient successWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PratiCaseColors.successWashStart, PratiCaseColors.successWashEnd],
  );
}
