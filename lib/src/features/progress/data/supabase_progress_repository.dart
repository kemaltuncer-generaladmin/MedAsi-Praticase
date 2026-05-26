import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/user_facing_error.dart';
import '../domain/progress_models.dart';
import 'progress_repository.dart';

class SupabaseProgressRepository implements ProgressRepository {
  const SupabaseProgressRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<ExamModeItem>> loadExamModes() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('exam_mode_cards')
          .select('id,title,subtitle,icon_key,action_key,sort_order')
          .eq('is_active', true)
          .neq('id', 'branch_package')
          .order('sort_order');
      return [
        for (final row in rows)
          ExamModeItem(
            id: _string(row, 'id'),
            title: _string(row, 'id') == 'theoretical_exam'
                ? 'Teorik Sınav'
                : _string(row, 'title'),
            subtitle: _string(row, 'subtitle'),
            iconKey: _string(row, 'icon_key'),
            actionKey: _string(row, 'action_key'),
          ),
      ];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<StoreCatalog> loadStoreCatalog() async {
    try {
      final response = await _client.functions.invoke(
        'praticase-storekit-verify',
        body: {'action': 'catalog'},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final error = data['error']?.toString().trim() ?? '';
      if (error.isNotEmpty) {
        throw ProgressDataUnavailable(
          PratiCaseUserMessage.safe(
            error,
            fallback: PratiCaseUserMessage.storeFailure,
          ),
        );
      }
      return _storeCatalog(data);
    } on ProgressDataUnavailable {
      rethrow;
    } on FunctionException {
      throw const ProgressDataUnavailable(PratiCaseUserMessage.storeFailure);
    } on Object {
      throw const ProgressDataUnavailable(PratiCaseUserMessage.storeFailure);
    }
  }

  @override
  Future<StoreCatalog> completeStorePurchase({
    required StoreProduct product,
    required String purchaseId,
    required String verificationSource,
    required String localVerificationData,
    required String serverVerificationData,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'praticase-storekit-verify',
        body: {
          'action': 'verify',
          'product_code': product.code,
          'store_product_id': product.appStoreProductId,
          'provider': 'app_store',
          'purchase_id': purchaseId,
          'verification_data': {
            'source': verificationSource,
            'local_verification_data': localVerificationData,
            'server_verification_data': serverVerificationData,
          },
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final error = data['error']?.toString().trim() ?? '';
      if (error.isNotEmpty) {
        throw ProgressDataUnavailable(
          PratiCaseUserMessage.safe(
            error,
            fallback: PratiCaseUserMessage.purchaseFailure,
          ),
        );
      }
      return loadStoreCatalog();
    } on ProgressDataUnavailable {
      rethrow;
    } on FunctionException {
      throw const ProgressDataUnavailable(PratiCaseUserMessage.purchaseFailure);
    } on Object {
      throw const ProgressDataUnavailable(PratiCaseUserMessage.purchaseFailure);
    }
  }

  @override
  Future<List<BadgeCard>> loadBadges() async {
    try {
      await _refreshUserBadges();
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
            'language,text_size,sound_and_haptics,data_usage,offline_mode,case_downloads_enabled,'
            'target_branches,daily_goal,osce_exam_date',
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
        dailyGoal: _int(row, 'daily_goal') <= 0 ? 1 : _int(row, 'daily_goal'),
        osceExamDate: DateTime.tryParse(_string(row, 'osce_exam_date')),
        targetBranches: _stringList(row['target_branches']),
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
  Future<ClinicalProgressSummary> loadClinicalProgressSummary() async {
    try {
      final learningFeedback = await _loadLearningGapFeedback();
      final osceRows = await _client
          .schema('praticase')
          .from('session_result_cards')
          .select(
            'case_title,case_branch,ended_at,total_score,percentage,'
            'category_scores,improvement_points,critical_mistakes,'
            'unnecessary_tests,missed_history,missed_physical_exam,missed_tests',
          )
          .order('ended_at', ascending: false);
      final rows =
          <Map<String, dynamic>>[
            for (final row in osceRows) Map<String, dynamic>.from(row),
            ...await _loadOralProgressRows(),
          ]..sort((a, b) {
            final left =
                DateTime.tryParse(_string(a, 'ended_at')) ?? DateTime(1970);
            final right =
                DateTime.tryParse(_string(b, 'ended_at')) ?? DateTime(1970);
            return right.compareTo(left);
          });
      final totals = <String, (int, int)>{
        'communication': (0, 0),
        'history': (0, 0),
        'physical': (0, 0),
        'tests': (0, 0),
        'diagnosis': (0, 0),
        'management': (0, 0),
      };
      for (final row in rows) {
        final categories = row['category_scores'] as List<dynamic>? ?? [];
        for (final value in categories) {
          if (value is! Map<String, dynamic>) continue;
          final key = _categoryKey(_string(value, 'title'));
          if (key == null) continue;
          final current = totals[key]!;
          totals[key] = (
            current.$1 + _int(value, 'score'),
            current.$2 + _int(value, 'maxScore'),
          );
        }
      }
      return ClinicalProgressSummary(
        sessionCount: rows.length,
        categoryScores: [
          _skillScore('communication', 'İletişim', totals),
          _skillScore('history', 'Anamnez', totals),
          _skillScore('physical', 'Fizik Muayene', totals),
          _skillScore('tests', 'Tetkik İnceleme', totals),
          _skillScore('diagnosis', 'Ayırıcı Tanı', totals),
          _skillScore('management', 'Yönetim & Tedavi', totals),
        ],
        recentResults: _recentResults(rows),
        feedback: [
          ...learningFeedback,
          ..._feedbackInsights(rows),
        ].take(4).toList(),
      );
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  Future<List<Map<String, dynamic>>> _loadOralProgressRows() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('oral_exam_sessions')
          .select(
            'id,branch_id,ended_at,total_score,max_score,reasoning_score,'
            'knowledge_score,communication_score,pace_score,professionalism_score,'
            'mentor_summary,improvement_points,missed_points,case_brief,'
            'critical_errors,'
            'oral_exam_branches(title)',
          )
          .eq('status', 'completed')
          .order('ended_at', ascending: false);
      return [
        for (final row in rows)
          _oralProgressRow(Map<String, dynamic>.from(row)),
      ];
    } on PostgrestException catch (error) {
      if (_isMissingSource(error)) return const [];
      rethrow;
    }
  }

  Map<String, dynamic> _oralProgressRow(Map<String, dynamic> row) {
    final maxScore = _int(row, 'max_score') <= 0 ? 100 : _int(row, 'max_score');
    final total = _int(row, 'total_score').clamp(0, maxScore).toInt();
    final branch = _oralBranchTitle(row['oral_exam_branches']);
    return {
      'case_title': _oralCaseTitle(_string(row, 'case_brief')),
      'case_branch': branch.isEmpty ? 'Sözlü Sınav' : 'Sözlü - $branch',
      'ended_at': _string(row, 'ended_at'),
      'total_score': total,
      'percentage': ((total / maxScore) * 100).round().clamp(0, 100).toInt(),
      'category_scores': [
        {
          'title': 'İletişim',
          'score': _int(row, 'communication_score'),
          'maxScore': 15,
        },
        {
          'title': 'Ayırıcı Tanı',
          'score': _int(row, 'reasoning_score'),
          'maxScore': 40,
        },
        {
          'title': 'Yönetim & Tedavi',
          'score': _int(row, 'knowledge_score'),
          'maxScore': 30,
        },
      ],
      'improvement_points': _stringList(row['improvement_points']),
      'critical_mistakes': _stringList(row['critical_errors']),
      'unnecessary_tests': const <String>[],
      'missed_history': _stringList(row['missed_points']),
      'missed_physical_exam': const <String>[],
      'missed_tests': const <String>[],
    };
  }

  @override
  Future<List<NotificationCard>> loadNotifications() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_notification_cards')
          .select('id,title,body,is_read,created_at')
          .order('created_at', ascending: false);
      return [for (final row in rows) _notification(row)];
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Future<int> loadUnreadNotificationCount() async {
    try {
      final response = await _client
          .schema('praticase')
          .from('user_notifications')
          .select('id')
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } on PostgrestException catch (error) {
      throw ProgressDataUnavailable(_message(error));
    }
  }

  @override
  Stream<List<NotificationCard>> watchNotifications() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(const <NotificationCard>[]);
    return _client
        .schema('praticase')
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((rows) => [for (final row in rows) _notification(row)]);
  }

  @override
  Stream<int> watchUnreadNotificationCount() {
    return watchNotifications().map(
      (items) => items.where((item) => !item.isRead).length,
    );
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
  Future<void> markAllNotificationsRead() async {
    try {
      await _client
          .schema('praticase')
          .from('user_notifications')
          .update({'is_read': true})
          .eq('is_read', false);
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
      final seen = <String>{};
      return [
        for (final row in rows) ...[
          if (seen.add(
            '${_string(row, 'title')}/${_string(row, 'question')}/${_string(row, 'body')}/${_string(row, 'answer')}',
          ))
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
        ],
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

  Future<void> _refreshUserBadges() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .schema('praticase')
          .rpc('refresh_user_badges', params: {'p_user_id': user.id});
    } on PostgrestException {
      // Older databases can still serve badge cards without the refresh RPC.
    }
  }

  String _currentUserLabel() {
    final user = _client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final fullName = metadata['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    return user == null ? '' : 'PratiCase Öğrencisi';
  }

  List<ProgressResultInsight> _recentResults(List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows.take(6))
        ProgressResultInsight(
          caseTitle: _string(row, 'case_title').isEmpty
              ? 'OSCE İstasyonu'
              : _string(row, 'case_title'),
          branch: _string(row, 'case_branch').isEmpty
              ? 'Genel'
              : _string(row, 'case_branch'),
          score: _int(row, 'percentage').clamp(0, 100).toInt(),
          endedAt: DateTime.tryParse(_string(row, 'ended_at')),
        ),
    ];
  }

  List<ProgressFeedbackInsight> _feedbackInsights(
    List<Map<String, dynamic>> rows,
  ) {
    final critical = _topItems(rows, 'critical_mistakes');
    final unnecessary = _topItems(rows, 'unnecessary_tests');
    final missedTests = _topItems(rows, 'missed_tests');
    final missedHistory = _topItems(rows, 'missed_history');
    final missedExam = _topItems(rows, 'missed_physical_exam');
    final improvement = _topItems(rows, 'improvement_points');
    return [
      if (critical.isNotEmpty)
        ProgressFeedbackInsight(title: 'Kritik Hatalar', items: critical),
      if (missedHistory.isNotEmpty)
        ProgressFeedbackInsight(
          title: 'Eksik Anamnez Başlıkları',
          items: missedHistory,
        ),
      if (missedExam.isNotEmpty)
        ProgressFeedbackInsight(
          title: 'Kaçırılan Muayeneler',
          items: missedExam,
        ),
      if (missedTests.isNotEmpty)
        ProgressFeedbackInsight(
          title: 'Eksik Gerekli Tetkikler',
          items: missedTests,
        ),
      if (unnecessary.isNotEmpty)
        ProgressFeedbackInsight(
          title: 'Gereksiz Tetkikler',
          items: unnecessary,
        ),
      if (improvement.isNotEmpty)
        ProgressFeedbackInsight(title: 'Klinik Öneriler', items: improvement),
    ].take(4).toList();
  }

  Future<List<ProgressFeedbackInsight>> _loadLearningGapFeedback() async {
    try {
      final rows = await _client
          .schema('praticase')
          .from('user_learning_gap_rollups')
          .select(
            'exam_kind,skill_code,skill_label,concept_label,topic,branch,'
            'event_count,occurrence_count,critical_count,incorrect_count,'
            'omitted_count,missed_count,unnecessary_count,unsafe_count,'
            'personalization_score',
          )
          .order('personalization_score', ascending: false)
          .limit(12);
      final theoretical = <String>[];
      final clinical = <String>[];
      for (final row in rows) {
        final rowMap = Map<String, dynamic>.from(row);
        final item = _learningGapItem(rowMap);
        if (item.isEmpty) continue;
        if (_string(rowMap, 'exam_kind') == 'theoretical') {
          if (theoretical.length < 3) theoretical.add(item);
        } else if (clinical.length < 3) {
          clinical.add(item);
        }
      }
      return [
        if (theoretical.isNotEmpty)
          ProgressFeedbackInsight(
            title: 'Kişisel Teorik Eksikler',
            items: theoretical,
          ),
        if (clinical.isNotEmpty)
          ProgressFeedbackInsight(
            title: 'Klinik Performans Odakları',
            items: clinical,
          ),
      ];
    } on PostgrestException catch (error) {
      if (_isMissingSource(error)) return const [];
      rethrow;
    }
  }

  String _learningGapItem(Map<String, dynamic> row) {
    final concept = _string(row, 'concept_label').isNotEmpty
        ? _string(row, 'concept_label')
        : _string(row, 'topic').isNotEmpty
        ? _string(row, 'topic')
        : _string(row, 'branch');
    if (concept.isEmpty) return '';
    final skill = _string(row, 'skill_label');
    final count = _int(row, 'occurrence_count');
    final critical = _int(row, 'critical_count');
    final suffix = critical > 0
        ? '$critical kritik kayıt'
        : count > 1
        ? '$count tekrar'
        : '1 kayıt';
    return skill.isEmpty || concept.toLowerCase() == skill.toLowerCase()
        ? '$concept - $suffix'
        : '$concept / $skill - $suffix';
  }

  List<String> _topItems(List<Map<String, dynamic>> rows, String key) {
    final counts = <String, int>{};
    for (final row in rows) {
      for (final item in _stringList(row[key])) {
        counts[item] = (counts[item] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final count = b.value.compareTo(a.value);
        return count == 0 ? a.key.compareTo(b.key) : count;
      });
    return [for (final item in sorted.take(3)) item.key];
  }

  NotificationCard _notification(Map<String, dynamic> row) {
    return NotificationCard(
      id: _string(row, 'id'),
      title: _string(row, 'title'),
      body: _string(row, 'body'),
      isRead: row['is_read'] == true,
      createdAt:
          DateTime.tryParse(_string(row, 'created_at')) ?? DateTime.now(),
    );
  }

  String? _caseTitle(Object? value) {
    final row = value is Map<String, dynamic> ? value : null;
    final title = row == null ? '' : _string(row, 'title');
    return title.isEmpty ? null : title;
  }

  String _oralBranchTitle(Object? value) {
    final row = value is Map<String, dynamic>
        ? value
        : value is List && value.isNotEmpty && value.first is Map
        ? Map<String, dynamic>.from(value.first as Map)
        : null;
    return row == null ? '' : _string(row, 'title');
  }

  String _oralCaseTitle(String caseBrief) {
    final trimmed = caseBrief.trim();
    if (trimmed.isEmpty) return 'Sözlü Sınav';
    final sentenceEnd = trimmed.indexOf('.');
    final title = sentenceEnd > 24
        ? trimmed.substring(0, sentenceEnd)
        : trimmed;
    return title.length > 72 ? '${title.substring(0, 69).trim()}...' : title;
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

  List<String> _stringList(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ];
    }
    return const [];
  }

  ClinicalSkillScore _skillScore(
    String category,
    String label,
    Map<String, (int, int)> totals,
  ) {
    final total = totals[category] ?? (0, 0);
    return ClinicalSkillScore(
      category: category,
      label: label,
      score: total.$1,
      maxScore: total.$2,
    );
  }

  String? _categoryKey(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('iletişim') || normalized.contains('iletisim')) {
      return 'communication';
    }
    if (normalized.contains('anamnez')) return 'history';
    if (normalized.contains('fizik') || normalized.contains('muayene')) {
      return 'physical';
    }
    if (normalized.contains('tetkik')) return 'tests';
    if (normalized.contains('tanı') || normalized.contains('tani')) {
      return 'diagnosis';
    }
    if (normalized.contains('yönetim') ||
        normalized.contains('yonetim') ||
        normalized.contains('tedavi')) {
      return 'management';
    }
    return null;
  }

  String _message(PostgrestException error) {
    if (_isMissingSource(error)) {
      return 'Profil ve gelişim verisi şu anda hazırlanıyor. Lütfen daha sonra tekrar deneyin.';
    }
    if (error.code == 'PGRST301' || error.code == '401') {
      return 'Oturumun süresi dolmuş olabilir. Lütfen yeniden giriş yap.';
    }
    return 'Profil ve gelişim verileri alınamadı. Bağlantını kontrol edip tekrar dene.';
  }

  bool _isMissingSource(PostgrestException error) {
    if (error.code == '42P01' ||
        error.code == 'PGRST205' ||
        error.code == '42883' ||
        error.code == 'PGRST202') {
      return true;
    }
    final message = error.message.toLowerCase();
    return message.contains('does not exist') ||
        message.contains('schema cache') ||
        message.contains('not found in the schema') ||
        message.contains('could not find');
  }

  StoreCatalog _storeCatalog(Map<String, dynamic> data) {
    final profile = data['profile'] is Map
        ? Map<String, dynamic>.from(data['profile'] as Map)
        : const <String, dynamic>{};
    final products = data['products'] is List
        ? data['products'] as List
        : const [];
    final warnings = data['wallet_warnings'] is List
        ? data['wallet_warnings'] as List
        : const [];
    return StoreCatalog(
      walletBalance: (profile['wallet_balance'] as num?)?.toDouble() ?? 0,
      questionQuota: _int(profile, 'question_quota'),
      aiQuota: _int(profile, 'ai_quota'),
      warnings: [
        for (final item in warnings)
          if (item is Map &&
              (item['message']?.toString().trim() ?? '').isNotEmpty)
            item['message'].toString().trim(),
      ],
      products: [
        for (final item in products)
          if (item is Map)
            StoreProduct(
              code: item['code']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              description: item['description']?.toString() ?? '',
              priceCents: (item['price_cents'] as num?)?.round() ?? 0,
              currency: item['currency']?.toString() ?? 'TRY',
              questionAmount: (item['question_amount'] as num?)?.round() ?? 0,
              coinAmount: (item['coin_amount'] as num?)?.toDouble() ?? 0,
              appStoreProductId: item['app_store_product_id']?.toString() ?? '',
              isFeatured: item['is_featured'] == true,
              interval: item['interval']?.toString() ?? '',
            ),
      ],
    );
  }
}
