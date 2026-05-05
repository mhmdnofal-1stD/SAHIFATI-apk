import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'secure_session_storage.dart';

class PendingEvaluationSyncItem {
  const PendingEvaluationSyncItem({
    required this.id,
    required this.endpoint,
    required this.body,
    required this.createdAtMs,
    this.accountKey,
  });

  final String id;
  final String endpoint;
  final Map<String, dynamic> body;
  final int createdAtMs;
  final String? accountKey;

  factory PendingEvaluationSyncItem.fromJson(Map<String, dynamic> json) {
    return PendingEvaluationSyncItem(
      id: json['id']?.toString() ?? '',
      endpoint: json['endpoint']?.toString() ?? '',
      body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      accountKey: json['accountKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'endpoint': endpoint,
      'body': body,
      'createdAtMs': createdAtMs,
      'accountKey': accountKey,
    };
  }
}

class OfflineAssessmentStore {
  static const String _quickQuestionsSchoolKey =
      'offline.quick_questions_school';
  static const String _pendingEvaluationSyncKey =
      'offline.pending_evaluation_sync';
  static const String _evaluationsKeyPrefix = 'offline.evaluations.';
  static const String _userEvaluationsKeyPrefix =
    'offline.user_evaluations.';
  static const String _quranChartKeyPrefix = 'offline.quran_chart.';
  static const String _currentUserProfileKeyPrefix =
      'offline.current_user_profile.';
  static const String _supervisionCodeKeyPrefix = 'offline.supervision_code.';
  static const String _notificationsKeyPrefix = 'offline.notifications.';
    static const String _teacherRecommendationsKeyPrefix =
      'offline.teacher_recommendations.';
  static const String _schoolsKey = 'offline.schools_catalog';
  static const String _subjectsHierarchyKey = 'offline.subjects_hierarchy';

  Future<void> cacheQuickQuestionsSchoolJson(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quickQuestionsSchoolKey, rawJson);
  }

  Future<String?> getCachedQuickQuestionsSchoolJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_quickQuestionsSchoolKey);
  }

  Future<void> cacheEvaluationsJson(String rawJson, {String? type}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_evaluationsKey(type), rawJson);
  }

  Future<String?> getCachedEvaluationsJson({String? type}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_evaluationsKey(type));
  }

  Future<void> cacheUserEvaluationsJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_userEvaluationsKeyPrefix, scopeKey), rawJson);
  }

  Future<String?> getCachedUserEvaluationsJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_userEvaluationsKeyPrefix, scopeKey));
  }

  Future<void> cacheQuranChartJson({
    required String scopeKey,
    required String dimension,
    required String filtersKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _quranChartKey(
        scopeKey: scopeKey,
        dimension: dimension,
        filtersKey: filtersKey,
      ),
      rawJson,
    );
  }

  Future<String?> getCachedQuranChartJson({
    required String scopeKey,
    required String dimension,
    required String filtersKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      _quranChartKey(
        scopeKey: scopeKey,
        dimension: dimension,
        filtersKey: filtersKey,
      ),
    );
  }

  Future<void> cacheCurrentUserProfileJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_currentUserProfileKeyPrefix, scopeKey), rawJson);
  }

  Future<String?> getCachedCurrentUserProfileJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_currentUserProfileKeyPrefix, scopeKey));
  }

  Future<void> cacheSupervisionCodeJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_supervisionCodeKeyPrefix, scopeKey), rawJson);
  }

  Future<String?> getCachedSupervisionCodeJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_supervisionCodeKeyPrefix, scopeKey));
  }

  Future<void> cacheNotificationsJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_notificationsKeyPrefix, scopeKey), rawJson);
  }

  Future<String?> getCachedNotificationsJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_notificationsKeyPrefix, scopeKey));
  }

  Future<void> cacheTeacherRecommendationsJson({
    required String scopeKey,
    required int studentId,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_teacherRecommendationsKeyPrefix, '$scopeKey.$studentId'),
      rawJson,
    );
  }

  Future<String?> getCachedTeacherRecommendationsJson({
    required String scopeKey,
    required int studentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      _scopedKey(_teacherRecommendationsKeyPrefix, '$scopeKey.$studentId'),
    );
  }

  Future<void> cacheSchoolsJson(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schoolsKey, rawJson);
  }

  Future<String?> getCachedSchoolsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_schoolsKey);
  }

  Future<void> cacheSubjectsHierarchyJson(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subjectsHierarchyKey, rawJson);
  }

  Future<String?> getCachedSubjectsHierarchyJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_subjectsHierarchyKey);
  }

  Future<List<PendingEvaluationSyncItem>>
      getPendingEvaluationSyncItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_pendingEvaluationSyncKey);
    if (rawJson == null || rawJson.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => PendingEvaluationSyncItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> enqueuePendingEvaluation({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final currentItems = await getPendingEvaluationSyncItems();
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    final nextItems = [
      ...currentItems,
      PendingEvaluationSyncItem(
        id: '${DateTime.now().microsecondsSinceEpoch}-${endpoint.hashCode}',
        endpoint: endpoint,
        body: body,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        accountKey: activeAccountKey,
      ),
    ];
    await replacePendingEvaluationSyncItems(nextItems);
  }

  Future<void> replacePendingEvaluationSyncItems(
    List<PendingEvaluationSyncItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingEvaluationSyncKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  String _evaluationsKey(String? type) {
    final normalizedType =
        type == null || type.isEmpty ? 'all' : type.trim().toLowerCase();
    return '$_evaluationsKeyPrefix$normalizedType';
  }

  String _quranChartKey({
    required String scopeKey,
    required String dimension,
    required String filtersKey,
  }) {
    final normalizedScope = scopeKey.trim().isEmpty ? 'default' : scopeKey.trim();
    final normalizedDimension =
        dimension.trim().isEmpty ? 'memorization' : dimension.trim().toLowerCase();
    final normalizedFilters = filtersKey.trim().isEmpty ? 'all' : filtersKey.trim();
    return '$_quranChartKeyPrefix$normalizedScope.$normalizedDimension.$normalizedFilters';
  }

  String _scopedKey(String prefix, String scopeKey) {
    final normalizedScope = scopeKey.trim().isEmpty ? 'default' : scopeKey.trim();
    return '$prefix$normalizedScope';
  }

  /// Removes all per-account cached data for [accountKey].
  /// Call this when a user is removed from the device so their offline
  /// data is cleaned up immediately.
  Future<void> clearAllForAccountKey(String accountKey) async {
    final trimmed = accountKey.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Remove every key whose scoped segment starts with this accountKey.
    final scopedPrefixes = [
      _userEvaluationsKeyPrefix + trimmed,
      _quranChartKeyPrefix + trimmed,
      _currentUserProfileKeyPrefix + trimmed,
      _supervisionCodeKeyPrefix + trimmed,
      _notificationsKeyPrefix + trimmed,
      _teacherRecommendationsKeyPrefix + trimmed,
    ];
    final toRemove = prefs
        .getKeys()
        .where((k) => scopedPrefixes.any((p) => k.startsWith(p)))
        .toList();
    for (final key in toRemove) {
      await prefs.remove(key);
    }

    // Strip pending evaluation sync items that belong to this account.
    final rawSync = prefs.getString(_pendingEvaluationSyncKey);
    if (rawSync != null && rawSync.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSync);
        if (decoded is List) {
          final filtered = decoded
              .whereType<Map>()
              .where((item) => item['accountKey'] != trimmed)
              .toList();
          await prefs.setString(
              _pendingEvaluationSyncKey, jsonEncode(filtered));
        }
      } catch (_) {}
    }
  }
}
