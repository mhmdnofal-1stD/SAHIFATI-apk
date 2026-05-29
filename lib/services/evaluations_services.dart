import 'dart:convert';
import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

import 'offline_assessment_store.dart';
import 'secure_session_storage.dart';

class QuranChartFilters {
  const QuranChartFilters({
    this.thirds = const <String>[],
    this.surahIds = const <int>[],
    this.juzs = const <int>[],
    this.ayahTypes = const <String>[],
    this.subjectKeys = const <String>[],
    this.schoolIds = const <int>[],
    this.schoolLevelPairs = const <String>[],
    this.memoEvaluationIds = const <int>[],
    this.comprehensionEvaluationIds = const <int>[],
  });

  final List<String> thirds;
  final List<int> surahIds;
  final List<int> juzs;
  final List<String> ayahTypes;
  final List<String> subjectKeys;
  final List<int> schoolIds;
  final List<String> schoolLevelPairs;
  final List<int> memoEvaluationIds;
  final List<int> comprehensionEvaluationIds;

  bool get hasAnyActive =>
      thirds.isNotEmpty ||
      surahIds.isNotEmpty ||
      juzs.isNotEmpty ||
      ayahTypes.isNotEmpty ||
      subjectKeys.isNotEmpty ||
      schoolIds.isNotEmpty ||
      schoolLevelPairs.isNotEmpty ||
      memoEvaluationIds.isNotEmpty ||
      comprehensionEvaluationIds.isNotEmpty;

  List<int> _sortedInts(List<int> values) {
    final sorted = [...values];
    sorted.sort();
    return sorted;
  }

  List<String> _sortedStrings(List<String> values) {
    final sorted = [...values];
    sorted.sort((left, right) => left.compareTo(right));
    return sorted;
  }

  List<int> _effectiveJuzs() {
    final selectedJuzs = juzs.toSet();
    final thirdsJuzs = <int>{};

    for (final third in thirds) {
      switch (third) {
        case 'first':
          thirdsJuzs.addAll(List<int>.generate(10, (index) => index + 1));
          break;
        case 'second':
          thirdsJuzs.addAll(List<int>.generate(10, (index) => index + 11));
          break;
        case 'third':
          thirdsJuzs.addAll(List<int>.generate(10, (index) => index + 21));
          break;
      }
    }

    if (thirdsJuzs.isEmpty) {
      return _sortedInts(selectedJuzs.toList());
    }

    if (selectedJuzs.isEmpty) {
      return _sortedInts(thirdsJuzs.toList());
    }

    return _sortedInts(selectedJuzs.intersection(thirdsJuzs).toList());
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    final effectiveJuzs = _effectiveJuzs();

    if (surahIds.isNotEmpty) {
      params['surahIds'] = _sortedInts(surahIds).join(',');
    }
    if (effectiveJuzs.isNotEmpty) {
      params['juzs'] = effectiveJuzs.join(',');
    }
    if (ayahTypes.isNotEmpty) {
      params['ayahTypes'] = _sortedStrings(ayahTypes).join(',');
    }
    if (subjectKeys.isNotEmpty) {
      params['subjectKeys'] = _sortedStrings(subjectKeys).join(',');
    }
    if (schoolIds.isNotEmpty) {
      params['schoolIds'] = _sortedInts(schoolIds).join(',');
    }
    if (schoolLevelPairs.isNotEmpty) {
      params['schoolLevelPairs'] = _sortedStrings(schoolLevelPairs).join(',');
    }
    if (memoEvaluationIds.isNotEmpty) {
      params['memoEvaluationIds'] = _sortedInts(memoEvaluationIds).join(',');
    }
    if (comprehensionEvaluationIds.isNotEmpty) {
      params['comprehensionEvaluationIds'] =
          _sortedInts(comprehensionEvaluationIds).join(',');
    }

    return params;
  }

  String toCacheKey() {
    final query = Uri(queryParameters: toQueryParameters()).query;
    if (query.isEmpty) {
      return 'all';
    }

    return base64UrlEncode(utf8.encode(query));
  }
}

class PaginatedUserEvaluationsResponse {
  const PaginatedUserEvaluationsResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<UserEvaluation> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}

class EvaluationsServices {
  final SahifatyApi _sahifatyApi = SahifatyApi();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();

  Future<String> _resolveUserEvaluationScopeKey(int userId) async {
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    if (activeAccountKey != null && activeAccountKey.trim().isNotEmpty) {
      return '${activeAccountKey.trim()}.user_$userId';
    }

    return 'user_$userId';
  }

  Future<void> _cacheResolvedUserEvaluations(
    int userId,
    List<UserEvaluation> items,
  ) async {
    final scopeKey = await _resolveUserEvaluationScopeKey(userId);
    await _offlineStore.cacheUserEvaluationsJson(
      scopeKey: scopeKey,
      rawJson: jsonEncode(
        items.map((item) => item.toCacheJson()).toList(growable: false),
      ),
    );
  }

  Future<List<UserEvaluation>> _readCachedResolvedUserEvaluations(
    int userId,
  ) async {
    final scopeKey = await _resolveUserEvaluationScopeKey(userId);
    final rawJson = await _offlineStore.getCachedUserEvaluationsJson(
      scopeKey: scopeKey,
    );
    if (rawJson == null || rawJson.isEmpty) {
      return const <UserEvaluation>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <UserEvaluation>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => UserEvaluation.fromCacheJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <UserEvaluation>[];
    }
  }

