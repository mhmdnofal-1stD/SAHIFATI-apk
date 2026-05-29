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

class PendingProfileSyncItem {
  const PendingProfileSyncItem({
    required this.id,
    required this.body,
    required this.createdAtMs,
    this.accountKey,
  });

  final String id;
  final Map<String, dynamic> body;
  final int createdAtMs;
  final String? accountKey;

  factory PendingProfileSyncItem.fromJson(Map<String, dynamic> json) {
    return PendingProfileSyncItem(
      id: json['id']?.toString() ?? '',
      body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      accountKey: json['accountKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'createdAtMs': createdAtMs,
      'accountKey': accountKey,
    };
  }
}

class PendingTeacherRecommendationSyncItem {
  const PendingTeacherRecommendationSyncItem({
    required this.id,
    required this.action,
    required this.studentId,
    required this.ayahId,
    required this.createdAtMs,
    this.recommendationId,
    this.accountKey,
  });

  final String id;
  final String action;
  final int studentId;
  final int ayahId;
  final int createdAtMs;
  final int? recommendationId;
  final String? accountKey;

  factory PendingTeacherRecommendationSyncItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return PendingTeacherRecommendationSyncItem(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      studentId: (json['studentId'] as num?)?.toInt() ?? 0,
      ayahId: (json['ayahId'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      recommendationId: (json['recommendationId'] as num?)?.toInt(),
      accountKey: json['accountKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'studentId': studentId,
      'ayahId': ayahId,
      'createdAtMs': createdAtMs,
      'recommendationId': recommendationId,
      'accountKey': accountKey,
    };
  }
}

class PendingProfileUpdateItem {
  const PendingProfileUpdateItem({
    required this.body,
    required this.createdAtMs,
    this.accountKey,
  });

  final Map<String, dynamic> body;
  final int createdAtMs;
  final String? accountKey;

  factory PendingProfileUpdateItem.fromJson(Map<String, dynamic> json) {
    return PendingProfileUpdateItem(
      body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      accountKey: json['accountKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'createdAtMs': createdAtMs,
      'accountKey': accountKey,
    };
  }
}

class PendingTeacherRecommendationWriteItem {
  const PendingTeacherRecommendationWriteItem({
    required this.id,
    required this.operation,
    required this.studentId,
    required this.ayahId,
    required this.createdAtMs,
    this.recommendationId,
    this.tempRecommendationId,
    this.accountKey,
  });

  final String id;
  final String operation;
  final int studentId;
  final int ayahId;
  final int createdAtMs;
  final int? recommendationId;
  final int? tempRecommendationId;
  final String? accountKey;

  factory PendingTeacherRecommendationWriteItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return PendingTeacherRecommendationWriteItem(
      id: json['id']?.toString() ?? '',
      operation: json['operation']?.toString() ?? '',
      studentId: (json['studentId'] as num?)?.toInt() ?? 0,
      ayahId: (json['ayahId'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      recommendationId: (json['recommendationId'] as num?)?.toInt(),
      tempRecommendationId: (json['tempRecommendationId'] as num?)?.toInt(),
      accountKey: json['accountKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation,
      'studentId': studentId,
      'ayahId': ayahId,
      'createdAtMs': createdAtMs,
      'recommendationId': recommendationId,
      'tempRecommendationId': tempRecommendationId,
      'accountKey': accountKey,
    }..removeWhere((key, value) => value == null);
  }
}

class OfflineAssessmentStore {
  static const String _quickQuestionsSchoolKey =
      'offline.quick_questions_school';
  static const String _pendingEvaluationSyncKey =
      'offline.pending_evaluation_sync';
    static const String _pendingProfileSyncKey =
      'offline.pending_profile_sync';
    static const String _pendingTeacherRecommendationSyncKey =
      'offline.pending_teacher_recommendation_sync';
    static const String _pendingProfileUpdateKeyPrefix =
      'offline.pending_profile_update.';
    static const String _pendingTeacherRecommendationWritesKeyPrefix =
      'offline.pending_teacher_recommendation_writes.';
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
  static const String _publicSchoolsKey = 'offline.public_schools';
  static const String _subjectsHierarchyKey = 'offline.subjects_hierarchy';
  static const String _cardsKeyPrefix = 'offline.cards.';
  static const String _cardKeyPrefix = 'offline.card.';
    static const String _supervisionLinksKeyPrefix =
      'offline.supervision_links.';
    static const String _supervisionRequestsKeyPrefix =
      'offline.supervision_requests.';
    static const String _supervisionLimitsKeyPrefix =
      'offline.supervision_limits.';
      static const String _ayatKeyPrefix = 'offline.ayat.';

  Future<void> cacheQuickQuestionsSchoolJson(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quickQuestionsSchoolKey, rawJson);
  }

  Future<String?> getCachedQuickQuestionsSchoolJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_quickQuestionsSchoolKey);
  }

  Future<void> cachePublicSchoolsJson(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_publicSchoolsKey, rawJson);
  }

  Future<String?> getCachedPublicSchoolsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_publicSchoolsKey);
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

  Future<void> cacheCardsJson({
    required String scopeKey,
    required int page,
    required String filterKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardsPageKey(scopeKey: scopeKey, page: page, filterKey: filterKey),
      rawJson,
    );
  }

  Future<String?> getCachedCardsJson({
    required String scopeKey,
    required int page,
    required String filterKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      _cardsPageKey(scopeKey: scopeKey, page: page, filterKey: filterKey),
    );
  }

