import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/user_facing_error.dart';
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
          .select(
            'id,title,difficulty,description,patience_level,sort_order,panel_role',
          )
          .order('sort_order');
      final branchRows = await _client
          .schema('praticase')
          .from('oral_exam_branches')
          .select('id,title,description,sort_order')
          .order('sort_order');
      final scenariosByBranch = <String, List<OralExamScenario>>{};
      try {
        final scenarioRows = await _client
            .schema('praticase')
            .from('oral_exam_scenarios')
            .select('id,branch_id,title,case_brief,difficulty_floor,sort_order')
            .order('sort_order');
        for (final row in scenarioRows) {
          final branchId = _string(row, 'branch_id');
          scenariosByBranch
              .putIfAbsent(branchId, () => [])
              .add(
                OralExamScenario(
                  id: _string(row, 'id'),
                  branchId: branchId,
                  title: _string(row, 'title'),
                  caseBrief: _string(row, 'case_brief'),
                  difficultyFloor: _string(row, 'difficulty_floor'),
                  sortOrder: _int(row, 'sort_order'),
                ),
              );
        }
      } on PostgrestException catch (error) {
        if (error.code != '42P01' &&
            error.code != 'PGRST205' &&
            !error.message.toLowerCase().contains('does not exist') &&
            !error.message.toLowerCase().contains('schema cache')) {
          rethrow;
        }
      }
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
              panelRole: _string(row, 'panel_role'),
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
        scenariosByBranch: scenariosByBranch,
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
    String? scenarioId,
    OralExamFormat format = OralExamFormat.solo,
  }) async {
    final response = await _invoke({
      'action': 'start',
      'persona_id': personaId,
      'branch_id': branchId,
      'duration_seconds': durationSeconds,
      'exam_format': format.apiValue,
      if (scenarioId != null && scenarioId.isNotEmpty)
        'scenario_id': scenarioId,
    });
    final persona = (response['persona'] as Map?) ?? const {};
    final branch = (response['branch'] as Map?) ?? const {};
    final panelList = (response['panel'] as List?) ?? const [];
    final panel = <OralExamPersona>[
      for (final raw in panelList)
        if (raw is Map)
          OralExamPersona(
            id: _stringFrom(raw, 'id'),
            title: _stringFrom(raw, 'title'),
            difficulty: _stringFrom(raw, 'difficulty'),
            description: '',
            patienceLevel: 5,
            sortOrder: 0,
            panelRole: _stringFrom(raw, 'panel_role'),
          ),
    ];
    return OralExamSession(
      id: _stringFrom(response, 'session_id'),
      durationSeconds: _intFrom(response, 'duration_seconds'),
      caseBrief: _safeMentorText(
        _stringFrom(response, 'case_brief'),
        fallback: 'Klinik vaka bilgisi hazırlanıyor.',
      ),
      startedAt:
          DateTime.tryParse(_stringFrom(response, 'started_at')) ??
          DateTime.now(),
      personaId: _stringFrom(persona, 'id'),
      personaTitle: _stringFrom(persona, 'title'),
      difficulty: _stringFrom(persona, 'difficulty'),
      branchId: _stringFrom(branch, 'id'),
      branchTitle: _stringFrom(branch, 'title'),
      openingMessage: _safeMentorText(
        _stringFrom(response, 'mentor_message'),
        fallback:
            'Vaka üzerinden ilerleyelim. Öncelikle yaklaşımını nasıl yapılandırırsın?',
      ),
      format: OralExamFormat.fromApi(_stringFrom(response, 'exam_format')),
      panel: panel,
      activePersonaId: _stringFrom(response, 'active_persona_id').isNotEmpty
          ? _stringFrom(response, 'active_persona_id')
          : _stringFrom(persona, 'id'),
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
    final mentorMessages = _mentorMessagesFrom(response);
    return OralExamTurnResult(
      mentorMessage: _safeMentorText(_stringFrom(response, 'mentor_message')),
      mentorMessages: mentorMessages,
      isFollowup: response['is_followup'] == true,
      shouldEnd: response['should_end'] == true,
      remainingSeconds: _intFrom(response, 'remaining_seconds'),
      scoreDelta: _intFrom(eval, 'score_delta'),
      reasoningNote: _stringFrom(eval, 'reasoning'),
      isCorrect: eval['is_correct'] == true,
      activePersonaId: _stringFrom(response, 'active_persona_id'),
      activePersonaTitle: _stringFrom(response, 'active_persona_title'),
    );
  }

  @override
  Future<List<OralExamMessage>> skipQuestion(String sessionId) async {
    final response = await _invoke({'action': 'skip', 'session_id': sessionId});
    return _mentorMessagesFrom(response);
  }

  @override
  Future<OralExamResult> finalizeSession(String sessionId) async {
    final response = await _invoke({
      'action': 'finalize',
      'session_id': sessionId,
    });
    final data = (response['result'] as Map?) ?? const {};
    final panelSummaries = (data['panel_summaries'] as Map?) ?? const {};
    final verdicts = <OralExamPanelVerdict>[
      for (final entry in panelSummaries.entries)
        if (entry.value is Map)
          OralExamPanelVerdict(
            personaId: entry.key.toString(),
            verdict: _safeResultText(
              _stringFrom(entry.value as Map, 'verdict'),
            ),
            note: _safeResultText(_stringFrom(entry.value as Map, 'note')),
          ),
    ];
    return OralExamResult(
      sessionId: _stringFrom(data, 'id'),
      totalScore: _intFrom(data, 'total_score'),
      maxScore: _intFrom(data, 'max_score'),
      reasoningScore: _intFrom(data, 'reasoning_score'),
      knowledgeScore: _intFrom(data, 'knowledge_score'),
      communicationScore: _intFrom(data, 'communication_score'),
      paceScore: _intFrom(data, 'pace_score'),
      professionalismScore: _intFrom(data, 'professionalism_score'),
      mentorSummary: _safeResultText(
        _stringFrom(data, 'mentor_summary'),
        fallback: 'Klinik değerlendirme tamamlandı.',
      ),
      strongPoints: _safeStringList(data['strong_points']),
      improvementPoints: _safeStringList(data['improvement_points']),
      missedPoints: _safeStringList(data['missed_points']),
      caseBrief: _safeResultText(_stringFrom(data, 'case_brief')),
      format: OralExamFormat.fromApi(_stringFrom(data, 'exam_format')),
      panelVerdicts: verdicts,
    );
  }

  @override
  Future<List<OralExamMessage>> loadTranscript(String sessionId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('oral_exam_turns')
          .select(
            'speaker,message,is_followup,was_skipped,sequence,speaker_persona_id',
          )
          .eq('session_id', sessionId)
          .order('sequence');
      return [
        for (final row in rows)
          OralExamMessage(
            speaker: _string(row, 'speaker'),
            message: _string(row, 'speaker') == 'mentor'
                ? _safeMentorText(_string(row, 'message'))
                : _string(row, 'message'),
            isFollowup: row['is_followup'] == true,
            wasSkipped: row['was_skipped'] == true,
            personaId: _string(row, 'speaker_persona_id'),
          ),
      ];
    } on PostgrestException catch (error) {
      throw OralExamUnavailable(_friendly(error));
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final fallback = body['action'] == 'finalize'
        ? PratiCaseUserMessage.reportFailure
        : PratiCaseUserMessage.oralExamFailure;
    try {
      final response = await _client.functions.invoke(
        'praticase-oral-exam',
        body: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final error = data['error']?.toString().trim() ?? '';
        if (error.isNotEmpty) {
          throw OralExamUnavailable(
            PratiCaseUserMessage.safe(error, fallback: fallback),
          );
        }
        return data;
      }
      if (data is Map) return Map<String, dynamic>.from(data);
      throw OralExamUnavailable(fallback);
    } on FunctionException {
      throw OralExamUnavailable(fallback);
    } on OralExamUnavailable {
      rethrow;
    } on Object {
      throw OralExamUnavailable(fallback);
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
    return 'Sözlü sınav verisi alınamadı. Bağlantını kontrol edip tekrar dene.';
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

  List<String> _safeStringList(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          if ((item?.toString().trim() ?? '').isNotEmpty)
            _safeResultText(item!.toString()),
      ];
    }
    return const <String>[];
  }

  List<OralExamMessage> _mentorMessagesFrom(Map<String, dynamic> response) {
    final rawMessages = response['committee_messages'];
    if (rawMessages is List) {
      final messages = <OralExamMessage>[
        for (final raw in rawMessages)
          if (raw is Map && _stringFrom(raw, 'message').isNotEmpty)
            OralExamMessage(
              speaker: 'mentor',
              message: _safeMentorText(_stringFrom(raw, 'message')),
              personaId: _stringFrom(raw, 'persona_id'),
              personaTitle: _stringFrom(raw, 'persona_title'),
              isFollowup: raw['asks_question'] == true,
            ),
      ];
      if (messages.isNotEmpty) return messages;
    }

    final message = _safeMentorText(_stringFrom(response, 'mentor_message'));
    if (message.isEmpty) return const <OralExamMessage>[];
    return [
      OralExamMessage(
        speaker: 'mentor',
        message: message,
        personaId: _stringFrom(response, 'active_persona_id'),
        personaTitle: _stringFrom(response, 'active_persona_title'),
        isFollowup: response['is_followup'] == true,
      ),
    ];
  }

  String _safeMentorText(String value, {String? fallback}) {
    return PratiCaseUserMessage.mentorMessage(value, fallback: fallback);
  }

  String _safeResultText(String value, {String? fallback}) {
    return PratiCaseUserMessage.safe(
      value,
      fallback: fallback ?? 'Değerlendirme bilgisi hazırlanamadı.',
    );
  }
}
