import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/osce_case.dart';
import 'cases_repository.dart';

class SupabaseCasesRepository implements CasesRepository {
  const SupabaseCasesRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  }) async {
    try {
      var request = _client
          .schema('praticase')
          .from('user_case_library')
          .select(
            'case_id,title,branch,setting,difficulty,duration_minutes,points,'
            'solved_count,summary,icon_key,is_bookmarked,progress_percent,last_score',
          );
      final trimmed = query.trim();
      if (trimmed.isNotEmpty) {
        request = request.ilike('title', '%$trimmed%');
      }
      if (difficulty != null && difficulty.trim().isNotEmpty) {
        request = request.eq('difficulty', difficulty.trim());
      }
      final rows = await request.order('title');
      return [for (final row in rows) _summary(row)];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<OsceCaseDetail> loadCaseDetail(String caseId) async {
    try {
      final row = await _client
          .schema('praticase')
          .from('user_case_library')
          .select(
            'case_id,title,branch,setting,difficulty,duration_minutes,points,'
            'solved_count,summary,icon_key,is_bookmarked,progress_percent,last_score',
          )
          .eq('case_id', caseId)
          .single();
      final caseRow = await _client
          .schema('praticase')
          .from('cases')
          .select('candidate_prompt,patient_profile,flow_steps,goals')
          .eq('id', caseId)
          .single();

      return OsceCaseDetail(
        summary: _summary(row),
        candidatePrompt: _string(caseRow, 'candidate_prompt'),
        patient: _patient(caseRow['patient_profile']),
        flowSteps: _flowSteps(caseRow['flow_steps']),
        goals: _goals(caseRow['goals']),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> setBookmark({
    required String caseId,
    required bool bookmarked,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const CasesDataUnavailable('Oturum bulunamadı.');
    try {
      final table = _client.schema('praticase').from('user_bookmarked_cases');
      if (bookmarked) {
        await table.upsert({'user_id': user.id, 'case_id': caseId});
      } else {
        await table.delete().eq('user_id', user.id).eq('case_id', caseId);
      }
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<ExamSessionOverview> startSession(String caseId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const CasesDataUnavailable('Oturum bulunamadı.');
    try {
      final session = await _client
          .schema('praticase')
          .from('exam_sessions')
          .insert({
            'user_id': user.id,
            'case_id': caseId,
            'current_step': 'history',
          })
          .select('id')
          .single();
      await _client.schema('praticase').from('user_case_progress').upsert({
        'user_id': user.id,
        'case_id': caseId,
        'status': 'in_progress',
        'progress_percent': 20,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,case_id');
      return loadSession(_string(session, 'id'));
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<ExamSessionOverview> loadSession(String sessionId) async {
    try {
      final row = await _client
          .schema('praticase')
          .from('exam_sessions')
          .select(
            'id,case_id,current_step,remaining_points,budget_points,started_at,'
            'cases(title,patient_profile,duration_minutes)',
          )
          .eq('id', sessionId)
          .single();
      final caseData = row['cases'] as Map<String, dynamic>? ?? {};
      return ExamSessionOverview(
        id: _string(row, 'id'),
        caseId: _string(row, 'case_id'),
        caseTitle: _string(caseData, 'title'),
        patient: _patient(caseData['patient_profile']),
        currentStep: _string(row, 'current_step'),
        remainingPoints: _int(row, 'remaining_points'),
        budgetPoints: _int(row, 'budget_points'),
        durationMinutes: _int(caseData, 'duration_minutes'),
        startedAt:
            DateTime.tryParse(_string(row, 'started_at')) ?? DateTime.now(),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<ChatMessage>> loadMessages(String sessionId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('exam_messages')
          .select('id,sender,message,created_at')
          .eq('session_id', sessionId)
          .order('created_at');
      return [for (final row in rows) _messageRow(row)];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> sendPatientQuestion({
    required String sessionId,
    required String message,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-patient-turn',
        body: {'sessionId': sessionId, 'message': message},
      );
      if (response.status >= 400) {
        throw CasesDataUnavailable(_functionMessage(response.data));
      }
    } on CasesDataUnavailable {
      rethrow;
    } on Object {
      throw const CasesDataUnavailable(
        'Yapay zeka hasta yanıtı alınamadı. Lütfen Vertex AI edge function ayarlarını kontrol edin.',
      );
    }
  }

  @override
  Future<List<PhysicalExamGroup>> loadPhysicalExamGroups(String caseId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('physical_exam_groups')
          .select('id,title')
          .eq('case_id', caseId)
          .order('sort_order');
      return [
        for (final row in rows)
          PhysicalExamGroup(
            id: _string(row, 'id'),
            title: _string(row, 'title'),
          ),
      ];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<PhysicalExamOption>> loadPhysicalExamOptions({
    required String sessionId,
    required String caseId,
  }) async {
    try {
      final groups = await _client
          .schema('praticase')
          .from('physical_exam_groups')
          .select(
            'id,physical_exam_options(id,title,finding,point_value,sort_order)',
          )
          .eq('case_id', caseId)
          .order('sort_order');
      final selectedRows = await _client
          .schema('praticase')
          .from('session_physical_exam_findings')
          .select('option_id')
          .eq('session_id', sessionId);
      final selected = {
        for (final row in selectedRows) _string(row, 'option_id'),
      };
      final options = <PhysicalExamOption>[];
      for (final group in groups) {
        final groupId = _string(group, 'id');
        final optionRows =
            group['physical_exam_options'] as List<dynamic>? ?? [];
        optionRows.sort(
          (a, b) => _int(
            a as Map<String, dynamic>,
            'sort_order',
          ).compareTo(_int(b as Map<String, dynamic>, 'sort_order')),
        );
        for (final item in optionRows) {
          final row = item as Map<String, dynamic>;
          final optionId = _string(row, 'id');
          options.add(
            PhysicalExamOption(
              id: optionId,
              groupId: groupId,
              title: _string(row, 'title'),
              finding: _string(row, 'finding'),
              pointValue: _int(row, 'point_value'),
              isSelected: selected.contains(optionId),
            ),
          );
        }
      }
      return options;
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> selectPhysicalExam({
    required String sessionId,
    required String optionId,
  }) async {
    try {
      await _client
          .schema('praticase')
          .from('session_physical_exam_findings')
          .upsert({'session_id': sessionId, 'option_id': optionId});
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<TestGroup>> loadTestGroups(String caseId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('test_groups')
          .select('id,title')
          .eq('case_id', caseId)
          .order('sort_order');
      return [
        for (final row in rows)
          TestGroup(id: _string(row, 'id'), title: _string(row, 'title')),
      ];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<TestOption>> loadTestOptions({
    required String sessionId,
    required String caseId,
  }) async {
    try {
      final groups = await _client
          .schema('praticase')
          .from('test_groups')
          .select('id,test_options(id,title,result,point_cost,sort_order)')
          .eq('case_id', caseId)
          .order('sort_order');
      final selectedRows = await _client
          .schema('praticase')
          .from('session_requested_tests')
          .select('option_id')
          .eq('session_id', sessionId);
      final selected = {
        for (final row in selectedRows) _string(row, 'option_id'),
      };
      final options = <TestOption>[];
      for (final group in groups) {
        final groupId = _string(group, 'id');
        final optionRows = group['test_options'] as List<dynamic>? ?? [];
        optionRows.sort(
          (a, b) => _int(
            a as Map<String, dynamic>,
            'sort_order',
          ).compareTo(_int(b as Map<String, dynamic>, 'sort_order')),
        );
        for (final item in optionRows) {
          final row = item as Map<String, dynamic>;
          final optionId = _string(row, 'id');
          options.add(
            TestOption(
              id: optionId,
              groupId: groupId,
              title: _string(row, 'title'),
              result: _string(row, 'result'),
              pointCost: _int(row, 'point_cost'),
              isSelected: selected.contains(optionId),
            ),
          );
        }
      }
      return options;
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> requestTest({
    required String sessionId,
    required String optionId,
  }) async {
    try {
      await _client.schema('praticase').from('session_requested_tests').upsert({
        'session_id': sessionId,
        'option_id': optionId,
      });
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<DiagnosisOption>> loadDiagnosisOptions({
    required String sessionId,
    required String caseId,
  }) async {
    try {
      final answer = await loadDiagnosisAnswer(sessionId);
      final selected = answer?.selectedOptionIds.toSet() ?? <String>{};
      final rows = await _client
          .schema('praticase')
          .from('diagnosis_options')
          .select('id,title')
          .eq('case_id', caseId)
          .order('sort_order');
      return [
        for (final row in rows)
          DiagnosisOption(
            id: _string(row, 'id'),
            title: _string(row, 'title'),
            isSelected: selected.contains(_string(row, 'id')),
          ),
      ];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<DiagnosisAnswer?> loadDiagnosisAnswer(String sessionId) async {
    try {
      final row = await _client
          .schema('praticase')
          .from('session_diagnosis_answers')
          .select('primary_diagnosis,reasoning,selected_option_ids')
          .eq('session_id', sessionId)
          .maybeSingle();
      if (row == null) return null;
      return DiagnosisAnswer(
        primaryDiagnosis: _string(row, 'primary_diagnosis'),
        reasoning: _string(row, 'reasoning'),
        selectedOptionIds: _stringList(row['selected_option_ids']),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> saveDiagnosisAnswer({
    required String sessionId,
    required String primaryDiagnosis,
    required List<String> selectedOptionIds,
    required String reasoning,
  }) async {
    try {
      await _client
          .schema('praticase')
          .from('session_diagnosis_answers')
          .upsert({
            'session_id': sessionId,
            'primary_diagnosis': primaryDiagnosis.trim(),
            'selected_option_ids': selectedOptionIds,
            'reasoning': reasoning.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<ManagementOption>> loadManagementOptions({
    required String sessionId,
    required String caseId,
  }) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('management_plan_options')
          .select('id,category,title,point_value,sort_order')
          .eq('case_id', caseId)
          .order('category')
          .order('sort_order');
      final selectedRows = await _client
          .schema('praticase')
          .from('session_management_plan_items')
          .select('option_id')
          .eq('session_id', sessionId);
      final selected = {
        for (final row in selectedRows) _string(row, 'option_id'),
      };
      return [
        for (final row in rows)
          ManagementOption(
            id: _string(row, 'id'),
            category: _string(row, 'category'),
            title: _string(row, 'title'),
            pointValue: _int(row, 'point_value'),
            isSelected: selected.contains(_string(row, 'id')),
          ),
      ];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<ManagementPlanAnswer?> loadManagementPlan(String sessionId) async {
    try {
      final note = await _client
          .schema('praticase')
          .from('session_management_notes')
          .select('diagnosis,plan_note')
          .eq('session_id', sessionId)
          .maybeSingle();
      if (note == null) return null;
      final selectedRows = await _client
          .schema('praticase')
          .from('session_management_plan_items')
          .select('option_id')
          .eq('session_id', sessionId);
      return ManagementPlanAnswer(
        diagnosis: _string(note, 'diagnosis'),
        note: _string(note, 'plan_note'),
        selectedOptionIds: [
          for (final row in selectedRows) _string(row, 'option_id'),
        ],
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> saveManagementPlan({
    required String sessionId,
    required String diagnosis,
    required List<String> selectedOptionIds,
    required String note,
  }) async {
    try {
      await _client
          .schema('praticase')
          .from('session_management_notes')
          .upsert({
            'session_id': sessionId,
            'diagnosis': diagnosis.trim(),
            'plan_note': note.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
      if (selectedOptionIds.isNotEmpty) {
        await _client
            .schema('praticase')
            .from('session_management_plan_items')
            .upsert([
              for (final id in selectedOptionIds)
                {'session_id': sessionId, 'option_id': id},
            ]);
      }
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<ExamResultSummary> loadResult(String sessionId) async {
    try {
      await _finalizeSession(sessionId);
      final row = await _client
          .schema('praticase')
          .from('session_result_cards')
          .select(
            'session_id,case_title,total_score,max_score,percentage,'
            'category_scores,strong_points,improvement_points,'
            'critical_mistakes,unnecessary_tests,missed_history,'
            'missed_physical_exam,ideal_approach',
          )
          .eq('session_id', sessionId)
          .single();
      return ExamResultSummary(
        sessionId: _string(row, 'session_id'),
        caseTitle: _string(row, 'case_title'),
        totalScore: _int(row, 'total_score'),
        maxScore: _int(row, 'max_score'),
        percentage: _int(row, 'percentage'),
        categoryScores: _categoryScores(row['category_scores']),
        strongPoints: _stringList(row['strong_points']),
        improvementPoints: _stringList(row['improvement_points']),
        criticalMistakes: _stringList(row['critical_mistakes']),
        unnecessaryTests: _stringList(row['unnecessary_tests']),
        missedHistory: _stringList(row['missed_history']),
        missedPhysicalExam: _stringList(row['missed_physical_exam']),
        idealApproach: _string(row, 'ideal_approach'),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  Future<void> _finalizeSession(String sessionId) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-complete-session',
        body: {'sessionId': sessionId},
      );
      if (response.status >= 400) {
        throw CasesDataUnavailable(_functionMessage(response.data));
      }
    } on CasesDataUnavailable {
      rethrow;
    } on Object {
      throw const CasesDataUnavailable(
        'Yapay zeka sonuç karnesi oluşturulamadı. Lütfen Vertex AI edge function ayarlarını kontrol edin.',
      );
    }
  }

  @override
  Future<LabResultDetail?> loadLabResult(String testOptionId) async {
    try {
      final row = await _client
          .schema('praticase')
          .from('lab_result_details')
          .select('title,measured_at,parameters,interpretation')
          .eq('test_option_id', testOptionId)
          .maybeSingle();
      if (row == null) return null;
      return LabResultDetail(
        title: _string(row, 'title'),
        measuredAt: DateTime.tryParse(_string(row, 'measured_at')),
        parameters: _labParameters(row['parameters']),
        interpretation: _string(row, 'interpretation'),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<ImagingResultDetail?> loadImagingResult(String testOptionId) async {
    try {
      final row = await _client
          .schema('praticase')
          .from('imaging_result_details')
          .select('title,image_url,report,conclusion')
          .eq('test_option_id', testOptionId)
          .maybeSingle();
      if (row == null) return null;
      return ImagingResultDetail(
        title: _string(row, 'title'),
        imageUrl: _string(row, 'image_url'),
        report: _string(row, 'report'),
        conclusion: _string(row, 'conclusion'),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<MedicationInfo>> loadMedicationInfos(String caseId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('medication_infos')
          .select(
            'name,dosage,route,indication,side_effects,contraindications,source_url,sort_order',
          )
          .eq('case_id', caseId)
          .order('sort_order');
      return [
        for (final row in rows)
          MedicationInfo(
            name: _string(row, 'name'),
            dosage: _string(row, 'dosage'),
            route: _string(row, 'route'),
            indication: _string(row, 'indication'),
            sideEffects: _string(row, 'side_effects'),
            contraindications: _string(row, 'contraindications'),
            sourceUrl: _string(row, 'source_url'),
          ),
      ];
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> saveNote({
    required String body,
    String? caseId,
    String title = '',
    String category = 'Genel',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const CasesDataUnavailable('Oturum bulunamadı.');
    try {
      await _client.schema('praticase').from('user_notes').insert({
        'user_id': user.id,
        if (caseId != null && caseId.isNotEmpty) 'case_id': caseId,
        'title': title.trim(),
        'body': body.trim(),
        'category': category.trim().isEmpty ? 'Genel' : category.trim(),
      });
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<CaseProgressOverview> loadCaseProgress(String sessionId) async {
    try {
      final row = await _client
          .schema('praticase')
          .from('user_case_progress_steps')
          .select('session_id,case_title,current_step,steps')
          .eq('session_id', sessionId)
          .single();
      return CaseProgressOverview(
        sessionId: _string(row, 'session_id'),
        caseTitle: _string(row, 'case_title'),
        currentStep: _string(row, 'current_step'),
        steps: _progressSteps(row['steps']),
      );
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> advanceSession({
    required String sessionId,
    required String step,
  }) async {
    try {
      await _client
          .schema('praticase')
          .from('exam_sessions')
          .update({
            'current_step': step,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', sessionId);
      await _updateProgressForStep(sessionId: sessionId, step: step);
    } on PostgrestException catch (error) {
      throw CasesDataUnavailable(_message(error));
    }
  }

  Future<void> _updateProgressForStep({
    required String sessionId,
    required String step,
  }) async {
    final session = await loadSession(sessionId);
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.schema('praticase').from('user_case_progress').upsert({
      'user_id': user.id,
      'case_id': session.caseId,
      'status': step == 'completed' ? 'completed' : 'in_progress',
      'progress_percent': _progressPercent(step),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,case_id');
  }

  int _progressPercent(String step) {
    return switch (step) {
      'physical_exam' => 40,
      'tests' => 60,
      'diagnosis' => 75,
      'management' => 90,
      'completed' => 100,
      _ => 20,
    };
  }

  String _functionMessage(Object? data) {
    if (data is Map) {
      final error = data['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
    }
    return 'Canlı işlem tamamlanamadı. Lütfen tekrar deneyin.';
  }

  OsceCaseSummary _summary(Map<String, dynamic> row) {
    return OsceCaseSummary(
      id: _string(row, 'case_id'),
      title: _string(row, 'title'),
      branch: _string(row, 'branch'),
      setting: _string(row, 'setting'),
      difficulty: OsceDifficulty.fromDatabase(_string(row, 'difficulty')),
      durationMinutes: _int(row, 'duration_minutes'),
      points: _int(row, 'points'),
      solvedCount: _int(row, 'solved_count'),
      summary: _string(row, 'summary'),
      iconKey: _nullableString(row, 'icon_key'),
      isBookmarked: row['is_bookmarked'] == true,
      progressPercent: _nullableInt(row, 'progress_percent'),
      lastScore: _nullableInt(row, 'last_score'),
    );
  }

  PatientProfile _patient(Object? value) {
    final row = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return PatientProfile(
      name: _string(row, 'name'),
      age: _string(row, 'age'),
      gender: _string(row, 'gender'),
      mainComplaint: _string(row, 'mainComplaint'),
      openingLine: _string(row, 'openingLine'),
      applicationSetting: _string(row, 'applicationSetting'),
      complaintDuration: _string(row, 'complaintDuration'),
    );
  }

  List<CaseFlowStep> _flowSteps(Object? value) {
    final rows = value is List ? value : const [];
    return [
      for (final item in rows)
        if (item is Map<String, dynamic>)
          CaseFlowStep(
            title: _string(item, 'title'),
            iconKey: _string(item, 'iconKey'),
          ),
    ];
  }

  List<CaseGoal> _goals(Object? value) {
    final rows = value is List ? value : const [];
    return [
      for (final item in rows)
        if (item is Map<String, dynamic>)
          CaseGoal(title: _string(item, 'title'), points: _int(item, 'points')),
    ];
  }

  ChatMessage _messageRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: _string(row, 'id'),
      sender: _string(row, 'sender'),
      message: _string(row, 'message'),
      createdAt:
          DateTime.tryParse(_string(row, 'created_at')) ?? DateTime.now(),
    );
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          if (item != null) item.toString(),
      ];
    }
    return const [];
  }

  List<ResultCategoryScore> _categoryScores(Object? value) {
    final rows = value is List ? value : const [];
    return [
      for (final item in rows)
        if (item is Map<String, dynamic>)
          ResultCategoryScore(
            title: _string(item, 'title'),
            score: _int(item, 'score'),
            maxScore: _int(item, 'maxScore'),
          ),
    ];
  }

  List<LabParameter> _labParameters(Object? value) {
    final rows = value is List ? value : const [];
    return [
      for (final item in rows)
        if (item is Map<String, dynamic>)
          LabParameter(
            name: _string(item, 'name'),
            value: _string(item, 'value'),
            referenceRange: _string(item, 'referenceRange'),
            status: _string(item, 'status'),
          ),
    ];
  }

  List<CaseProgressStep> _progressSteps(Object? value) {
    final rows = value is List ? value : const [];
    return [
      for (final item in rows)
        if (item is Map<String, dynamic>)
          CaseProgressStep(
            title: _string(item, 'title'),
            step: _string(item, 'step'),
            status: _string(item, 'status'),
          ),
    ];
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  String? _nullableString(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    return value.isEmpty ? null : value;
  }

  int _int(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _nullableInt(Map<String, dynamic> row, String key) {
    if (row[key] == null) return null;
    return _int(row, key);
  }

  String _message(PostgrestException error) {
    if (error.code == '42P01' || error.message.contains('schema')) {
      return 'Vaka verisi şu anda hazırlanıyor. Lütfen daha sonra tekrar deneyin.';
    }
    return 'Canlı vaka verisi alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
  }
}
