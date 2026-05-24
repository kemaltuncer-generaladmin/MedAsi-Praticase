class BadgeCard {
  const BadgeCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.tier,
    required this.progressCount,
    required this.targetCount,
    required this.earned,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? iconKey;
  final String tier;
  final int progressCount;
  final int targetCount;
  final bool earned;
}

class ExamModeItem {
  const ExamModeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.actionKey,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final String actionKey;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.totalPoints,
    required this.solvedCaseCount,
    required this.correctDiagnosisRate,
    required this.isCurrentUser,
  });

  final int rank;
  final String userId;
  final String displayName;
  final int totalPoints;
  final int solvedCaseCount;
  final int correctDiagnosisRate;
  final bool isCurrentUser;
}

class ProfileCard {
  const ProfileCard({
    required this.displayName,
    required this.email,
    required this.classLevel,
    required this.target,
    required this.totalPoints,
    required this.solvedCaseCount,
    required this.correctDiagnosisRate,
    required this.dailyStreak,
    required this.successRatePercent,
    required this.settings,
    this.dailyGoal = 1,
    this.osceExamDate,
    this.targetBranches = const [],
  });

  final String displayName;
  final String email;
  final String classLevel;
  final String target;
  final int totalPoints;
  final int solvedCaseCount;
  final int correctDiagnosisRate;
  final int dailyStreak;
  final int successRatePercent;
  final AppSettings settings;
  final int dailyGoal;
  final DateTime? osceExamDate;
  final List<String> targetBranches;
}

class ClinicalProgressSummary {
  const ClinicalProgressSummary({
    required this.sessionCount,
    required this.categoryScores,
    this.recentResults = const [],
    this.feedback = const [],
  });

  final int sessionCount;
  final List<ClinicalSkillScore> categoryScores;
  final List<ProgressResultInsight> recentResults;
  final List<ProgressFeedbackInsight> feedback;

  int percentFor(String category) {
    for (final score in categoryScores) {
      if (score.category == category) return score.percent;
    }
    return 0;
  }
}

class ProgressResultInsight {
  const ProgressResultInsight({
    required this.caseTitle,
    required this.branch,
    required this.score,
    required this.endedAt,
  });

  final String caseTitle;
  final String branch;
  final int score;
  final DateTime? endedAt;
}

class ProgressFeedbackInsight {
  const ProgressFeedbackInsight({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class ClinicalSkillScore {
  const ClinicalSkillScore({
    required this.category,
    required this.label,
    required this.score,
    required this.maxScore,
  });

  final String category;
  final String label;
  final int score;
  final int maxScore;

  int get percent => maxScore <= 0
      ? 0
      : ((score / maxScore) * 100).round().clamp(0, 100).toInt();
}

class AppSettings {
  const AppSettings({
    required this.displayMode,
    required this.language,
    required this.textSize,
    required this.soundAndHaptics,
    required this.dataUsage,
    required this.offlineMode,
    required this.caseDownloadsEnabled,
  });

  final String displayMode;
  final String language;
  final String textSize;
  final bool soundAndHaptics;
  final String dataUsage;
  final bool offlineMode;
  final bool caseDownloadsEnabled;
}

class NotificationCard {
  const NotificationCard({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
}

class SimpleContentItem {
  const SimpleContentItem({
    required this.id,
    required this.title,
    this.body = '',
    this.trailing = '',
  });

  final String id;
  final String title;
  final String body;
  final String trailing;
}

class CaseCollectionItem {
  const CaseCollectionItem({
    required this.caseId,
    required this.title,
    required this.branch,
    required this.difficulty,
    required this.points,
    required this.iconKey,
    this.progressPercent,
    this.score,
    this.updatedAt,
  });

  final String caseId;
  final String title;
  final String branch;
  final String difficulty;
  final int points;
  final String? iconKey;
  final int? progressPercent;
  final int? score;
  final DateTime? updatedAt;
}

class UserNote {
  const UserNote({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.caseTitle,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String? caseTitle;
  final DateTime updatedAt;
}

class StoreCatalog {
  const StoreCatalog({
    required this.products,
    required this.walletBalance,
    required this.questionQuota,
    required this.aiQuota,
    this.warnings = const [],
  });

  final List<StoreProduct> products;
  final double walletBalance;
  final int questionQuota;
  final int aiQuota;
  final List<String> warnings;
}

class StoreProduct {
  const StoreProduct({
    required this.code,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.questionAmount,
    required this.coinAmount,
    required this.appStoreProductId,
    required this.isFeatured,
    this.interval = '',
  });

  final String code;
  final String name;
  final String description;
  final int priceCents;
  final String currency;
  final int questionAmount;
  final double coinAmount;
  final String appStoreProductId;
  final bool isFeatured;
  final String interval;
}
