import 'package:flutter/foundation.dart';

/// Platform-specific visual performance switches.
///
/// PratiCase keeps the native iOS/Android visual language untouched. These
/// switches only reduce expensive paint work in Flutter web, where blur,
/// large shadows and continuous custom paints are noticeably more costly.
abstract final class PratiCasePerformance {
  static const bool web = kIsWeb;
  static const bool lightweightWebPaint = kIsWeb;
  static const bool staticWebEffects = kIsWeb;
}
