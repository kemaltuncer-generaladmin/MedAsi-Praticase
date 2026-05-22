class ProfileSetup {
  const ProfileSetup({
    required this.grade,
    required this.targetExam,
    required this.targetBranches,
    required this.dailyGoal,
    this.examDate,
  });

  final String grade;
  final String targetExam;
  final List<String> targetBranches;
  final int dailyGoal;
  final DateTime? examDate;
}
