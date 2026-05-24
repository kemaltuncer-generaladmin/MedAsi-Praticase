import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/oral_exam_models.dart';
import 'oral_exam_repository.dart';

class SupabaseOralExamRepository implements OralExamRepository {
  const SupabaseOralExamRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<OralExamCatalog> loadCatalog() async {
    try {
      final personaRows = await _client
          .schema('praticase')
          .from('oral_exam_personas')
          .select('id,title,difficulty,description,patience_level,sort_order')
          .order('sort_order');
      final branchRows = await _client
          .schema('praticase')
          .from('oral_exam_branches')
          .select('id,title,description,sort_order')
          .order('sort_order');
      return OralExamCatalog(
        personas: [
          for (final row in personaRows)
            OralExamPersona(
              id: _string(row, 'id'),
              title: _string(row, 'title'),
              difficulty: _string(row, 'difficulty'),
              description: _string(row, 'description'),
              patienceLevel: _int(row, 'patience_level'),
              sortOrder: _int(row, 'sort_order'),
            ),
        ],
        branches: [
          for (final row in branchRows)
            OralExamBranch(
              id: _string(row, 'id'),
              title: _string(row, 'title'),
              description: _string(row, 'description'),
              sortOrder: _int(row, 'sort_order'),
            ),
        ],
      );
    } on PostgrestException catch (error) {
      throw OralExamUnavailable(_friendly(error));
    }
  }

  @override
  Future<OralExamSession> startSession({
    required String personaId,
    required String branchId,
    required int durationSeconds,
  }) async {
    final response = await _invoke({
      'action': 'start',
      'persona_id': personaId,
      'branch_id': branchId,
      'duration_seconds': durationSeconds,
    });
    final persona = (response['persona'] as Map?) ?? const {};
    final branch = (response['branch'] as Map?) ?? const {};
    return OralExamSession(
      id: _stringFrom(response, 'session_id'),
      durationSeconds: _intFrom(response, 'duration_seconds'),
      caseBrief: _stringFrom(response, 'case_brief'),
      startedAt: DateTime.tryParse(_stringFrom(response, 'started_at')) ??
          DateTime.now(),
      personaId: _stringFrom(persona, 'id'),
      personaTitle: _stringFrom(persona, 'title'),
      difficulty: _stringFrom(persona, 'difficulty'),
      branchId: _stringFrom(branch, 'id'),
      branchTitle: _stringFrom(branch, 'title'),
      openingMessage: _stringFrom(response, 'mentor_message'),
    );
  }

  @override
  Future<OralExamTurnResult> sendAnswer({
    required String sessionId,
    required String message,
  }) async {
    final response = await _invoke({
      'action': 'turn',
      'session_id': sessionId,
      'message': message,
    });
    final eval = (response['turn_evaluation'] as Map?) ?? const {};
    return OralExamTurnResult(
      mentorMessage: _stringFrom(response, 'mentor_message'),
      isFollowup: response['is_followup'] == true,
      shouldEnd: response['should_end'] == true,
      remainingSeconds: _intFrom(response, 'remaining_seconds'),
      scoreDelta: _intFrom(eval, 'score_delta'),
      reasoningNote: _stringFrom(eval, 'reasoning'),
      isCorrect: eval['is_correct'] == true,
    );
  }

  @override
  Future<String> skipQuestion(String sessionId) async {
    final response = await _invoke({
      'action': 'skip',
      'session_id': sessionId,
    });
    return _stringFrom(response, 'mentor_message');
  }

  @override
  Future<OralExamResult> finalizeSession(String sessionId) async {
    final response = await _invoke({
      'action': 'finalize',
      'session_id': sessionId,
    });
    final data = (response['result'] as Map?) ?? const {};
    return OralExamResult(
      sessionId: _stringFrom(data, 'id'),
      totalScore: _intFrom(data, 'total_score'),
      maxScore: _intFrom(data, 'max_score'),
      reasoningScore: _intFrom(data, 'reasoning_score'),
      knowledgeScore: _intFrom(data, 'knowledge_score'),
      communicationScore: _intFrom(data, 'communication_score'),
      paceScore: _intFrom(data, 'pace_score'),
      professionalismScore: _intFrom(data, 'professionalism_score'),
      mentorSummary: _stringFrom(data, 'mentor_summary'),
      strongPoints: _stringList(data['strong_points']),
      improvementPoints: _stringList(data['improvement_points']),
      missedPoints: _stringList(data['missed_points']),
      caseBrief: _stringFrom(data, 'case_brief'),
    );
  }

  @override
  Future<List<OralExamMessage>> loadTranscript(String sessionId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('oral_exam_turns')
          .select('speaker,message,is_followup,was_skipped,sequence')
          .eq('session_id', sessionId)
          .order('sequence');
      return [
        for (final row in rows)
          OralExamMessage(
            speaker: _string(row, 'speaker'),
            message: _string(row, 'message'),
            isFollowup: row['is_followup'] == true,
            wasSkipped: row['was_skipped'] == true,
          ),
      ];
    } on PostgrestException catch (error) {
      throw OralExamUnavailable(_friendly(error));
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-oral-exam',
        body: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final error = data['error']?.toString().trim() ?? '';
        if (error.isNotEmpty) throw OralExamUnavailable(error);
        return data;
      }
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const OralExamUnavailable('Sözlü sınav yanıtı okunamadı.');
    } on FunctionException catch (error) {
      throw OralExamUnavailable(
        (error.details?.toString().trim().isNotEmpty == true
                ? error.details!.toString().trim()
                : null) ??
            error.reasonPhrase ??
            'Sözlü sınav servisi açılamadı.',
      );
    } on OralExamUnavailable {
      rethrow;
    } on Object {
      throw const OralExamUnavailable(
        'Sözlü sınav servisiyle bağlantı kurulamadı.',
      );
    }
  }

  String _friendly(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (error.code == '42P01' ||
        error.code == 'PGRST205' ||
        message.contains('schema cache') ||
        message.contains('does not exist')) {
      return 'Sözlü sınav modülü hazırlanıyor. Lütfen daha sonra tekrar dene.';
    }
    return 'Sözlü sınav verisi alınamadı. Bağlantı ve yetkileri kontrol et.';
  }

  String _string(Map<String, dynamic> row, String key) =>
      row[key]?.toString().trim() ?? '';

  int _int(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _stringFrom(Map source, String key) =>
      source[key]?.toString().trim() ?? '';

  int _intFrom(Map source, String key) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          if ((item?.toString().trim() ?? '').isNotEmpty)
            item!.toString().trim(),
      ];
    }
    return const <String>[];
  }
}
