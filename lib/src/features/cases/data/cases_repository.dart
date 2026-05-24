import '../domain/osce_case.dart';

abstract interface class CasesRepository {
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  });

  Future<OsceCaseDetail> loadCaseDetail(String caseId);

  Future<void> setBookmark({required String caseId, required bool bookmarked});

  Future<ExamSessionOverview> startSession(String caseId);

  Future<ExamSessionOverview> loadSession(String sessionId);

  Future<List<ChatMessage>> loadMessages(String sessionId);

  Future<void> sendPatientQuestion({
    required String sessionId,
    required String message,
  });

  Future<List<PhysicalExamGroup>> loadPhysicalExamGroups(String caseId);

  Future<List<PhysicalExamOption>> loadPhysicalExamOptions({
    required String sessionId,
    required String caseId,
  });

  Future<void> selectPhysicalExam({
    required String sessionId,
    required String optionId,
  });

  Future<List<TestGroup>> loadTestGroups(String caseId);

  Future<List<TestOption>> loadTestOptions({
    required String sessionId,
    required String caseId,
  });

  Future<void> requestTest({
    required String sessionId,
    required String optionId,
  });

  Future<List<DiagnosisOption>> loadDiagnosisOptions({
    required String sessionId,
    required String caseId,
  });

  Future<DiagnosisAnswer?> loadDiagnosisAnswer(String sessionId);

  Future<void> saveDiagnosisAnswer({
    required String sessionId,
    required String primaryDiagnosis,
    required List<String> selectedOptionIds,
    required String reasoning,
  });

  Future<List<ManagementOption>> loadManagementOptions({
    required String sessionId,
    required String caseId,
  });

  Future<ManagementPlanAnswer?> loadManagementPlan(String sessionId);

  Future<void> saveManagementPlan({
    required String sessionId,
    required String diagnosis,
    required List<String> selectedOptionIds,
    required String note,
    String consultationDestination = '',
  });

  Future<ExamResultSummary> loadResult(String sessionId);

  Future<LabResultDetail?> loadLabResult(String testOptionId);

  Future<ImagingResultDetail?> loadImagingResult(String testOptionId);

  Future<List<MedicationInfo>> loadMedicationInfos(String caseId);

  Future<void> saveNote({
    required String body,
    String? caseId,
    String title,
    String category,
  });

  Future<CaseProgressOverview> loadCaseProgress(String sessionId);

  Future<void> advanceSession({
    required String sessionId,
    required String step,
  });
}

class CasesDataUnavailable implements Exception {
  const CasesDataUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
