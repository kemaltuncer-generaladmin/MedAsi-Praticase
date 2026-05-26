class TheoreticalExamFilters {
  const TheoreticalExamFilters({
    required this.courses,
    required this.topicsByCourse,
    this.topicOptionsByCourse = const <String, List<TheoreticalTopicOption>>{},
    this.totalQuestionCount = 0,
    this.remainingQuestionCount = 0,
  });

  final List<String> courses;
  final Map<String, List<String>> topicsByCourse;
  final Map<String, List<TheoreticalTopicOption>> topicOptionsByCourse;
  final int totalQuestionCount;
  final int remainingQuestionCount;

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

  List<TheoreticalTopicOption> topicOptionsFor(String course) {
    final options = topicOptionsByCourse[course];
    if (options != null && options.isNotEmpty) return options;
    return [
      for (final topic in topicsByCourse[course] ?? const <String>[])
        TheoreticalTopicOption(
          course: course,
          topic: topic,
          metadataValue: topic,
          totalCount: 0,
          remainingCount: 0,
        ),
    ];
  }
}

class TheoreticalTopicOption {
  const TheoreticalTopicOption({
    required this.course,
    required this.topic,
    required this.metadataValue,
    required this.totalCount,
    required this.remainingCount,
    this.difficulty = '',
  });

  final String course;
  final String topic;
  final String metadataValue;
  final int totalCount;
  final int remainingCount;
  final String difficulty;

  String get key => '$course\u0000$topic\u0000$metadataValue';

  String get title => metadataValue.isNotEmpty ? metadataValue : topic;

  String get subtitle {
    if (topic.isEmpty || topic == title) return '';
    return topic;
  }
}

class TheoreticalCoursePlan {
  const TheoreticalCoursePlan({
    required this.course,
    required this.questionCount,
    this.topics = const <TheoreticalTopicOption>[],
  });

  final String course;
  final int questionCount;
  final List<TheoreticalTopicOption> topics;

  int get topicCount => topics.length;
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
    this.tags = const <String>[],
    this.metadata = const <String, dynamic>{},
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
  final List<String> tags;
  final Map<String, dynamic> metadata;

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

class TheoreticalExamSubmissionResult {
  const TheoreticalExamSubmissionResult({
    required this.submittedCount,
    required this.syncedCount,
    required this.remainingQuestionQuota,
    this.errorMessage = '',
  });

  final int submittedCount;
  final int syncedCount;
  final int? remainingQuestionQuota;
  final String errorMessage;

  bool get fullySynced => submittedCount == syncedCount && errorMessage.isEmpty;
}

int _turkishCompare(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());
