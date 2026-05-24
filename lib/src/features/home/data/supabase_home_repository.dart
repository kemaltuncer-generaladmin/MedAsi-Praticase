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
      final profile = await _loadProfile(authUser.id);
      final banners = await _loadBanners();
      final stats = await _loadStats(authUser.id);
      final continued = await _loadContinuedCase(authUser.id);
      final recommendations = await _loadRecommendations(authUser.id);
      final badge = await _loadBadgeSummary(authUser.id);
      final unreadNotifications = await _loadUnreadNotificationCount(
        authUser.id,
      );

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
        unreadNotificationCount: unreadNotifications,
      );
    } on PostgrestException catch (error) {
      throw HomeDataUnavailable(_friendlyDatabaseMessage(error));
    }
  }

  Future<Map<String, dynamic>?> _loadProfile(String userId) {
    return _client
        .from('profiles')
        .select('first_name,last_name,email')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> _loadBanners() async {
    try {
      return await _client
          .schema('praticase')
          .from('home_banners')
          .select(
            'id,title,subtitle,cta_label,cta_route,image_url,image_storage_path,image_alt_text,deep_link',
          )
          .eq('is_active', true)
          .order('sort_order')
          .limit(5);
    } on PostgrestException catch (error) {
      if (_isOptionalSourceMissing(error)) return const [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadStats(String userId) async {
    try {
      return await _client
          .schema('praticase')
          .from('user_dashboard_stats')
          .select(
            'solved_case_count,success_rate_percent,total_points,daily_streak,'
            'solved_delta_percent,success_delta_percent,points_delta_percent,'
            'streak_label',
          )
          .eq('user_id', userId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (_isOptionalSourceMissing(error)) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadContinuedCase(String userId) async {
    try {
      return await _client
          .schema('praticase')
          .from('user_home_case_progress')
          .select('case_id,title,branch,difficulty,progress_percent,updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (_isOptionalSourceMissing(error)) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecommendations(String userId) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_recommended_cases')
          .select(
            'case_id,title,branch,difficulty,points,icon_key,is_bookmarked,sort_order',
          )
          .eq('user_id', userId)
          .order('sort_order')
          .limit(8);
      if (rows.isNotEmpty) return rows;
    } on PostgrestException catch (error) {
      if (!_isOptionalSourceMissing(error)) rethrow;
    }
    return _loadPublishedCases();
  }

  Future<List<Map<String, dynamic>>> _loadPublishedCases() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('cases')
          .select('id,title,branch,difficulty,points,icon_key')
          .eq('is_published', true)
          .like('slug', 'admin-%')
          .order('created_at', ascending: false)
          .limit(8);
      return [
        for (final row in rows)
          {
            'case_id': row['id'],
            'title': row['title'],
            'branch': row['branch'],
            'difficulty': row['difficulty'],
            'points': row['points'],
            'icon_key': row['icon_key'],
            'is_bookmarked': false,
          },
      ];
    } on PostgrestException catch (error) {
      if (_isOptionalSourceMissing(error)) return const [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadBadgeSummary(String userId) async {
    try {
      return await _client
          .schema('praticase')
          .from('user_badge_summary')
          .select('title,subtitle,action_label')
          .eq('user_id', userId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (_isOptionalSourceMissing(error)) return null;
      rethrow;
    }
  }

  Future<int> _loadUnreadNotificationCount(String userId) async {
    try {
      final response = await _client
          .schema('praticase')
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } on PostgrestException catch (error) {
      if (_isOptionalSourceMissing(error)) return 0;
      rethrow;
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
    final imageUrl = _readString(row, 'image_url');
    final storagePath = _readString(row, 'image_storage_path');
    return HomeBanner(
      id: _readString(row, 'id') ?? '',
      title: _readString(row, 'title') ?? '',
      subtitle: _readString(row, 'subtitle') ?? '',
      ctaLabel: _readString(row, 'cta_label') ?? 'Başla',
      ctaRoute: _readString(row, 'deep_link') ?? _readString(row, 'cta_route'),
      imageUrl:
          imageUrl ??
          (storagePath == null
              ? null
              : _client.storage
                    .from('praticase-home')
                    .getPublicUrl(storagePath)),
      imageAltText: _readString(row, 'image_alt_text') ?? '',
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
    if (_isOptionalSourceMissing(error)) {
      return 'Ana ekran verisi şu anda hazırlanıyor. Lütfen daha sonra tekrar deneyin.';
    }
    if (error.code == 'PGRST301' || error.code == '401') {
      return 'Oturumun süresi dolmuş olabilir. Lütfen yeniden giriş yap.';
    }
    return 'Ana ekran canlı verisi alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
  }

  bool _isOptionalSourceMissing(PostgrestException error) {
    if (error.code == '42P01' ||
        error.code == 'PGRST205' ||
        error.code == '42883' ||
        error.code == 'PGRST202') {
      return true;
    }
    final message = error.message.toLowerCase();
    return message.contains('schema cache') ||
        message.contains('could not find') ||
        message.contains('does not exist') ||
        message.contains('not found in the schema');
  }
}
