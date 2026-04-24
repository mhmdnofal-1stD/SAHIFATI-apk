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
}
