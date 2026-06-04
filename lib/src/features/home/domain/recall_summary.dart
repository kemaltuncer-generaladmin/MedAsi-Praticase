class RecallSummary {
  const RecallSummary({
    required this.todayTotal,
    required this.weaknesses,
    required this.guidance,
    required this.action,
    this.errorMessage,
    this.isAuthenticated = true,
  });

  const RecallSummary.unauthenticated()
    : todayTotal = 0,
      weaknesses = const [],
      guidance = const RecallGuidance.empty(),
      action = '',
      errorMessage = 'Recall için oturum bulunamadı.',
      isAuthenticated = false;

  const RecallSummary.error(String message)
    : todayTotal = 0,
      weaknesses = const [],
      guidance = const RecallGuidance.empty(),
      action = '',
      errorMessage = message,
      isAuthenticated = true;

  final int todayTotal;
  final List<RecallWeakness> weaknesses;
  final RecallGuidance guidance;
  final String action;
  final String? errorMessage;
  final bool isAuthenticated;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get isEmpty => !hasError && todayTotal == 0 && weaknesses.isEmpty;

  bool get hasStudySignal =>
      !hasError && (todayTotal > 0 || weaknesses.isNotEmpty);

  Map<String, dynamic> toSanitizedGuidanceInput() {
    return {
      'source': 'recall_praticase_summary',
      'today_total': todayTotal,
      'weaknesses': [
        for (final weakness in weaknesses.take(5)) weakness.toSanitizedJson(),
      ],
    };
  }
}

class RecallWeakness {
  const RecallWeakness({
    required this.title,
    required this.riskLevel,
    required this.topic,
  });

  final String title;
  final String riskLevel;
  final String topic;

  Map<String, dynamic> toSanitizedJson() {
    return {'title': title, 'risk_level': riskLevel, 'topic': topic};
  }
}

class RecallGuidance {
  const RecallGuidance({required this.sentence, required this.action});

  const RecallGuidance.empty() : sentence = '', action = '';

  final String sentence;
  final String action;

  String get displayText => sentence.trim().isNotEmpty ? sentence : action;
}
