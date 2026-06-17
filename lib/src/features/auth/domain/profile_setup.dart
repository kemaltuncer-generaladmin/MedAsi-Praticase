class ProfileSetup {
  const ProfileSetup({
    required this.discipline,
    required this.grade,
    required this.targetExam,
    required this.targetBranches,
    required this.dailyGoal,
    required this.universityName,
    required this.universityType,
    required this.weeklyGoalDays,
    required this.helpStyle,
    required this.learningPace,
    required this.feedbackTone,
    required this.notifyMorning,
    required this.notifyEvening,
    required this.notifyCritical,
    this.syllabusFileName,
    this.storeAction = 'skip',
    this.storePackageLabel,
    this.fullName,
    this.universityCity,
    this.universityOther,
    this.examDate,
  });

  final String discipline;
  final String grade;
  final String targetExam;
  final List<String> targetBranches;
  final int dailyGoal;
  final String? fullName;
  final String universityName;
  final String? universityCity;
  final String universityType;
  final String? universityOther;
  final int weeklyGoalDays;
  final String helpStyle;
  final String learningPace;
  final String feedbackTone;
  final bool notifyMorning;
  final bool notifyEvening;
  final bool notifyCritical;
  final String? syllabusFileName;
  final String storeAction;
  final String? storePackageLabel;
  final DateTime? examDate;
}
