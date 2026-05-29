import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/services/app_exception.dart';
import 'package:sahifaty/services/offline_assessment_store.dart';
import 'package:sahifaty/services/secure_session_storage.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

String buildTeacherRecommendationsPath(
  int studentId, {
  List<int>? ayahIds,
}) {
  final queryParametersAll = <String, List<String>>{
    'studentId': [studentId.toString()],
  };

  if (ayahIds != null && ayahIds.isNotEmpty) {
    queryParametersAll['ayahIds'] =
        ayahIds.map((ayahId) => ayahId.toString()).toList();
  }

  return Uri(
    path: 'teacher-recommendations',
    queryParameters: queryParametersAll,
  ).toString();
}

class TeacherRecommendationUpsertResult {
  const TeacherRecommendationUpsertResult({
    required this.recommendation,
    required this.operation,
  });

  final TeacherRecommendation recommendation;
  final String operation;
}

class TeacherRecommendationBulkUpsertResult {
  const TeacherRecommendationBulkUpsertResult({
    required this.created,
    required this.updated,
    required this.recommendations,
  });

  final int created;
  final int updated;
  final List<TeacherRecommendation> recommendations;
}

class TeacherRecommendationsService {
  final SahifatyApi _sahifatyApi = SahifatyApi();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();

  bool _isOfflineException(Object error) => error is FetchDataException;

  int _nextLocalRecommendationId() {
    return -DateTime.now().microsecondsSinceEpoch;
  }

