enum OsceDifficulty {
  easy('Kolay'),
  medium('Orta'),
  hard('Zor');

  const OsceDifficulty(this.label);

  final String label;

  static OsceDifficulty fromDatabase(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'kolay' || normalized == 'easy') return easy;
    if (normalized == 'zor' || normalized == 'hard') return hard;
    return medium;
  }
}

class OsceCaseSummary {
  const OsceCaseSummary({
    required this.id,
    required this.title,
    required this.branch,
    required this.setting,
    required this.difficulty,
    required this.durationMinutes,
    required this.points,
    required this.solvedCount,
    required this.summary,
    required this.iconKey,
    required this.isBookmarked,
    this.progressPercent,
    this.lastScore,
  });

  final String id;
  final String title;
  final String branch;
  final String setting;
  final OsceDifficulty difficulty;
  final int durationMinutes;
  final int points;
  final int solvedCount;
  final String summary;
  final String? iconKey;
  final bool isBookmarked;
  final int? progressPercent;
  final int? lastScore;
}

class OsceCaseDetail {
  const OsceCaseDetail({
    required this.summary,
    required this.candidatePrompt,
    required this.patient,
    required this.flowSteps,
    required this.goals,
  });

  final OsceCaseSummary summary;
  final String candidatePrompt;
  final PatientProfile patient;
  final List<CaseFlowStep> flowSteps;
  final List<CaseGoal> goals;
}

class PatientProfile {
  const PatientProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.mainComplaint,
    required this.openingLine,
    required this.applicationSetting,
    required this.complaintDuration,
  });

  final String name;
  final String age;
  final String gender;
  final String mainComplaint;
  final String openingLine;
  final String applicationSetting;
  final String complaintDuration;
}

class CaseFlowStep {
  const CaseFlowStep({required this.title, required this.iconKey});

  final String title;
  final String iconKey;
}

class CaseGoal {
  const CaseGoal({required this.title, required this.points});

  final String title;
  final int points;
}

class ExamSessionOverview {
  const ExamSessionOverview({
    required this.id,
    required this.caseId,
    required this.caseTitle,
    required this.patient,
    required this.currentStep,
    required this.remainingPoints,
    required this.budgetPoints,
    required this.durationMinutes,
    required this.startedAt,
  });

  final String id;
  final String caseId;
  final String caseTitle;
  final PatientProfile patient;
  final String currentStep;
  final int remainingPoints;
  final int budgetPoints;
  final int durationMinutes;
  final DateTime startedAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String sender;
  final String message;
  final DateTime createdAt;

  bool get fromCandidate => sender == 'candidate';
}

class PhysicalExamGroup {
  const PhysicalExamGroup({required this.id, required this.title});

  final String id;
  final String title;
}

class PhysicalExamOption {
  const PhysicalExamOption({
    required this.id,
    required this.groupId,
    required this.title,
    required this.finding,
    required this.pointValue,
    required this.isSelected,
  });

  final String id;
  final String groupId;
  final String title;
  final String finding;
  final int pointValue;
  final bool isSelected;
}

class TestGroup {
  const TestGroup({required this.id, required this.title});

  final String id;
  final String title;
}

class TestOption {
  const TestOption({
    required this.id,
    required this.groupId,
    required this.title,
    required this.result,
    required this.pointCost,
    required this.isSelected,
  });

  final String id;
  final String groupId;
  final String title;
  final String result;
  final int pointCost;
  final bool isSelected;
}

class DiagnosisOption {
  const DiagnosisOption({
    required this.id,
    required this.title,
    required this.isSelected,
  });

  final String id;
  final String title;
  final bool isSelected;
}

class DiagnosisAnswer {
  const DiagnosisAnswer({
    required this.primaryDiagnosis,
    required this.reasoning,
    required this.selectedOptionIds,
  });

  final String primaryDiagnosis;
  final String reasoning;
  final List<String> selectedOptionIds;
}

class ManagementOption {
  const ManagementOption({
    required this.id,
    required this.category,
    required this.title,
    required this.pointValue,
    required this.isSelected,
  });

  final String id;
  final String category;
  final String title;
  final int pointValue;
  final bool isSelected;
}

class ManagementPlanAnswer {
  const ManagementPlanAnswer({
    required this.diagnosis,
    required this.note,
    required this.selectedOptionIds,
    this.consultationDestination = '',
  });

  final String diagnosis;
  final String note;
  final List<String> selectedOptionIds;
  final String consultationDestination;
}

class ResultCategoryScore {
  const ResultCategoryScore({
    required this.title,
    required this.score,
    required this.maxScore,
  });

  final String title;
  final int score;
  final int maxScore;
}

class ExamResultSummary {
  const ExamResultSummary({
    required this.sessionId,
    required this.caseTitle,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.categoryScores,
    required this.strongPoints,
    required this.improvementPoints,
    required this.criticalMistakes,
    required this.unnecessaryTests,
    required this.missedHistory,
    required this.missedPhysicalExam,
    required this.idealApproach,
  });

  final String sessionId;
  final String caseTitle;
  final int totalScore;
  final int maxScore;
  final int percentage;
  final List<ResultCategoryScore> categoryScores;
  final List<String> strongPoints;
  final List<String> improvementPoints;
  final List<String> criticalMistakes;
  final List<String> unnecessaryTests;
  final List<String> missedHistory;
  final List<String> missedPhysicalExam;
  final String idealApproach;
}

class LabResultDetail {
  const LabResultDetail({
    required this.title,
    required this.measuredAt,
    required this.parameters,
    required this.interpretation,
  });

  final String title;
  final DateTime? measuredAt;
  final List<LabParameter> parameters;
  final String interpretation;
}

class LabParameter {
  const LabParameter({
    required this.name,
    required this.value,
    required this.referenceRange,
    required this.status,
  });

  final String name;
  final String value;
  final String referenceRange;
  final String status;
}

class ImagingResultDetail {
  const ImagingResultDetail({
    required this.title,
    required this.imageUrl,
    required this.report,
    required this.conclusion,
  });

  final String title;
  final String imageUrl;
  final String report;
  final String conclusion;
}

class MedicationInfo {
  const MedicationInfo({
    required this.name,
    required this.dosage,
    required this.route,
    required this.indication,
    required this.sideEffects,
    required this.contraindications,
    required this.sourceUrl,
  });

  final String name;
  final String dosage;
  final String route;
  final String indication;
  final String sideEffects;
  final String contraindications;
  final String sourceUrl;
}

class CaseProgressStep {
  const CaseProgressStep({
    required this.title,
    required this.step,
    required this.status,
  });

  final String title;
  final String step;
  final String status;
}

class CaseProgressOverview {
  const CaseProgressOverview({
    required this.sessionId,
    required this.caseTitle,
    required this.currentStep,
    required this.steps,
  });

  final String sessionId;
  final String caseTitle;
  final String currentStep;
  final List<CaseProgressStep> steps;
}
