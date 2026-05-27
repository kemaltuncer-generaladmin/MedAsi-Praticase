import 'package:flutter/material.dart';

import '../../../../shared/ui/glow_button.dart';

/// Tüm auth ekranlarının birincil aksiyon butonu.
///
/// İçeride [GlowButton] kullanır → otomatik olarak: spring scale, ışıltılı
/// gradient zemin, basıldığında glow yoğunlaşması, yüklemede spinner,
/// `showArrow=true` ise sağda yön oku, accent renge bağlı.
///
/// `pulse=true` verilirse buton sürekli yumuşak nabız atar (örn. CTA'ya
/// dikkat çekilmek istenen onboarding son adımı).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = false,
    this.pulse = false,
    this.identifier,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final bool pulse;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    return GlowButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      pulse: pulse,
      height: 58,
      icon: showArrow ? Icons.arrow_forward_rounded : null,
      semanticIdentifier: identifier,
    );
  }
}
