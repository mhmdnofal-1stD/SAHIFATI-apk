import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/teacher_recommendation.dart';
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

class TeacherRecommendationsService {
  final SahifatyApi _sahifatyApi = SahifatyApi();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();

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

    return TeacherRecommendationUpsertResult(
      recommendation: TeacherRecommendation.fromJson(
        Map<String, dynamic>.from(recommendationJson),
      ),
      operation: data['operation']?.toString() == 'updated'
          ? 'updated'
          : 'created',
    );
  }

  Future<http.Response> deleteRecommendation(int recommendationId) async {
    final response =
        await _sahifatyApi.delete('teacher-recommendations/$recommendationId');
    return response as http.Response;
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
