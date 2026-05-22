import '../../features/cases/data/cases_repository.dart';
import '../../features/cases/domain/osce_case.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/domain/home_dashboard.dart';
import '../../features/progress/data/progress_repository.dart';
import '../../features/progress/domain/progress_models.dart';

const _repositoryTimeout = Duration(seconds: 25);

extension _TimeoutFuture<T> on Future<T> {
  Future<T> withRepositoryTimeout() => timeout(_repositoryTimeout);
}

class TimeoutHomeRepository implements HomeRepository {
  const TimeoutHomeRepository(this._delegate);

  final HomeRepository _delegate;

  @override
  Future<HomeDashboard> loadDashboard() =>
      _delegate.loadDashboard().withRepositoryTimeout();
}

class TimeoutCasesRepository implements CasesRepository {
  const TimeoutCasesRepository(this._delegate);

  final CasesRepository _delegate;

  @override
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  }) => _delegate
      .loadCases(query: query, difficulty: difficulty)
      .withRepositoryTimeout();

  @override
  Future<OsceCaseDetail> loadCaseDetail(String caseId) =>
      _delegate.loadCaseDetail(caseId).withRepositoryTimeout();

  @override
  Future<void> setBookmark({
    required String caseId,
    required bool bookmarked,
  }) => _delegate
      .setBookmark(caseId: caseId, bookmarked: bookmarked)
      .withRepositoryTimeout();

  @override
  Future<ExamSessionOverview> startSession(String caseId) =>
      _delegate.startSession(caseId).withRepositoryTimeout();

  @override
  Future<ExamSessionOverview> loadSession(String sessionId) =>
      _delegate.loadSession(sessionId).withRepositoryTimeout();

  @override
  Future<List<ChatMessage>> loadMessages(String sessionId) =>
      _delegate.loadMessages(sessionId).withRepositoryTimeout();

  @override
  Future<void> sendPatientQuestion({
    required String sessionId,
    required String message,
  }) => _delegate
      .sendPatientQuestion(sessionId: sessionId, message: message)
      .withRepositoryTimeout();

  @override
  Future<List<PhysicalExamGroup>> loadPhysicalExamGroups(String caseId) =>
      _delegate.loadPhysicalExamGroups(caseId).withRepositoryTimeout();

  @override
  Future<List<PhysicalExamOption>> loadPhysicalExamOptions({
    required String sessionId,
    required String caseId,
  }) => _delegate
      .loadPhysicalExamOptions(sessionId: sessionId, caseId: caseId)
      .withRepositoryTimeout();

  @override
  Future<void> selectPhysicalExam({
    required String sessionId,
    required String optionId,
  }) => _delegate
      .selectPhysicalExam(sessionId: sessionId, optionId: optionId)
      .withRepositoryTimeout();

  @override
  Future<List<TestGroup>> loadTestGroups(String caseId) =>
      _delegate.loadTestGroups(caseId).withRepositoryTimeout();

  @override
  Future<List<TestOption>> loadTestOptions({
    required String sessionId,
    required String caseId,
  }) => _delegate
      .loadTestOptions(sessionId: sessionId, caseId: caseId)
      .withRepositoryTimeout();

  @override
  Future<void> requestTest({
    required String sessionId,
    required String optionId,
  }) => _delegate
      .requestTest(sessionId: sessionId, optionId: optionId)
      .withRepositoryTimeout();

  @override
  Future<List<DiagnosisOption>> loadDiagnosisOptions({
    required String sessionId,
    required String caseId,
  }) => _delegate
      .loadDiagnosisOptions(sessionId: sessionId, caseId: caseId)
      .withRepositoryTimeout();

  @override
  Future<DiagnosisAnswer?> loadDiagnosisAnswer(String sessionId) =>
      _delegate.loadDiagnosisAnswer(sessionId).withRepositoryTimeout();

  @override
  Future<void> saveDiagnosisAnswer({
    required String sessionId,
    required String primaryDiagnosis,
    required List<String> selectedOptionIds,
    required String reasoning,
  }) => _delegate
      .saveDiagnosisAnswer(
        sessionId: sessionId,
        primaryDiagnosis: primaryDiagnosis,
        selectedOptionIds: selectedOptionIds,
        reasoning: reasoning,
      )
      .withRepositoryTimeout();

  @override
  Future<List<ManagementOption>> loadManagementOptions({
    required String sessionId,
    required String caseId,
  }) => _delegate
      .loadManagementOptions(sessionId: sessionId, caseId: caseId)
      .withRepositoryTimeout();

  @override
  Future<ManagementPlanAnswer?> loadManagementPlan(String sessionId) =>
      _delegate.loadManagementPlan(sessionId).withRepositoryTimeout();

  @override
  Future<void> saveManagementPlan({
    required String sessionId,
    required String diagnosis,
    required List<String> selectedOptionIds,
    required String note,
  }) => _delegate
      .saveManagementPlan(
        sessionId: sessionId,
        diagnosis: diagnosis,
        selectedOptionIds: selectedOptionIds,
        note: note,
      )
      .withRepositoryTimeout();

  @override
  Future<ExamResultSummary> loadResult(String sessionId) =>
      _delegate.loadResult(sessionId).withRepositoryTimeout();

  @override
  Future<LabResultDetail?> loadLabResult(String testOptionId) =>
      _delegate.loadLabResult(testOptionId).withRepositoryTimeout();

  @override
  Future<ImagingResultDetail?> loadImagingResult(String testOptionId) =>
      _delegate.loadImagingResult(testOptionId).withRepositoryTimeout();

  @override
  Future<List<MedicationInfo>> loadMedicationInfos(String caseId) =>
      _delegate.loadMedicationInfos(caseId).withRepositoryTimeout();

  @override
  Future<void> saveNote({
    required String body,
    String? caseId,
    String title = '',
    String category = '',
  }) => _delegate
      .saveNote(body: body, caseId: caseId, title: title, category: category)
      .withRepositoryTimeout();

  @override
  Future<CaseProgressOverview> loadCaseProgress(String sessionId) =>
      _delegate.loadCaseProgress(sessionId).withRepositoryTimeout();

  @override
  Future<void> advanceSession({
    required String sessionId,
    required String step,
  }) => _delegate
      .advanceSession(sessionId: sessionId, step: step)
      .withRepositoryTimeout();
}

