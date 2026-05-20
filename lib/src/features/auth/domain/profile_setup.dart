class ProfileSetup {
  const ProfileSetup({
    required this.grade,
    required this.targetBranches,
    required this.dailyGoal,
    this.examDate,
  });

  final String grade;
  final List<String> targetBranches;
  final int dailyGoal;
  final DateTime? examDate;
}
