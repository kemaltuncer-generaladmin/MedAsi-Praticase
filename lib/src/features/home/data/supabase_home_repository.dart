import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/home_dashboard.dart';
import 'home_repository.dart';

class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<HomeDashboard> loadDashboard() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const HomeDataUnavailable('Oturum bulunamadı.');
    }

    try {
      final profileFuture = _client
          .from('profiles')
          .select('first_name,last_name,email')
          .eq('id', authUser.id)
          .maybeSingle();
      final bannersFuture = _client
          .schema('praticase')
          .from('home_banners')
          .select('id,title,subtitle,cta_label')
          .eq('is_active', true)
          .order('sort_order')
          .limit(5);
      final statsFuture = _client
          .schema('praticase')
          .from('user_dashboard_stats')
          .select(
            'solved_case_count,success_rate_percent,total_points,daily_streak,'
            'solved_delta_percent,success_delta_percent,points_delta_percent,'
            'streak_label',
          )
          .eq('user_id', authUser.id)
          .maybeSingle();
      final continuedFuture = _client
          .schema('praticase')
          .from('user_home_case_progress')
          .select('case_id,title,branch,difficulty,progress_percent,updated_at')
          .eq('user_id', authUser.id)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final recommendationsFuture = _client
          .schema('praticase')
          .from('user_recommended_cases')
          .select(
            'case_id,title,branch,difficulty,points,icon_key,is_bookmarked,sort_order',
          )
          .eq('user_id', authUser.id)
          .order('sort_order')
          .limit(8);
      final badgeFuture = _client
          .schema('praticase')
          .from('user_badge_summary')
          .select('title,subtitle,action_label')
          .eq('user_id', authUser.id)
          .maybeSingle();
      final notificationsFuture = _client
          .schema('praticase')
          .from('user_notifications')
          .select('id')
          .eq('user_id', authUser.id)
          .eq('is_read', false)
          .count(CountOption.exact);

      final profile = await profileFuture;
      final banners = await bannersFuture;
      final stats = await statsFuture;
      final continued = await continuedFuture;
      final recommendations = await recommendationsFuture;
      final badge = await badgeFuture;
      final notifications = await notificationsFuture;

      return HomeDashboard(
        user: HomeUser(
          id: authUser.id,
          email: _readString(profile, 'email') ?? authUser.email ?? '',
          fullName: _fullName(profile, authUser),
        ),
        banners: [for (final row in banners) _bannerFromRow(row)],
        stats: stats == null ? null : _statsFromRow(stats),
        continuedCase: continued == null ? null : _continuedFromRow(continued),
        recommendedCases: [
          for (final row in recommendations) _recommendedFromRow(row),
        ],
        badgeSummary: badge == null ? null : _badgeFromRow(badge),
        unreadNotificationCount: notifications.count,
      );
    } on PostgrestException catch (error) {
      throw HomeDataUnavailable(_friendlyDatabaseMessage(error));
    }
  }

  String? _fullName(Map<String, dynamic>? profile, User user) {
    final firstName = _readString(profile, 'first_name');
    final lastName = _readString(profile, 'last_name');
    final parts = [?firstName, ?lastName];
    if (parts.isNotEmpty) return parts.join(' ');

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final fullName = metadata['full_name'];
    return fullName is String && fullName.trim().isNotEmpty
        ? fullName.trim()
        : null;
  }

  HomeBanner _bannerFromRow(Map<String, dynamic> row) {
    return HomeBanner(
      id: _readString(row, 'id') ?? '',
      title: _readString(row, 'title') ?? '',
      subtitle: _readString(row, 'subtitle') ?? '',
      ctaLabel: _readString(row, 'cta_label') ?? 'Başla',
    );
  }

  DashboardStats _statsFromRow(Map<String, dynamic> row) {
    return DashboardStats(
      solvedCaseCount: _readInt(row, 'solved_case_count'),
      successRatePercent: _readInt(row, 'success_rate_percent'),
      totalPoints: _readInt(row, 'total_points'),
      dailyStreak: _readInt(row, 'daily_streak'),
      solvedDeltaPercent: _readInt(row, 'solved_delta_percent'),
      successDeltaPercent: _readInt(row, 'success_delta_percent'),
      pointsDeltaPercent: _readInt(row, 'points_delta_percent'),
      streakLabel: _readString(row, 'streak_label'),
    );
  }

  ContinuedCase _continuedFromRow(Map<String, dynamic> row) {
    return ContinuedCase(
      caseId: _readString(row, 'case_id') ?? '',
      title: _readString(row, 'title') ?? '',
      branch: _readString(row, 'branch') ?? '',
      difficulty: CaseDifficulty.fromDatabase(_readString(row, 'difficulty')),
      progressPercent: _readInt(row, 'progress_percent'),
    );
  }

  RecommendedCase _recommendedFromRow(Map<String, dynamic> row) {
    return RecommendedCase(
      caseId: _readString(row, 'case_id') ?? '',
      title: _readString(row, 'title') ?? '',
      branch: _readString(row, 'branch') ?? '',
      difficulty: CaseDifficulty.fromDatabase(_readString(row, 'difficulty')),
      points: _readInt(row, 'points'),
      iconKey: _readString(row, 'icon_key'),
      isBookmarked: row['is_bookmarked'] == true,
    );
  }

  BadgeSummary _badgeFromRow(Map<String, dynamic> row) {
    return BadgeSummary(
      title: _readString(row, 'title') ?? '',
      subtitle: _readString(row, 'subtitle') ?? '',
      actionLabel: _readString(row, 'action_label') ?? 'Rozetlerim',
    );
  }

  String? _readString(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  int _readInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _friendlyDatabaseMessage(PostgrestException error) {
    if (error.code == '42P01' || error.message.contains('schema')) {
      return 'Ana ekran verisi şu anda hazırlanıyor. Lütfen daha sonra tekrar deneyin.';
    }
    return 'Ana ekran canlı verisi alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
  }
}