class TimeoutProgressRepository implements ProgressRepository {
  const TimeoutProgressRepository(this._delegate);

  final ProgressRepository _delegate;

  @override
  Future<List<BadgeCard>> loadBadges() =>
      _delegate.loadBadges().withRepositoryTimeout();

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard() =>
      _delegate.loadLeaderboard().withRepositoryTimeout();

  @override
  Future<ProfileCard> loadProfile() =>
      _delegate.loadProfile().withRepositoryTimeout();

  @override
  Future<List<NotificationCard>> loadNotifications() =>
      _delegate.loadNotifications().withRepositoryTimeout();

  @override
  Future<void> markNotificationRead(String notificationId) =>
      _delegate.markNotificationRead(notificationId).withRepositoryTimeout();

  @override
  Future<List<SimpleContentItem>> loadSupportTopics() =>
      _delegate.loadSupportTopics().withRepositoryTimeout();

  @override
  Future<List<SimpleContentItem>> loadFaqItems() =>
      _delegate.loadFaqItems().withRepositoryTimeout();

  @override
  Future<List<SimpleContentItem>> loadAnnouncements() =>
      _delegate.loadAnnouncements().withRepositoryTimeout();

  @override
  Future<List<SimpleContentItem>> loadUserDataOverview() =>
      _delegate.loadUserDataOverview().withRepositoryTimeout();

  @override
  Future<List<CaseCollectionItem>> loadFavoriteCases() =>
      _delegate.loadFavoriteCases().withRepositoryTimeout();

  @override
  Future<List<CaseCollectionItem>> loadCaseHistory() =>
      _delegate.loadCaseHistory().withRepositoryTimeout();

  @override
  Future<List<UserNote>> loadNotes() =>
      _delegate.loadNotes().withRepositoryTimeout();

  @override
  Future<String> exportUserData() =>
      _delegate.exportUserData().withRepositoryTimeout();

  @override
  Future<void> createContactRequest({
    required String subject,
    required String email,
    required String message,
  }) => _delegate
      .createContactRequest(subject: subject, email: email, message: message)
      .withRepositoryTimeout();

  @override
  Future<void> saveProfile({
    required String displayName,
    required String email,
    required String specialty,
    required String educationLevel,
  }) => _delegate
      .saveProfile(
        displayName: displayName,
        email: email,
        specialty: specialty,
        educationLevel: educationLevel,
      )
      .withRepositoryTimeout();

  @override
  Future<void> saveAppSettings(AppSettings settings) =>
      _delegate.saveAppSettings(settings).withRepositoryTimeout();
}
