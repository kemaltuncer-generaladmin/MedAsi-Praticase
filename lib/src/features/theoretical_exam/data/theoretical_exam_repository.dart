import '../domain/theoretical_exam_models.dart';

abstract interface class TheoreticalExamRepository {
  Future<TheoreticalExamFilters> loadFilters();

  Future<List<TheoreticalQuestion>> loadQuestions({
    required Set<String> courses,
    String topic = '',
    int limit = 20,
  });
}

class TheoreticalExamUnavailable implements Exception {
  const TheoreticalExamUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