  Future<List<UserEvaluation>> getResolvedUserEvaluations(int userId) async {
    try {
      const limit = 1000;
      var page = 1;
      var totalPages = 1;
      final collected = <UserEvaluation>[];

      while (page <= totalPages) {
        final response = await getUserEvaluationsPage(
          userId,
          limit: limit,
          page: page,
        );
        collected.addAll(response.data);
        totalPages = response.totalPages > 0 ? response.totalPages : 1;
        page += 1;
      }

      await _cacheResolvedUserEvaluations(userId, collected);
      return collected;
    } catch (_) {
      final cached = await _readCachedResolvedUserEvaluations(userId);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<Evaluation>> getAllEvaluations({String? type}) async {
    try {
      final query = type == null || type.isEmpty ? '' : '?type=$type';
      final http.Response res = await _sahifatyApi.get('evaluations$query');

      if (res.statusCode == 200) {
        await _offlineStore.cacheEvaluationsJson(res.body, type: type);
        return _parseEvaluations(res.body);
      } else {
        final cachedEvaluations = await _loadCachedEvaluations(type: type);
        if (cachedEvaluations.isNotEmpty) {
          return cachedEvaluations;
        }

        throw Exception('service_evaluations_load_failed'.tr);
      }
    } catch (ex) {
      final cachedEvaluations = await _loadCachedEvaluations(type: type);
      if (cachedEvaluations.isNotEmpty) {
        return cachedEvaluations;
      }

      rethrow;
    }
  }

  Future<http.Response> evaluateAyah(Map<String, dynamic> body) async {
    try {
      http.Response response =
          await _sahifatyApi.post(url: 'user-evaluations', body: body);
      return response;
    } catch (ex) {
      rethrow;
    }
  }

  Future<List<UserEvaluation>> getAllUserEvaluations(
    int userId, {
    List<int>? ayatIds,
    int limit = 1000,
    int page = 1,
  }) async {
    final response = await getUserEvaluationsPage(
      userId,
      ayatIds: ayatIds,
      limit: limit,
      page: page,
    );
    return response.data;
  }

  Future<PaginatedUserEvaluationsResponse> getUserEvaluationsPage(
    int userId, {
    List<int>? ayatIds,
    int limit = 1000,
    int page = 1,
  }) async {
    try {
      final queryParameters = <String, String>{
        'userId': userId.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };
      if (ayatIds != null && ayatIds.isNotEmpty) {
        queryParameters['ayatIds'] = ayatIds.join(',');
      }

      final query = Uri(queryParameters: queryParameters).query;
      final http.Response res =
          await _sahifatyApi.get('user-evaluations?$query');

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);

        final List<dynamic> data = body['data'] ?? [];

        return PaginatedUserEvaluationsResponse(
          data: data
              .map<UserEvaluation>((e) => UserEvaluation.fromJson(e))
              .toList(),
          total: (body['total'] as num?)?.toInt() ?? data.length,
          page: (body['page'] as num?)?.toInt() ?? page,
          limit: (body['limit'] as num?)?.toInt() ?? limit,
          totalPages: (body['totalPages'] as num?)?.toInt() ?? 1,
        );
      } else {
        throw Exception('service_evaluations_load_failed'.tr);
      }
    } catch (ex, stackTrace) {
      if (kDebugMode) {
        print(stackTrace);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getQuranChartPayload(
    int userId, {
    String dimension = 'memorization',
    QuranChartFilters filters = const QuranChartFilters(),
  }) async {
    try {
      final queryParameters = <String, String>{
        ...filters.toQueryParameters(),
        'dimension': dimension,
      };
      final query = Uri(queryParameters: queryParameters).query;
      final path = query.isEmpty
          ? 'user-evaluations/chart/$userId'
          : 'user-evaluations/chart/$userId?$query';
      final http.Response res = await _sahifatyApi.get(path);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic>) {
          return body;
        }
        if (body is Map) {
          return Map<String, dynamic>.from(body);
        }
      }

      throw Exception('service_evaluations_load_failed'.tr);
    } catch (ex, stackTrace) {
      if (kDebugMode) {
        print(stackTrace);
      }
      rethrow;
    }
  }

  Future<http.Response> evaluateMultipleAyat(Map<String, dynamic> body) async {
    try {
      http.Response response =
          await _sahifatyApi.post(url: 'user-evaluations/bulk', body: body);

      return response;
    } catch (ex) {
      rethrow;
    }
  }

  Future<http.Response> batchFlushEvaluations(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      return await _sahifatyApi.post(
        url: 'user-evaluations/batch-flush',
        body: {'items': items},
      );
    } catch (ex) {
      rethrow;
    }
  }

  List<Evaluation> _parseEvaluations(String rawJson) {
    final List<dynamic> data = jsonDecode(rawJson);
    return data.map<Evaluation>((e) => Evaluation.fromJson(e)).toList();
  }

  Future<List<Evaluation>> _loadCachedEvaluations({String? type}) async {
    final cachedJson = await _offlineStore.getCachedEvaluationsJson(type: type);
    if (cachedJson == null || cachedJson.isEmpty) {
      return const [];
    }

    return _parseEvaluations(cachedJson);
  }
}
