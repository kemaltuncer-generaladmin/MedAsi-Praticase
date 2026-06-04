import 'package:flutter/material.dart';

import 'praticase_colors.dart';

/// PratiCase accent (vurgu) rengi seçenekleri.
///
/// Kullanıcı profil → ayarlar üzerinden kendi vurgu rengini seçebilir.
/// Varsayılan teal (kurumsal marka tonu).
enum PratiCaseAccentOption {
  teal('Teal', PratiCaseColors.teal, PratiCaseColors.tealBright),
  navy('Navy', PratiCaseColors.navy, PratiCaseColors.slateBlue),
  slate('Slate', PratiCaseColors.slateBlue, PratiCaseColors.surfaceContainer),
  gold('Gold', PratiCaseColors.gold, PratiCaseColors.goldBright);

  const PratiCaseAccentOption(this.label, this.primary, this.bright);

  /// İnsan-okunabilir etiket (settings'te gösterilir).
  final String label;

  /// Birincil vurgu tonu (CTA bg, ring, ikon rengi).
  final Color primary;

  /// Açık varyant (chip bg, glow, halka).
  final Color bright;
}

/// Aktif accent rengini global olarak yayan singleton controller.
///
/// Top-level `MaterialApp`'i `ListenableBuilder(listenable: PratiCaseAccent
/// .instance, ...)` ile sararak tema rebuild'ini tetikleriz. Settings
/// ekranı `PratiCaseAccent.instance.setOption(...)` ile değiştirir.
///
/// Şu an in-memory; ileride `user_app_settings.accent` alanı ile
/// senkronlanabilir.
class PratiCaseAccent extends ChangeNotifier {
  PratiCaseAccent._();

  static final PratiCaseAccent instance = PratiCaseAccent._();

  PratiCaseAccentOption _option = PratiCaseAccentOption.teal;

  PratiCaseAccentOption get option => _option;
  Color get primary => _option.primary;
  Color get bright => _option.bright;

  void setOption(PratiCaseAccentOption option) {
    if (option == _option) return;
    _option = option;
    notifyListeners();
  }
}
