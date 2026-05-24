abstract final class PratiCaseUserMessage {
  static const generalFailure =
      'İşlem şu anda tamamlanamadı. Birazdan tekrar deneyebilirsin.';
  static const connectionFailure =
      'Bağlantı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.';
  static const storeFailure =
      'Paketler şu anda yüklenemedi. Tekrar deneyebilir veya sorun devam ederse destek ekibine ulaşabilirsin.';
  static const purchaseFailure =
      'Satın alma şu anda tamamlanamadı. Lütfen tekrar dene.';
  static const reportFailure =
      'Karne şu anda hazırlanamadı. Yanıtların kaydedildi, tekrar deneyebilirsin.';
  static const oralExamFailure =
      'Sözlü sınav işlemi şu anda tamamlanamadı. Birazdan tekrar deneyebilirsin.';
  static const theoreticalExamFailure =
      'Teorik sınav şu anda yüklenemedi. Birazdan tekrar deneyebilirsin.';

  static final _technicalPattern = RegExp(
    r'(permission\s+denied|row.level.security|\brls\b|postgrest|postgres|'
    r'supabase|edge\s+function|vertex\s+ai|provider\s+error|stack\s+trace|'
    r'exception|duplicate\s+key|violates|sqlstate|schema\s+cache|'
    r'\brelation\b|\bcolumn\b|unauthori[sz]ed|forbidden|origin\s+not\s+allowed|'
    r'method\s+not\s+allowed|configuration|\bundefined\b|\bnull\b|'
    r'\bhttp\s*[45]\d\d\b|'
    r'error\s*code\s*:?\s*\d+|status\s*code\s*:?\s*\d+|'
    r'store_products|wallet_entitlements|session_[a-z_]+|'
    r'mentor_message|case_brief|snake_case|'
    r'\b[a-z]+(?:_[a-z0-9]+)+\b)',
    caseSensitive: false,
  );

  static bool exposesTechnicalDetail(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (_technicalPattern.hasMatch(text)) return true;
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      return true;
    }
    return RegExp(r'^\d+$').hasMatch(text);
  }

  static String safe(String? value, {String fallback = generalFailure}) {
    final text = value?.trim() ?? '';
    return text.isEmpty || exposesTechnicalDetail(text) ? fallback : text;
  }

  static String from(Object? error, {String fallback = generalFailure}) {
    return safe(error?.toString(), fallback: fallback);
  }

  static String store(Object? error) => from(error, fallback: storeFailure);

  static String purchase(Object? error) =>
      from(error, fallback: purchaseFailure);

  static String report(Object? error) => from(error, fallback: reportFailure);

  static String oralExam(Object? error) =>
      from(error, fallback: oralExamFailure);

  static String theoreticalExam(Object? error) =>
      from(error, fallback: theoreticalExamFailure);

  static String mentorMessage(String? message, {String? fallback}) {
    return safe(
      message,
      fallback:
          fallback ??
          'Yanıtını klinik gerekçenle birlikte bir cümle daha açar mısın?',
    );
  }
}
