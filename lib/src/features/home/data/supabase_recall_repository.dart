import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/user_facing_error.dart';
import '../domain/recall_summary.dart';
import 'recall_repository.dart';

class SupabaseRecallRepository implements RecallRepository {
  SupabaseRecallRepository({
    required SupabaseClient client,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _client = client,
       _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://recall.medasi.com.tr');

  final SupabaseClient _client;
  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  Future<RecallSummary> loadSummary() async {
    final token = _client.auth.currentSession?.accessToken.trim() ?? '';
    if (token.isEmpty) {
      return const RecallSummary.unauthenticated();
    }

    try {
      final today = await _getJson(
        _baseUri.replace(
          path: '/recall/today',
          queryParameters: {'source_app': 'praticase'},
        ),
        token,
      );
      final weaknessData = await _getJson(
        _baseUri.replace(
          path: '/recall/weaknesses',
          queryParameters: {'source_app': 'praticase', 'limit': '5'},
        ),
        token,
      );
      final todayTotal = _todayTotal(today);
      final weaknesses = _weaknesses(weaknessData).take(5).toList();
      final guidance = await _loadRecallGuidance(
        todayTotal: todayTotal,
        weaknesses: weaknesses,
      );

      return RecallSummary(
        todayTotal: todayTotal,
        weaknesses: weaknesses,
        guidance: guidance,
        action: guidance.action.isNotEmpty
            ? guidance.action
            : _fallbackGuidance(todayTotal, weaknesses).action,
      );
    } on RecallDataUnavailable catch (error) {
      return RecallSummary.error(error.message);
    } on Object {
      return const RecallSummary.error(
        'Recall özeti şu anda alınamadı. Ana çalışma akışın etkilenmez.',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String token) async {
    final response = await _httpClient.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RecallDataUnavailable(
        'Recall bağlantısı için yeniden giriş gerekebilir.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const RecallDataUnavailable(
        'Recall özeti şu anda alınamadı. Ana çalışma akışın etkilenmez.',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List) return {'items': decoded};
    return const {};
  }

  Future<RecallGuidance> _loadRecallGuidance({
    required int todayTotal,
    required List<RecallWeakness> weaknesses,
  }) async {
    final fallback = _fallbackGuidance(todayTotal, weaknesses);
    if (todayTotal == 0 && weaknesses.isEmpty) return fallback;

    final body = {
      'source': 'recall_praticase_summary',
      'today_total': todayTotal,
      'weaknesses': [
        for (final weakness in weaknesses) weakness.toSanitizedJson(),
      ],
    };

    try {
      final response = await _client.functions.invoke(
        'praticase-recall-guidance',
        body: body,
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final error = map['error']?.toString().trim() ?? '';
      if (response.status >= 400 || error.isNotEmpty) return fallback;
      final sentence = _stringFromAny(
        map['guidance_sentence'] ?? map['sentence'] ?? map['guidance'],
      );
      final action = _stringFromAny(
        map['study_action'] ?? map['recommended_action'] ?? map['action'],
      );
      if (sentence.isEmpty && action.isEmpty) return fallback;
      return RecallGuidance(
        sentence: PratiCaseUserMessage.safe(
          sentence,
          fallback: fallback.sentence,
        ),
        action: PratiCaseUserMessage.safe(action, fallback: fallback.action),
      );
    } on Object {
      return fallback;
    }
  }

  static RecallGuidance _fallbackGuidance(
    int todayTotal,
    List<RecallWeakness> weaknesses,
  ) {
    if (todayTotal == 0 && weaknesses.isEmpty) {
      return const RecallGuidance.empty();
    }
    final topic = weaknesses
        .map((weakness) => weakness.topic)
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => 'öncelikli konu',
        );
    return RecallGuidance(
      sentence:
          'Bugün önce yüksek riskli PratiCase tekrarlarından başla; özellikle $topic alanını kısa bir tekrar ve vaka çözümüyle pekiştir.',
      action: 'Yüksek riskli tekrarları tamamla.',
    );
  }

  static int _todayTotal(Map<String, dynamic> data) {
    final candidates = [
      data['today_total'],
      data['total'],
      data['count'],
      data['pending_count'],
      data['praticase_count'],
    ];
    for (final value in candidates) {
      final parsed = _intFromAny(value);
      if (parsed != null) return parsed;
    }
    final items = _listFromAny(
      data['items'] ?? data['recalls'] ?? data['data'],
    );
    return items.length;
  }

  static List<RecallWeakness> _weaknesses(Map<String, dynamic> data) {
    final rows = _listFromAny(
      data['weaknesses'] ?? data['items'] ?? data['data'] ?? data['results'],
    );
    return [
      for (final row in rows)
        if (row is Map) _weakness(Map<String, dynamic>.from(row)),
    ].where((weakness) {
      return weakness.title.isNotEmpty || weakness.topic.isNotEmpty;
    }).toList();
  }

  static RecallWeakness _weakness(Map<String, dynamic> row) {
    final title = _stringFromAny(
      row['title'] ??
          row['name'] ??
          row['label'] ??
          row['weakness_title'] ??
          row['topic'],
    );
    final topic = _stringFromAny(
      row['topic'] ?? row['subject'] ?? row['course'] ?? title,
    );
    final riskLevel = _stringFromAny(
      row['risk_level'] ?? row['risk'] ?? row['level'] ?? row['severity'],
    );
    return RecallWeakness(
      title: title,
      topic: topic,
      riskLevel: riskLevel.isEmpty ? 'medium' : riskLevel,
    );
  }

  static List<dynamic> _listFromAny(Object? value) {
    if (value is List) return value;
    if (value is Map) {
      return _listFromAny(value['items'] ?? value['data'] ?? value['results']);
    }
    return const [];
  }

  static int? _intFromAny(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _stringFromAny(Object? value) {
    if (value is String) return value.trim();
    return value?.toString().trim() ?? '';
  }
}
