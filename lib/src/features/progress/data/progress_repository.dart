import '../domain/progress_models.dart';

abstract interface class ProgressRepository {
  Future<List<BadgeCard>> loadBadges();

  Future<List<LeaderboardEntry>> loadLeaderboard();

  Future<ProfileCard> loadProfile();

  Future<List<NotificationCard>> loadNotifications();

  Future<List<SimpleContentItem>> loadSupportTopics();

  Future<List<SimpleContentItem>> loadFaqItems();

  Future<List<SimpleContentItem>> loadAnnouncements();

  Future<List<SimpleContentItem>> loadUserDataOverview();

  Future<List<CaseCollectionItem>> loadFavoriteCases();

  Future<List<CaseCollectionItem>> loadCaseHistory();

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
}

class ProgressDataUnavailable implements Exception {
  const ProgressDataUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
