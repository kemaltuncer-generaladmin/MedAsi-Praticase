// Sözlü sınav modeli — Türk tıp fakültesi sözlü sınav dinamiğine uygundur.

enum OralExamFormat {
  solo,
  panel;

  String get apiValue => this == OralExamFormat.panel ? 'panel' : 'solo';
  bool get isPanel => this == OralExamFormat.panel;

  static OralExamFormat fromApi(String? value) =>
      value == 'panel' ? OralExamFormat.panel : OralExamFormat.solo;
}

class OralExamPersona {
  const OralExamPersona({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.description,
    required this.patienceLevel,
    required this.sortOrder,
    required this.panelRole,
  });

  final String id;
  final String title;
  final String difficulty;
  final String description;
  final int patienceLevel;
  final int sortOrder;
  final String panelRole;
}

class OralExamBranch {
  const OralExamBranch({
    required this.id,
    required this.title,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String description;
  final int sortOrder;
}

class OralExamScenario {
  const OralExamScenario({
    required this.id,
    required this.branchId,
    required this.title,
    required this.caseBrief,
    required this.difficultyFloor,
    required this.sortOrder,
  });

  final String id;
  final String branchId;
  final String title;
  final String caseBrief;
  final String difficultyFloor;
  final int sortOrder;
}

class OralExamCatalog {
  const OralExamCatalog({
    required this.personas,
    required this.branches,
    required this.scenariosByBranch,
  });

  final List<OralExamPersona> personas;
  final List<OralExamBranch> branches;
  final Map<String, List<OralExamScenario>> scenariosByBranch;

  List<OralExamScenario> scenariosFor(String branchId) {
    return scenariosByBranch[branchId] ?? const <OralExamScenario>[];
  }
}

class OralExamSession {
  const OralExamSession({
    required this.id,
    required this.durationSeconds,
    required this.caseBrief,
    required this.startedAt,
    required this.personaId,
    required this.personaTitle,
    required this.difficulty,
    required this.branchId,
    required this.branchTitle,
    required this.openingMessage,
    required this.format,
    required this.panel,
    required this.activePersonaId,
  });

  final String id;
  final int durationSeconds;
  final String caseBrief;
  final DateTime startedAt;
  final String personaId;
  final String personaTitle;
  final String difficulty;
  final String branchId;
  final String branchTitle;
  final String openingMessage;
  final OralExamFormat format;
  final List<OralExamPersona> panel;
  final String activePersonaId;

  OralExamPersona? personaById(String id) {
    for (final p in panel) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class OralExamTurnResult {
  const OralExamTurnResult({
    required this.mentorMessage,
    required this.mentorMessages,
    required this.isFollowup,
    required this.shouldEnd,
    required this.remainingSeconds,
    required this.scoreDelta,
    required this.reasoningNote,
    required this.isCorrect,
    required this.activePersonaId,
    required this.activePersonaTitle,
  });

  final String mentorMessage;
  final List<OralExamMessage> mentorMessages;
  final bool isFollowup;
  final bool shouldEnd;
  final int remainingSeconds;
  final int scoreDelta;
  final String reasoningNote;
  final bool isCorrect;
  final String activePersonaId;
  final String activePersonaTitle;
}

class OralExamPanelVerdict {
  const OralExamPanelVerdict({
    required this.personaId,
    required this.verdict,
    required this.note,
  });

  final String personaId;
  final String verdict;
  final String note;
}

class OralExamResult {
  const OralExamResult({
    required this.sessionId,
    required this.totalScore,
    required this.maxScore,
    required this.reasoningScore,
    required this.knowledgeScore,
    required this.communicationScore,
    required this.paceScore,
    required this.professionalismScore,
    required this.mentorSummary,
    required this.strongPoints,
    required this.improvementPoints,
    required this.missedPoints,
    required this.caseBrief,
    required this.format,
    required this.panelVerdicts,
  });

  final String sessionId;
  final int totalScore;
  final int maxScore;
  final int reasoningScore;
  final int knowledgeScore;
  final int communicationScore;
  final int paceScore;
  final int professionalismScore;
  final String mentorSummary;
  final List<String> strongPoints;
  final List<String> improvementPoints;
  final List<String> missedPoints;
  final String caseBrief;
  final OralExamFormat format;
  final List<OralExamPanelVerdict> panelVerdicts;

  int get percentage =>
      maxScore == 0 ? 0 : ((totalScore / maxScore) * 100).round().clamp(0, 100);
}

class OralExamMessage {
  const OralExamMessage({
    required this.speaker,
    required this.message,
    this.isFollowup = false,
    this.wasSkipped = false,
    this.personaId = '',
    this.personaTitle = '',
  });

  final String speaker;
  final String message;
  final bool isFollowup;
  final bool wasSkipped;
  final String personaId;
  final String personaTitle;

  bool get fromMentor => speaker == 'mentor';
}

class OralExamUnavailable implements Exception {
  const OralExamUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}
