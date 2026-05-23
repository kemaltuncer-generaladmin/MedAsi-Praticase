class TheoreticalExamFilters {
  const TheoreticalExamFilters({
    required this.courses,
    required this.topicsByCourse,
  });

  final List<String> courses;
  final Map<String, List<String>> topicsByCourse;

  List<String> topicsFor(Set<String> selectedCourses) {
    final topics = <String>{};
    if (selectedCourses.isEmpty) {
      for (final values in topicsByCourse.values) {
        topics.addAll(values);
      }
    } else {
      for (final course in selectedCourses) {
        topics.addAll(topicsByCourse[course] ?? const <String>[]);
      }
    }
    final sorted = topics.toList()..sort(_turkishCompare);
    return sorted;
  }
}

class TheoreticalQuestion {
  const TheoreticalQuestion({
    required this.id,
    required this.course,
    required this.topic,
    required this.difficulty,
    required this.stem,
    required this.options,
    this.correctOptionId,
    this.explanation = '',
    this.optionRationales = const <String>[],
  });

  final String id;
  final String course;
  final String topic;
  final String difficulty;
  final String stem;
  final List<TheoreticalQuestionOption> options;
  final String? correctOptionId;
  final String explanation;
  final List<String> optionRationales;

  bool get canScore => correctOptionId != null && correctOptionId!.isNotEmpty;
}

class TheoreticalQuestionOption {
  const TheoreticalQuestionOption({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
}

class TheoreticalExamAttempt {
  const TheoreticalExamAttempt({
    required this.questions,
    required this.selectedOptionIds,
    required this.startedAt,
  });

  final List<TheoreticalQuestion> questions;
  final Map<String, String> selectedOptionIds;
  final DateTime startedAt;

  int get answeredCount => selectedOptionIds.length;

  int get scorableCount =>
      questions.where((question) => question.canScore).length;

  int get correctCount {
    var count = 0;
    for (final question in questions) {
      if (!question.canScore) continue;
      if (selectedOptionIds[question.id] == question.correctOptionId) {
        count += 1;
      }
    }
    return count;
  }

  int get percent {
    final total = scorableCount;
    if (total == 0) return 0;
    return ((correctCount / total) * 100).round().clamp(0, 100).toInt();
  }
}

int _turkishCompare(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());
