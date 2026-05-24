import '../domain/theoretical_exam_models.dart';

abstract interface class TheoreticalExamRepository {
  Future<TheoreticalExamFilters> loadFilters();

  Future<List<TheoreticalQuestion>> loadQuestions({
    required Set<String> courses,
    Set<String> topics = const <String>{},
    List<TheoreticalCoursePlan> plans = const <TheoreticalCoursePlan>[],
    int limit = 20,
  });

  Future<TheoreticalExamSubmissionResult> submitAttempt({
    required TheoreticalExamAttempt attempt,
    required Duration elapsed,
  });
}

class TheoreticalExamUnavailable implements Exception {
  const TheoreticalExamUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
