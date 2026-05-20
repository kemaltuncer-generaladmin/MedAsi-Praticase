abstract final class AuthValidators {
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'E-posta gerekli.';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
      return 'Geçerli bir e-posta gir.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Şifre en az 8 karakter olmalı.';
    return null;
  }

  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return 'Ad soyad gerekli.';
    return null;
  }
}
