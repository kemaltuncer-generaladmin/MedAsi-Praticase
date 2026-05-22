import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/progress_models.dart';
import 'progress_repository.dart';

class SupabaseProgressRepository implements ProgressRepository {
  const SupabaseProgressRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<BadgeCard>> loadBadges() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_badge_cards')
          .select(
            'badge_id,title,subtitle,icon_key,tier,progress_count,target_count,earned_at,sort_order',
          )
          .order('sort_order');
      return [
        for (final row in rows)
          BadgeCard(
            id: _string(row, 'badge_id'),
            title: _string(row, 'title'),
            subtitle: _string(row, 'subtitle'),
            iconKey: _nullableString(row, 'icon_key'),
            tier: _string(row, 'tier'),
            progressCount: _int(row, 'progress_count'),
            targetCount: _int(row, 'target_count'),
            earned: row['earned_at'] != null,
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('leaderboard_general')
          .select(
            'rank,user_id,display_name,total_points,solved_case_count,correct_diagnosis_rate,is_current_user',
          )
          .order('rank')
          .limit(100);
      return [
        for (final row in rows)
          LeaderboardEntry(
            rank: _int(row, 'rank'),
            userId: _string(row, 'user_id'),
            displayName: _string(row, 'display_name'),
            totalPoints: _int(row, 'total_points'),
            solvedCaseCount: _int(row, 'solved_case_count'),
            correctDiagnosisRate: _int(row, 'correct_diagnosis_rate'),
            isCurrentUser: row['is_current_user'] == true,
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<ProfileCard> loadProfile() async {
    try {
      final row = await _client
          .schema('praticase')
          .from('user_profile_cards')
          .select(
            'display_name,email,class_level,target,total_points,solved_case_count,'
            'correct_diagnosis_rate,daily_streak,success_rate_percent,display_mode,'
            'language,text_size,sound_and_haptics,data_usage,offline_mode,case_downloads_enabled',
          )
          .maybeSingle();
      if (row == null) {
        throw const ProgressDataUnavailable(
          'Profil kaydı bulunamadı. Lütfen profil kurulumunu tamamlayın.',
        );
      }
      return ProfileCard(
        displayName: _string(row, 'display_name').isEmpty
            ? _currentUserLabel()
            : _string(row, 'display_name'),
        email: _string(row, 'email').isEmpty
            ? (_client.auth.currentUser?.email ?? '')
            : _string(row, 'email'),
        classLevel: _string(row, 'class_level').isEmpty
            ? '5'
            : _string(row, 'class_level'),
        target: _string(row, 'target').isEmpty
            ? 'Staj + TUS'
            : _string(row, 'target'),
        totalPoints: _int(row, 'total_points'),
        solvedCaseCount: _int(row, 'solved_case_count'),
        correctDiagnosisRate: _int(row, 'correct_diagnosis_rate'),
        dailyStreak: _int(row, 'daily_streak'),
        successRatePercent: _int(row, 'success_rate_percent'),
        settings: AppSettings(
          displayMode: _string(row, 'display_mode').isEmpty
              ? 'Sistem'
              : _string(row, 'display_mode'),
          language: _string(row, 'language').isEmpty
              ? 'Türkçe'
              : _string(row, 'language'),
          textSize: _string(row, 'text_size').isEmpty
              ? 'Orta'
              : _string(row, 'text_size'),
          soundAndHaptics: row['sound_and_haptics'] != false,
          dataUsage: _string(row, 'data_usage').isEmpty
              ? 'Standart'
              : _string(row, 'data_usage'),
          offlineMode: row['offline_mode'] == true,
          caseDownloadsEnabled: row['case_downloads_enabled'] == true,
        ),
      );
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<NotificationCard>> loadNotifications() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_notification_cards')
          .select('id,title,body,is_read,created_at')
          .order('created_at', ascending: false);
      return [
        for (final row in rows)
          NotificationCard(
            id: _string(row, 'id'),
            title: _string(row, 'title'),
            body: _string(row, 'body'),
            isRead: row['is_read'] == true,
            createdAt:
                DateTime.tryParse(_string(row, 'created_at')) ?? DateTime.now(),
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    try {
      await _client
          .schema('praticase')
          .from('user_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<SimpleContentItem>> loadSupportTopics() => _loadSimple(
    'support_topics',
    'id,title,icon_key,sort_order',
    'sort_order',
  );

  @override
  Future<List<SimpleContentItem>> loadFaqItems() =>
      _loadSimple('faq_items', 'id,question,answer,sort_order', 'sort_order');

  @override
  Future<List<SimpleContentItem>> loadAnnouncements() => _loadSimple(
    'announcements',
    'id,title,body,published_at',
    'published_at',
  );

  @override
  Future<List<SimpleContentItem>> loadUserDataOverview() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_data_overview')
          .select('title,data_key');
      return [
        for (final row in rows)
          SimpleContentItem(
            id: _string(row, 'data_key'),
            title: _string(row, 'title'),
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<CaseCollectionItem>> loadFavoriteCases() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_favorite_cases')
          .select('case_id,title,branch,difficulty,points,icon_key,created_at');
      return [for (final row in rows) _caseCollection(row)];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<CaseCollectionItem>> loadCaseHistory() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_case_history_cards')
          .select(
            'case_id,title,icon_key,status,updated_at,progress_percent,total_score',
          );
      return [
        for (final row in rows)
          CaseCollectionItem(
            caseId: _string(row, 'case_id'),
            title: _string(row, 'title'),
            branch: _string(row, 'status'),
            difficulty: '',
            points: 0,
            iconKey: _nullableString(row, 'icon_key'),
            progressPercent: _nullableInt(row, 'progress_percent'),
            score: _nullableInt(row, 'total_score'),
            updatedAt: DateTime.tryParse(_string(row, 'updated_at')),
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<List<UserNote>> loadNotes() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_notes')
          .select('id,title,body,category,updated_at,cases(title)')
          .order('updated_at', ascending: false);
      return [
        for (final row in rows)
          UserNote(
            id: _string(row, 'id'),
            title: _string(row, 'title').isEmpty
                ? 'Klinik Not'
                : _string(row, 'title'),
            body: _string(row, 'body'),
            category: _string(row, 'category').isEmpty
                ? 'Genel'
                : _string(row, 'category'),
            caseTitle: _caseTitle(row['cases']),
            updatedAt:
                DateTime.tryParse(_string(row, 'updated_at')) ?? DateTime.now(),
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<String> exportUserData() async {
    try {
      final profile = await loadProfile();
      final notes = await loadNotes();
      final history = await loadCaseHistory();
      final favorites = await loadFavoriteCases();
      final notifications = await loadNotifications();
      return const JsonEncoder.withIndent('  ').convert({
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'profile': {
          'displayName': profile.displayName,
          'email': profile.email,
          'classLevel': profile.classLevel,
          'target': profile.target,
          'totalPoints': profile.totalPoints,
          'solvedCaseCount': profile.solvedCaseCount,
          'successRatePercent': profile.successRatePercent,
        },
        'notes': [
          for (final note in notes)
            {
              'title': note.title,
              'category': note.category,
              'caseTitle': note.caseTitle,
              'body': note.body,
              'updatedAt': note.updatedAt.toUtc().toIso8601String(),
            },
        ],
        'caseHistory': [
          for (final item in history)
            {
              'caseId': item.caseId,
              'title': item.title,
              'status': item.branch,
              'progressPercent': item.progressPercent,
              'score': item.score,
            },
        ],
        'favoriteCases': [
          for (final item in favorites)
            {'caseId': item.caseId, 'title': item.title},
        ],
        'notifications': [
          for (final item in notifications)
            {
              'title': item.title,
              'body': item.body,
              'isRead': item.isRead,
              'createdAt': item.createdAt.toUtc().toIso8601String(),
            },
        ],
      });
    } on ProgressDataUnavailable {
      rethrow;
    } on Object {
      throw const ProgressDataUnavailable(
        'Kullanıcı verisi dışa aktarılamadı.',
      );
    }
  }

  @override
  Future<void> createContactRequest({
    required String subject,
    required String email,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProgressDataUnavailable('Oturum bulunamadı.');
    }
    if (subject.trim().isEmpty ||
        email.trim().isEmpty ||
        message.trim().isEmpty) {
      throw const ProgressDataUnavailable('Tüm iletişim alanları zorunlu.');
    }
    try {
      await _client.schema('praticase').from('contact_requests').insert({
        'user_id': user.id,
        'subject': subject.trim(),
        'email': email.trim(),
        'message': message.trim(),
      });
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> saveProfile({
    required String displayName,
    required String email,
    required String specialty,
    required String educationLevel,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProgressDataUnavailable('Oturum bulunamadı.');
    }
    if (displayName.trim().isEmpty || email.trim().isEmpty) {
      throw const ProgressDataUnavailable('Ad soyad ve e-posta zorunlu.');
    }
    final parts = displayName.trim().split(RegExp(r'\s+'));
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': email.trim(),
        'first_name': parts.isEmpty ? null : parts.first,
        'last_name': parts.length <= 1 ? null : parts.skip(1).join(' '),
        'target': specialty.trim(),
        'class_level': educationLevel.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProgressDataUnavailable('Oturum bulunamadı.');
    }
    try {
      await _client.schema('praticase').from('user_app_settings').upsert({
        'user_id': user.id,
        'display_mode': settings.displayMode,
        'language': settings.language,
        'text_size': settings.textSize,
        'sound_and_haptics': settings.soundAndHaptics,
        'data_usage': settings.dataUsage,
        'offline_mode': settings.offlineMode,
        'case_downloads_enabled': settings.caseDownloadsEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  Future<List<SimpleContentItem>> _loadSimple(
    String table,
    String columns,
    String orderColumn,
  ) async {
    try {
      final rows = await _client
          .schema('praticase')
          .from(table)
          .select(columns)
          .order(orderColumn);
      return [
        for (final row in rows)
          SimpleContentItem(
            id: _string(row, 'id'),
            title: _string(row, 'title').isNotEmpty
                ? _string(row, 'title')
                : _string(row, 'question'),
            body: _string(row, 'body').isNotEmpty
                ? _string(row, 'body')
                : _string(row, 'answer'),
            trailing: _string(row, orderColumn),
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  CaseCollectionItem _caseCollection(Map<String, dynamic> row) {
    return CaseCollectionItem(
      caseId: _string(row, 'case_id'),
      title: _string(row, 'title'),
      branch: _string(row, 'branch'),
      difficulty: _string(row, 'difficulty'),
      points: _int(row, 'points'),
      iconKey: _nullableString(row, 'icon_key'),
      updatedAt: DateTime.tryParse(_string(row, 'created_at')),
    );
  }

  String _currentUserLabel() {
    final user = _client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final fullName = metadata['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    return user?.email ?? '';
  }

  String? _caseTitle(Object? value) {
    final row = value is Map<String, dynamic> ? value : null;
    final title = row == null ? '' : _string(row, 'title');
    return title.isEmpty ? null : title;
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  String? _nullableString(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    return value.isEmpty ? null : value;
  }

  int _int(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _nullableInt(Map<String, dynamic> row, String key) {
    if (row[key] == null) return null;
    return _int(row, key);
  }

  String _message(PostgrestException error) {
    if (error.code == '42P01' || error.message.contains('schema')) {
      return 'Profil ve gelişim verisi şu anda hazırlanıyor. Lütfen daha sonra tekrar deneyin.';
    }
    return 'Canlı profil/gelişim verisi alınamadı. Lütfen bağlantı ve yetkileri kontrol edin.';
  }
}
