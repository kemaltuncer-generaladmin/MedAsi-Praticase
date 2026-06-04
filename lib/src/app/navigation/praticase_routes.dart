import 'package:flutter/material.dart';

import '../../features/cases/data/cases_repository.dart';
import '../../features/cases/presentation/cases_screen.dart';
import '../../features/oral_exam/data/oral_exam_repository.dart';
import '../../features/oral_exam/presentation/oral_exam_screens.dart';
import '../../features/progress/data/progress_repository.dart';
import '../../features/progress/presentation/progress_screens.dart';
import '../../features/theoretical_exam/data/theoretical_exam_repository.dart';
import '../../features/theoretical_exam/presentation/theoretical_exam_screen.dart';

abstract final class PratiCaseRoutes {
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute<T>(builder: (_) => screen));
  }

  static Future<void> openCaseDetail(
    BuildContext context, {
    required CasesRepository repository,
    required String caseId,
  }) {
    return push<void>(
      context,
      CaseDetailScreen(repository: repository, caseId: caseId),
    );
  }

  static Future<void> openCases(
    BuildContext context, {
    required CasesRepository repository,
    required CasesScreenMode mode,
    required int unreadNotificationCount,
    VoidCallback? onOpenNotifications,
    VoidCallback? onOpenProfile,
    VoidCallback? onOpenHome,
  }) {
    return push<void>(
      context,
      CasesScreen(
        repository: repository,
        mode: mode,
        unreadNotificationCount: unreadNotificationCount,
        onOpenNotifications: onOpenNotifications,
        onOpenProfile: onOpenProfile,
        onOpenHome: onOpenHome,
      ),
    );
  }

  static Future<void> openTheoreticalExam(
    BuildContext context, {
    required TheoreticalExamRepository repository,
  }) {
    return push<void>(
      context,
      TheoreticalExamSetupScreen(repository: repository),
    );
  }

  static Future<void> openOralExam(
    BuildContext context, {
    required OralExamRepository repository,
  }) {
    return push<void>(context, OralExamSetupScreen(repository: repository));
  }

  static Future<void> openWeakAreaAnalysis(
    BuildContext context, {
    required ProgressRepository repository,
  }) {
    return push<void>(context, WeakAreaAnalysisScreen(repository: repository));
  }

  static Future<void> openBadges(
    BuildContext context, {
    required ProgressRepository repository,
  }) {
    return push<void>(context, BadgesScreen(repository: repository));
  }

  static Future<void> openNotifications(
    BuildContext context, {
    required ProgressRepository repository,
    required Future<void> Function() onChanged,
  }) {
    return push<void>(
      context,
      NotificationsScreen(repository: repository, onChanged: onChanged),
    );
  }

  static Future<void> openCaseHistory(
    BuildContext context, {
    required ProgressRepository repository,
  }) {
    return push<void>(context, CaseHistoryScreen(repository: repository));
  }

  static Future<void> openLeaderboard(
    BuildContext context, {
    required ProgressRepository repository,
  }) {
    return push<void>(context, LeaderboardScreen(repository: repository));
  }
}
