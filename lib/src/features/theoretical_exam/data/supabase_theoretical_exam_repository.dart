import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/theoretical_exam_models.dart';
import 'theoretical_exam_repository.dart';

class SupabaseTheoreticalExamRepository implements TheoreticalExamRepository {
  const SupabaseTheoreticalExamRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<TheoreticalExamFilters> loadFilters() async {
    final data = await _invoke('filters');
    final filters = data['filters'];
    if (filters is! List) {
      throw const TheoreticalExamUnavailable(
        'Qlinik soru filtreleri okunamadı.',
      );
    }

    final topicsByCourse = <String, Set<String>>{};
    final topicOptionsByCourse = <String, List<TheoreticalTopicOption>>{};
    final seenOptions = <String>{};
    for (final value in filters) {
      if (value is! Map) continue;
      final course = _string(value, 'subject');
      final topic = _string(value, 'topic');
      final metadataValue = _string(value, 'metadata_value');
      if (course.isEmpty) continue;
      topicsByCourse.putIfAbsent(course, () => <String>{});
      final displayTopic = metadataValue.isNotEmpty ? metadataValue : topic;
      if (displayTopic.isNotEmpty) topicsByCourse[course]!.add(displayTopic);
      final optionKey = '$course\u0000$topic\u0000$metadataValue';
      if (seenOptions.add(optionKey)) {
        topicOptionsByCourse.putIfAbsent(
          course,
          () => <TheoreticalTopicOption>[],
        );
        topicOptionsByCourse[course]!.add(
          TheoreticalTopicOption(
            course: course,
            topic: topic,
            metadataValue: metadataValue,
            totalCount: _int(value, 'total_count'),
            remainingCount: _int(value, 'remaining_count'),
            difficulty: _string(value, 'difficulty'),
          ),
        );
      }
    }

    final courses = topicsByCourse.keys.toList()..sort(_compare);
    return TheoreticalExamFilters(
      courses: courses,
      topicsByCourse: {
        for (final entry in topicsByCourse.entries)
          entry.key: (entry.value.toList()..sort(_compare)),
      },
      topicOptionsByCourse: {
        for (final entry in topicOptionsByCourse.entries)
          entry.key: entry.value..sort(_compareTopicOptions),
      },
    );
  }

  @override
  Future<List<TheoreticalQuestion>> loadQuestions({
    required Set<String> courses,
    Set<String> topics = const <String>{},
    List<TheoreticalCoursePlan> plans = const <TheoreticalCoursePlan>[],
    int limit = 20,
  }) async {
    final data = await _invoke('questions', {
      'subjects': courses.toList()..sort(_compare),
      'topics': topics.toList()..sort(_compare),
      'plans': [
        for (final plan in plans)
          {
            'subject': plan.course,
            'limit': plan.questionCount,
            'topics': [
              for (final topic in plan.topics)
                {
                  'topic': topic.topic,
                  'metadata_value': topic.metadataValue,
                  'difficulty': topic.difficulty,
                },
            ],
          },
      ],
      'limit': limit,
    });
    final rows = data['questions'];
    if (rows is! List) {
      throw const TheoreticalExamUnavailable('Qlinik soruları okunamadı.');
    }
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) _question(row),
    ];
  }

  @override
  Future<TheoreticalExamSubmissionResult> submitAttempt({
    required TheoreticalExamAttempt attempt,
    required Duration elapsed,
  }) async {
    final answers = [
      for (final entry in attempt.selectedOptionIds.entries)
        {'questionId': entry.key, 'selectedOptionId': entry.value},
    ];
    final data = await _invoke('submit_attempt', {
      'answers': answers,
      'elapsedSeconds': elapsed.inSeconds,
      'startedAt': attempt.startedAt.toUtc().toIso8601String(),
    });
    return TheoreticalExamSubmissionResult(
      submittedCount: _int(data, 'submittedCount'),
      syncedCount: _int(data, 'syncedCount'),
      remainingQuestionQuota: data['remainingQuestionQuota'] == null
          ? null
          : _int(data, 'remainingQuestionQuota'),
      errorMessage: _string(data, 'warning'),
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-theoretical-exam',
        body: {'action': action, ...payload},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final error = data['error']?.toString().trim() ?? '';
        if (error.isNotEmpty) throw TheoreticalExamUnavailable(error);
        return data;
      }
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const TheoreticalExamUnavailable('Teorik sınav yanıtı okunamadı.');
    } on FunctionException catch (error) {
      throw TheoreticalExamUnavailable(
        error.details?.toString() ??
            error.reasonPhrase ??
            'Teorik sınav servisi açılamadı.',
      );
    } on TheoreticalExamUnavailable {
      rethrow;
    } on Object {
      throw const TheoreticalExamUnavailable(
        'Teorik sınav servisiyle bağlantı kurulamadı.',
      );
    }
  }
}

TheoreticalQuestion _question(Map<String, dynamic> row) {
  final rawOptions = row['options'];
  final options = <TheoreticalQuestionOption>[];
  if (rawOptions is List) {
    for (var index = 0; index < rawOptions.length; index++) {
      final text = rawOptions[index]?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      options.add(
        TheoreticalQuestionOption(
          id: index.toString(),
          label: String.fromCharCode(65 + options.length),
          text: text,
        ),
      );
    }
  }
  final correctIndex = (row['correct_index'] as num?)?.toInt();
  return TheoreticalQuestion(
    id: _string(row, 'id'),
    course: _string(row, 'subject'),
    topic: _string(row, 'topic'),
    difficulty: _string(row, 'difficulty'),
    stem: _string(row, 'text'),
    options: options,
    correctOptionId:
        correctIndex == null ||
            correctIndex < 0 ||
            correctIndex >= options.length
        ? null
        : correctIndex.toString(),
    explanation: _string(row, 'explanation'),
    optionRationales: _stringList(row['option_rationales']),
  );
}

String _string(Map<dynamic, dynamic> row, String key) =>
    row[key]?.toString().trim() ?? '';

List<String> _stringList(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if ((item?.toString().trim() ?? '').isNotEmpty) item!.toString().trim(),
    ];
  }
  return const <String>[];
}

int _compare(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

int _compareTopicOptions(TheoreticalTopicOption a, TheoreticalTopicOption b) {
  final titleCompare = _compare(a.title, b.title);
  if (titleCompare != 0) return titleCompare;
  return _compare(a.subtitle, b.subtitle);
}

int _int(Map<dynamic, dynamic> row, String key) {
  final value = row[key];
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
