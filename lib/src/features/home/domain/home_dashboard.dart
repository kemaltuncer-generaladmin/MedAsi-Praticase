import 'recall_summary.dart';

enum CaseDifficulty {
  easy('Kolay'),
  medium('Orta'),
  hard('Zor');

  const CaseDifficulty(this.label);

  final String label;

  static CaseDifficulty fromDatabase(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'kolay' || normalized == 'easy') {
      return CaseDifficulty.easy;
    }
    if (normalized == 'zor' || normalized == 'hard') {
      return CaseDifficulty.hard;
    }
    return CaseDifficulty.medium;
  }
}

class HomeDashboard {
  const HomeDashboard({
    required this.user,
    required this.banners,
    required this.stats,
    required this.recommendedCases,
    required this.unreadNotificationCount,
    this.continuedCase,
    this.badgeSummary,
    this.recallSummary,
  });

  final HomeUser user;
  final List<HomeBanner> banners;
  final DashboardStats? stats;
  final ContinuedCase? continuedCase;
  final List<RecommendedCase> recommendedCases;
  final BadgeSummary? badgeSummary;
  final RecallSummary? recallSummary;
  final int unreadNotificationCount;
}

class HomeUser {
  const HomeUser({required this.id, required this.email, this.fullName});

  final String id;
  final String email;
  final String? fullName;

  String get firstName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.split(RegExp(r'\s+')).first;
    }
    final localPart = email.split('@').first.trim();
    final inferred = localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .firstOrNull;
    if (inferred != null) {
      return '${inferred[0].toUpperCase()}${inferred.substring(1)}';
    }
    return 'Öğrenci';
  }

  String get initials {
    final source = (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : 'PratiCase';
    final parts = source
        .split(RegExp(r'[\s._-]+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    final letters = parts
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first));
    return letters.join().toUpperCase();
  }
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.ctaRoute,
    this.imageUrl,
    this.imageAltText = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String? ctaRoute;
  final String? imageUrl;
  final String imageAltText;
}

class DashboardStats {
  const DashboardStats({
    required this.solvedCaseCount,
    required this.successRatePercent,
    required this.totalPoints,
    required this.dailyStreak,
    required this.solvedDeltaPercent,
    required this.successDeltaPercent,
    required this.pointsDeltaPercent,
    required this.streakLabel,
  });

  final int solvedCaseCount;
  final int successRatePercent;
  final int totalPoints;
  final int dailyStreak;
  final int solvedDeltaPercent;
  final int successDeltaPercent;
  final int pointsDeltaPercent;
  final String? streakLabel;
}

class ContinuedCase {
  const ContinuedCase({
    required this.caseId,
    required this.title,
    required this.branch,
    required this.difficulty,
    required this.progressPercent,
  });

  final String caseId;
  final String title;
  final String branch;
  final CaseDifficulty difficulty;
  final int progressPercent;
}

class RecommendedCase {
  const RecommendedCase({
    required this.caseId,
    required this.title,
    required this.branch,
    required this.difficulty,
    required this.points,
    required this.iconKey,
    required this.isBookmarked,
    this.reason = '',
  });

  final String caseId;
  final String title;
  final String branch;
  final CaseDifficulty difficulty;
  final int points;
  final String? iconKey;
  final bool isBookmarked;
  final String reason;
}

class BadgeSummary {
  const BadgeSummary({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
}
