import '../domain/progress_models.dart';

abstract interface class ProgressRepository {
  Future<List<ExamModeItem>> loadExamModes();

  Future<List<BadgeCard>> loadBadges();

  Future<List<LeaderboardEntry>> loadLeaderboard();

  Future<ProfileCard> loadProfile();

  Future<ClinicalProgressSummary> loadClinicalProgressSummary();

  Future<List<NotificationCard>> loadNotifications();

  Future<int> loadUnreadNotificationCount();

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead();

  Future<List<SimpleContentItem>> loadSupportTopics();

  Future<List<SimpleContentItem>> loadFaqItems();

  Future<List<SimpleContentItem>> loadAnnouncements();

  Future<List<SimpleContentItem>> loadUserDataOverview();

  Future<List<CaseCollectionItem>> loadFavoriteCases();

  Future<List<CaseCollectionItem>> loadCaseHistory();

  Future<List<UserNote>> loadNotes();

  Future<String> exportUserData();

  Future<void> createContactRequest({
    required String subject,
    required String email,
    required String message,
  });

  Future<void> saveProfile({
    required String displayName,
    required String email,
    required String specialty,
    required String educationLevel,
  });

  Future<void> saveAppSettings(AppSettings settings);
}

class ProgressDataUnavailable implements Exception {
  const ProgressDataUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
