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
    for (final value in filters) {
      if (value is! Map) continue;
      final course = _string(value, 'subject');
      final topic = _string(value, 'topic');
      if (course.isEmpty) continue;
      topicsByCourse.putIfAbsent(course, () => <String>{});
      if (topic.isNotEmpty) topicsByCourse[course]!.add(topic);
    }

    final courses = topicsByCourse.keys.toList()..sort(_compare);
    return TheoreticalExamFilters(
      courses: courses,
      topicsByCourse: {
        for (final entry in topicsByCourse.entries)
          entry.key: (entry.value.toList()..sort(_compare)),
      },
    );
  }

  @override
  Future<List<TheoreticalQuestion>> loadQuestions({
    required Set<String> courses,
    String topic = '',
    int limit = 20,
  }) async {
    final data = await _invoke('questions', {
      'subjects': courses.toList()..sort(_compare),
      'topic': topic,
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
      throw const TheoreticalExamUnavailable(
        'Kuramsal sınav yanıtı okunamadı.',
      );
    } on FunctionException catch (error) {
      throw TheoreticalExamUnavailable(
        error.details?.toString() ??
            error.reasonPhrase ??
            'Kuramsal sınav servisi açılamadı.',
      );
    } on TheoreticalExamUnavailable {
      rethrow;
    } on Object {
      throw const TheoreticalExamUnavailable(
        'Kuramsal sınav servisiyle bağlantı kurulamadı.',
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
