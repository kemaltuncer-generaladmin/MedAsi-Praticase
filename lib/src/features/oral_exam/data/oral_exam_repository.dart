import '../domain/oral_exam_models.dart';

abstract interface class OralExamRepository {
  Future<OralExamCatalog> loadCatalog();

  Future<OralExamSession> startSession({
    required String personaId,
    required String branchId,
    required int durationSeconds,
  });

  Future<OralExamTurnResult> sendAnswer({
    required String sessionId,
    required String message,
  });

  Future<String> skipQuestion(String sessionId);

  Future<OralExamResult> finalizeSession(String sessionId);

  Future<List<OralExamMessage>> loadTranscript(String sessionId);
}
