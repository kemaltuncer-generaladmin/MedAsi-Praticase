class EcosystemSetupProfile {
  const EcosystemSetupProfile({
    required this.userId,
    required this.email,
    required this.sourceApp,
    required this.lastCompletedApp,
    required this.universityName,
    required this.universityType,
    required this.classLevel,
    required this.targetExam,
    required this.dailyGoal,
    required this.weeklyGoalDays,
    required this.helpStyle,
    required this.learningPace,
    required this.feedbackTone,
    required this.notifyMorning,
    required this.notifyEvening,
    required this.notifyCritical,
    this.fullName,
    this.universityCity,
    this.universityOther,
    this.examDate,
    this.syllabusFileName,
  });

  final String userId;
  final String email;
  final String? fullName;
  final String sourceApp;
  final String lastCompletedApp;
  final String universityName;
  final String? universityCity;
  final String universityType;
  final String? universityOther;
  final String classLevel;
  final String targetExam;
  final DateTime? examDate;
  final int dailyGoal;
  final int weeklyGoalDays;
  final String helpStyle;
  final String learningPace;
  final String feedbackTone;
  final bool notifyMorning;
  final bool notifyEvening;
  final bool notifyCritical;
  final String? syllabusFileName;

  factory EcosystemSetupProfile.fromJson(Map<String, dynamic> json) {
    return EcosystemSetupProfile(
      userId: _string(json['user_id']),
      email: _string(json['email']),
      fullName: _nullableString(json['full_name']),
      sourceApp: _string(json['source_app'], fallback: 'medasi'),
      lastCompletedApp: _string(json['last_completed_app'], fallback: 'medasi'),
      universityName: _string(json['university_name']),
      universityCity: _nullableString(json['university_city']),
      universityType: _string(json['university_type'], fallback: 'Diğer'),
      universityOther: _nullableString(json['university_other']),
      classLevel: _string(json['class_level'], fallback: '5'),
      targetExam: _string(json['target_exam'], fallback: 'OSCE Sınavı'),
      examDate: DateTime.tryParse(_string(json['exam_date'])),
      dailyGoal: _int(json['daily_goal'], fallback: 2),
      weeklyGoalDays: _int(json['weekly_goal_days'], fallback: 5),
      helpStyle: _string(json['help_style'], fallback: 'hint'),
      learningPace: _string(json['learning_pace'], fallback: 'balanced'),
      feedbackTone: _string(json['feedback_tone'], fallback: 'friendly'),
      notifyMorning: _bool(json['notify_morning'], fallback: true),
      notifyEvening: _bool(json['notify_evening']),
      notifyCritical: _bool(json['notify_critical'], fallback: true),
      syllabusFileName: _nullableString(json['syllabus_file_name']),
    );
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    return switch (value?.toString().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => fallback,
    };
  }
}