  Future<void> cacheCardJson({
    required String id,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cardKeyPrefix$id', rawJson);
  }

  Future<String?> getCachedCardJson({required String id}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_cardKeyPrefix$id');
  }

  Future<void> cacheSupervisionLinksJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_supervisionLinksKeyPrefix, scopeKey),
      rawJson,
    );
  }

  Future<String?> getCachedSupervisionLinksJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_supervisionLinksKeyPrefix, scopeKey));
  }

  Future<void> cacheSupervisionRequestsJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_supervisionRequestsKeyPrefix, scopeKey),
      rawJson,
    );
  }

  Future<String?> getCachedSupervisionRequestsJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      _scopedKey(_supervisionRequestsKeyPrefix, scopeKey),
    );
  }

  Future<void> cacheSupervisionLimitsJson({
    required String scopeKey,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_supervisionLimitsKeyPrefix, scopeKey),
      rawJson,
    );
  }

  Future<String?> getCachedSupervisionLimitsJson({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_supervisionLimitsKeyPrefix, scopeKey));
  }

  Future<void> cacheAyatJson({
    required String type,
    required String key,
    required String rawJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ayatCacheKey(type: type, key: key), rawJson);
  }

  Future<String?> getCachedAyatJson({
    required String type,
    required String key,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ayatCacheKey(type: type, key: key));
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

  Future<List<PendingProfileSyncItem>> getPendingProfileSyncItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_pendingProfileSyncKey);
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
          (item) => PendingProfileSyncItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> enqueuePendingProfileUpdate({
    required Map<String, dynamic> body,
  }) async {
    final currentItems = await getPendingProfileSyncItems();
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    final nextItems = [
      ...currentItems.where((item) => item.accountKey != activeAccountKey),
      PendingProfileSyncItem(
        id: '${DateTime.now().microsecondsSinceEpoch}-profile',
        body: body,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        accountKey: activeAccountKey,
      ),
    ];
    await replacePendingProfileSyncItems(nextItems);
  }

  Future<void> replacePendingProfileSyncItems(
    List<PendingProfileSyncItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingProfileSyncKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<PendingTeacherRecommendationSyncItem>>
      getPendingTeacherRecommendationSyncItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_pendingTeacherRecommendationSyncKey);
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
          (item) => PendingTeacherRecommendationSyncItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> enqueuePendingTeacherRecommendation(
    PendingTeacherRecommendationSyncItem item,
  ) async {
    final currentItems = await getPendingTeacherRecommendationSyncItems();
    await replacePendingTeacherRecommendationSyncItems([
      ...currentItems,
      item,
    ]);
  }

  Future<void> replacePendingTeacherRecommendationSyncItems(
    List<PendingTeacherRecommendationSyncItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingTeacherRecommendationSyncKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<PendingProfileUpdateItem?> getPendingProfileUpdate({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(
      _scopedKey(_pendingProfileUpdateKeyPrefix, scopeKey),
    );
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return null;
    }

    return PendingProfileUpdateItem.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<void> setPendingProfileUpdate({
    required String scopeKey,
    required PendingProfileUpdateItem item,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_pendingProfileUpdateKeyPrefix, scopeKey),
      jsonEncode(item.toJson()),
    );
  }

  Future<void> clearPendingProfileUpdate({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_pendingProfileUpdateKeyPrefix, scopeKey));
  }

  Future<List<PendingTeacherRecommendationWriteItem>>
      getPendingTeacherRecommendationWriteItems({
    required String scopeKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(
      _scopedKey(_pendingTeacherRecommendationWritesKeyPrefix, scopeKey),
    );
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
          (item) => PendingTeacherRecommendationWriteItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> replacePendingTeacherRecommendationWriteItems({
    required String scopeKey,
    required List<PendingTeacherRecommendationWriteItem> items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_pendingTeacherRecommendationWritesKeyPrefix, scopeKey),
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

  String _cardsPageKey({
    required String scopeKey,
    required int page,
    required String filterKey,
  }) {
    final normalizedScope = scopeKey.trim().isEmpty ? 'default' : scopeKey.trim();
    final normalizedFilter = filterKey.trim().isEmpty ? 'all' : filterKey.trim();
    return '$_cardsKeyPrefix$normalizedScope.$normalizedFilter.page$page';
  }

  String _ayatCacheKey({
    required String type,
    required String key,
  }) {
    final normalizedType = type.trim().isEmpty ? 'surah' : type.trim();
    final normalizedKey = key.trim().isEmpty ? '0' : key.trim();
    return '$_ayatKeyPrefix$normalizedType.$normalizedKey';
  }

  /// Removes all per-account cached data for [accountKey].
  /// Call this when a user is removed from the device so their offline
  /// data is cleaned up immediately.
  Future<void> clearAllForAccountKey(String accountKey) async {
    final trimmed = accountKey.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    final pendingProfileItems = await getPendingProfileSyncItems();
    await replacePendingProfileSyncItems(
      pendingProfileItems.where((item) => item.accountKey != trimmed).toList(),
    );

    final pendingRecommendationItems =
        await getPendingTeacherRecommendationSyncItems();
    await replacePendingTeacherRecommendationSyncItems(
      pendingRecommendationItems
          .where((item) => item.accountKey != trimmed)
          .toList(),
    );

    // Remove every key whose scoped segment starts with this accountKey.
    final scopedPrefixes = [
      _userEvaluationsKeyPrefix + trimmed,
      _quranChartKeyPrefix + trimmed,
      _currentUserProfileKeyPrefix + trimmed,
      _supervisionCodeKeyPrefix + trimmed,
      _supervisionLinksKeyPrefix + trimmed,
      _supervisionRequestsKeyPrefix + trimmed,
      _supervisionLimitsKeyPrefix + trimmed,
      _notificationsKeyPrefix + trimmed,
      _teacherRecommendationsKeyPrefix + trimmed,
      _pendingProfileUpdateKeyPrefix + trimmed,
      _pendingTeacherRecommendationWritesKeyPrefix + trimmed,
      _cardsKeyPrefix + trimmed,
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