  TeacherRecommendation _buildQueuedRecommendation({
    required int studentId,
    required int ayahId,
    int? id,
  }) {
    final now = DateTime.now();
    return TeacherRecommendation(
      id: id ?? _nextLocalRecommendationId(),
      teacherId: 0,
      studentId: studentId,
      ayahId: ayahId,
      source: 'teacher',
      status: 'active',
      notified: 'pending',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _enqueuePendingCreate({
    required String scopeKey,
    required int studentId,
    required int ayahId,
    required int tempRecommendationId,
  }) async {
    final currentItems = await _offlineStore
        .getPendingTeacherRecommendationWriteItems(scopeKey: scopeKey);
    final nextItems = [
      ...currentItems,
      PendingTeacherRecommendationWriteItem(
        id: '${DateTime.now().microsecondsSinceEpoch}-rec-create-$ayahId',
        operation: 'create',
        studentId: studentId,
        ayahId: ayahId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        tempRecommendationId: tempRecommendationId,
        accountKey: await SecureSessionStorage.readActiveAccountKey(),
      ),
    ];
    await _offlineStore.replacePendingTeacherRecommendationWriteItems(
      scopeKey: scopeKey,
      items: nextItems,
    );
  }

  Future<void> _enqueuePendingDelete({
    required String scopeKey,
    required TeacherRecommendation recommendation,
  }) async {
    final currentItems = await _offlineStore
        .getPendingTeacherRecommendationWriteItems(scopeKey: scopeKey);
    final nextItems = [
      ...currentItems,
      PendingTeacherRecommendationWriteItem(
        id: '${DateTime.now().microsecondsSinceEpoch}-rec-delete-${recommendation.id}',
        operation: 'delete',
        studentId: recommendation.studentId,
        ayahId: recommendation.ayahId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        recommendationId: recommendation.id,
        accountKey: await SecureSessionStorage.readActiveAccountKey(),
      ),
    ];
    await _offlineStore.replacePendingTeacherRecommendationWriteItems(
      scopeKey: scopeKey,
      items: nextItems,
    );
  }

  Future<void> _removeQueuedCreateForTempRecommendation({
    required String scopeKey,
    required int tempRecommendationId,
  }) async {
    final currentItems = await _offlineStore
        .getPendingTeacherRecommendationWriteItems(scopeKey: scopeKey);
    final nextItems = currentItems
        .where((item) => item.tempRecommendationId != tempRecommendationId)
        .toList(growable: false);
    await _offlineStore.replacePendingTeacherRecommendationWriteItems(
      scopeKey: scopeKey,
      items: nextItems,
    );
  }

  Future<void> _replaceCachedStudentRecommendations(
    int studentId,
    List<TeacherRecommendation> recommendations,
  ) async {
    final scopeKey = await _resolveActiveCacheScopeKey();
    await _offlineStore.cacheTeacherRecommendationsJson(
      scopeKey: scopeKey,
      studentId: studentId,
      rawJson: jsonEncode(
        recommendations.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  Future<void> _upsertCachedRecommendation(
    TeacherRecommendation recommendation,
  ) async {
    final current = await getCachedStudentRecommendations(
          recommendation.studentId,
        ) ??
        <TeacherRecommendation>[];
    final next = [
      ...current.where((item) => item.id != recommendation.id),
      recommendation,
    ];
    await _replaceCachedStudentRecommendations(recommendation.studentId, next);
  }

  Future<void> _removeCachedRecommendation(
    TeacherRecommendation recommendation,
  ) async {
    final current = await getCachedStudentRecommendations(
          recommendation.studentId,
        ) ??
        <TeacherRecommendation>[];
    final next = current
        .where((item) => item.id != recommendation.id)
        .toList(growable: false);
    await _replaceCachedStudentRecommendations(recommendation.studentId, next);
  }

  Future<void> syncPendingWrites() async {
    final scopeKey = await _resolveActiveCacheScopeKey();
    final pendingItems = await _offlineStore
        .getPendingTeacherRecommendationWriteItems(scopeKey: scopeKey);
    if (pendingItems.isEmpty) {
      return;
    }

    final remaining = <PendingTeacherRecommendationWriteItem>[];
    for (final item in pendingItems) {
      try {
        if (item.operation == 'create') {
          final response = await _sahifatyApi.post(
            url: 'teacher-recommendations',
            body: {
              'studentId': item.studentId,
              'ayahId': item.ayahId,
            },
          );
          final decoded =
              response.body.isEmpty ? null : jsonDecode(response.body);
          if ((response.statusCode == 200 || response.statusCode == 201) &&
              decoded is Map &&
              decoded['recommendation'] is Map) {
            final recommendation = TeacherRecommendation.fromJson(
              Map<String, dynamic>.from(decoded['recommendation'] as Map),
            );
            final current = await getCachedStudentRecommendations(
                  item.studentId,
                ) ??
                <TeacherRecommendation>[];
            final next = current
                .map(
                  (recommendationItem) => recommendationItem.id == item.tempRecommendationId
                      ? recommendation
                      : recommendationItem,
                )
                .toList(growable: false);
            await _replaceCachedStudentRecommendations(item.studentId, next);
            continue;
          }
        } else if (item.operation == 'delete' &&
            item.recommendationId != null &&
            item.recommendationId! > 0) {
          final response = await _sahifatyApi.delete(
            'teacher-recommendations/${item.recommendationId}',
          );
          if (response is http.Response &&
              (response.statusCode == 200 || response.statusCode == 204)) {
            continue;
          }
        } else {
          continue;
        }
      } catch (_) {}

      remaining.add(item);
    }

    await _offlineStore.replacePendingTeacherRecommendationWriteItems(
      scopeKey: scopeKey,
      items: remaining,
    );
  }

  Future<String> _resolveActiveCacheScopeKey() async {
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    if (activeAccountKey != null && activeAccountKey.trim().isNotEmpty) {
      return activeAccountKey.trim();
    }

    return 'default';
  }

  Future<List<TeacherRecommendation>?> getCachedStudentRecommendations(
    int studentId, {
    List<int>? ayahIds,
  }) async {
    final scopeKey = await _resolveActiveCacheScopeKey();
    return _readCachedStudentRecommendations(
      scopeKey: scopeKey,
      studentId: studentId,
      ayahIds: ayahIds,
    );
  }

  Future<void> refreshStudentRecommendationsInBackground(
    int studentId, {
    List<int>? ayahIds,
    void Function(List<TeacherRecommendation> recommendations)? onUpdated,
  }) async {
    try {
      final recommendations = await getStudentRecommendations(
        studentId,
        ayahIds: ayahIds,
      );
      onUpdated?.call(recommendations);
    } catch (error) {
      debugPrint('Teacher recommendations background refresh skipped: $error');
    }
  }

  Future<List<TeacherRecommendation>> getStudentRecommendations(
    int studentId, {
    List<int>? ayahIds,
  }) async {
    try {
      try {
        await syncPendingWrites();
      } catch (_) {}

      final res = await _sahifatyApi.get(
        buildTeacherRecommendationsPath(
          studentId,
          ayahIds: ayahIds,
        ),
      );

      if (res.statusCode != 200) {
        throw Exception('service_teacher_recommendations_load_failed'.tr);
      }

      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      final recommendations = data
          .map((item) => TeacherRecommendation.fromJson(item))
          .toList();
      await _cacheStudentRecommendations(
        studentId: studentId,
        ayahIds: ayahIds,
        recommendations: recommendations,
      );
      return recommendations;
    } catch (_) {
      final cached = await getCachedStudentRecommendations(
        studentId,
        ayahIds: ayahIds,
      );
      if (cached != null) {
        return cached;
      }

      rethrow;
    }
  }

  Future<TeacherRecommendationUpsertResult> createRecommendation({
    required int studentId,
    required int ayahId,
  }) async {
    try {
      final response = await _sahifatyApi.post(
        url: 'teacher-recommendations',
        body: {
          'studentId': studentId,
          'ayahId': ayahId,
        },
      );

      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractCreateErrorMessage(decoded));
      }

      if (decoded is! Map) {
        throw Exception('service_teacher_recommendations_create_failed'.tr);
      }

      final data = Map<String, dynamic>.from(decoded);
      final recommendationJson = data['recommendation'];
      if (recommendationJson is! Map) {
        throw Exception('service_teacher_recommendations_create_failed'.tr);
      }

      final recommendation = TeacherRecommendation.fromJson(
        Map<String, dynamic>.from(recommendationJson),
      );
      await _upsertCachedRecommendation(recommendation);
      return TeacherRecommendationUpsertResult(
        recommendation: recommendation,
        operation: data['operation']?.toString() == 'updated'
            ? 'updated'
            : 'created',
      );
    } catch (error) {
      if (!_isOfflineException(error)) {
        rethrow;
      }

      final scopeKey = await _resolveActiveCacheScopeKey();
      final queuedRecommendation = _buildQueuedRecommendation(
        studentId: studentId,
        ayahId: ayahId,
      );
      await _enqueuePendingCreate(
        scopeKey: scopeKey,
        studentId: studentId,
        ayahId: ayahId,
        tempRecommendationId: queuedRecommendation.id,
      );
      await _upsertCachedRecommendation(queuedRecommendation);
      return TeacherRecommendationUpsertResult(
        recommendation: queuedRecommendation,
        operation: 'created',
      );
    }
  }

  Future<TeacherRecommendationBulkUpsertResult> createRecommendationsBulk({
    required int studentId,
    required List<int> ayahIds,
  }) async {
    try {
      final response = await _sahifatyApi.post(
        url: 'teacher-recommendations/bulk',
        body: {
          'studentId': studentId,
          'ayahIds': ayahIds,
        },
      );

      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_extractCreateErrorMessage(decoded));
      }

      if (decoded is! Map) {
        throw Exception('service_teacher_recommendations_create_failed'.tr);
      }

      final data = Map<String, dynamic>.from(decoded);
      final recommendations = (data['recommendations'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => TeacherRecommendation.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList() ??
          const <TeacherRecommendation>[];
      for (final recommendation in recommendations) {
        await _upsertCachedRecommendation(recommendation);
      }

      return TeacherRecommendationBulkUpsertResult(
        created: (data['created'] as num?)?.toInt() ?? 0,
        updated: (data['updated'] as num?)?.toInt() ?? 0,
        recommendations: recommendations,
      );
    } catch (error) {
      if (!_isOfflineException(error)) {
        rethrow;
      }

      final scopeKey = await _resolveActiveCacheScopeKey();
      final queuedRecommendations = ayahIds
          .map(
            (ayahId) => _buildQueuedRecommendation(
              studentId: studentId,
              ayahId: ayahId,
            ),
          )
          .toList(growable: false);
      for (final recommendation in queuedRecommendations) {
        await _enqueuePendingCreate(
          scopeKey: scopeKey,
          studentId: studentId,
          ayahId: recommendation.ayahId,
          tempRecommendationId: recommendation.id,
        );
      }
      await _cacheStudentRecommendations(
        studentId: studentId,
        ayahIds: ayahIds,
        recommendations: queuedRecommendations,
      );
      return TeacherRecommendationBulkUpsertResult(
        created: queuedRecommendations.length,
        updated: 0,
        recommendations: queuedRecommendations,
      );
    }
  }

  Future<http.Response> deleteRecommendation(
    TeacherRecommendation recommendation,
  ) async {
    final scopeKey = await _resolveActiveCacheScopeKey();
    if (recommendation.id <= 0) {
      await _removeQueuedCreateForTempRecommendation(
        scopeKey: scopeKey,
        tempRecommendationId: recommendation.id,
      );
      await _removeCachedRecommendation(recommendation);
      return http.Response('', 204);
    }

    try {
      final response = await _sahifatyApi.delete(
        'teacher-recommendations/${recommendation.id}',
      );
      if (response is http.Response &&
          (response.statusCode == 200 || response.statusCode == 204)) {
        await _removeCachedRecommendation(recommendation);
      }
      return response as http.Response;
    } catch (error) {
      if (!_isOfflineException(error)) {
        rethrow;
      }

      await _enqueuePendingDelete(
        scopeKey: scopeKey,
        recommendation: recommendation,
      );
      await _removeCachedRecommendation(recommendation);
      return http.Response('', 204);
    }
  }

  Future<List<TeacherRecommendation>?> _readCachedStudentRecommendations({
    required String scopeKey,
    required int studentId,
    List<int>? ayahIds,
  }) async {
    final rawJson = await _offlineStore.getCachedTeacherRecommendationsJson(
      scopeKey: scopeKey,
      studentId: studentId,
    );
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return null;
      }

      final cached = decoded
          .whereType<Map>()
          .map(
            (item) => TeacherRecommendation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      return _filterRecommendations(cached, ayahIds: ayahIds);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheStudentRecommendations({
    required int studentId,
    List<int>? ayahIds,
    required List<TeacherRecommendation> recommendations,
  }) async {
    final scopeKey = await _resolveActiveCacheScopeKey();
    final cachedAll = await _readCachedStudentRecommendations(
          scopeKey: scopeKey,
          studentId: studentId,
        ) ??
        <TeacherRecommendation>[];

    final nextRecommendations = ayahIds == null
        ? recommendations
        : [
            ...cachedAll.where(
              (item) => !ayahIds.contains(item.ayahId),
            ),
            ...recommendations,
          ];

    await _offlineStore.cacheTeacherRecommendationsJson(
      scopeKey: scopeKey,
      studentId: studentId,
      rawJson: jsonEncode(
        nextRecommendations.map((item) => item.toJson()).toList(),
      ),
    );
  }

  List<TeacherRecommendation> _filterRecommendations(
    List<TeacherRecommendation> recommendations, {
    List<int>? ayahIds,
  }) {
    if (ayahIds == null || ayahIds.isEmpty) {
      return recommendations;
    }

    final ayahIdSet = ayahIds.toSet();
    return recommendations
        .where((item) => ayahIdSet.contains(item.ayahId))
        .toList();
  }

  String _extractCreateErrorMessage(dynamic decoded) {
    if (decoded is Map) {
      final data = Map<String, dynamic>.from(decoded);
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List) {
        final joined = message
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join('\n');
        if (joined.isNotEmpty) {
          return joined;
        }
      }
    }

    return 'service_teacher_recommendations_create_failed'.tr;
  }
}
