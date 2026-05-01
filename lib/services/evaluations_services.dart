import 'dart:convert';
import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

import 'offline_assessment_store.dart';

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

class EvaluationsServices {
  final SahifatyApi _sahifatyApi = SahifatyApi();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();

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

  Future<Map<String, dynamic>> getQuranChartData(
    int userId, {
    String dimension = 'memorization',
    QuranChartFilters filters = const QuranChartFilters(),
  }) async {
    try {
      final queryParameters = <String, String>{
        'dimension': dimension,
        ...filters.toQueryParameters(),
      };
      final queryString = Uri(queryParameters: queryParameters).query;
      final res =
          await _sahifatyApi.get('user-evaluations/chart/$userId?$queryString');

      if (res.statusCode == 200) {
        // Decode the full JSON map
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('service_evaluations_load_failed'.tr);
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<List<UserEvaluation>> getAllUserEvaluations(
      int userId, List<int> ayatIds) async {
    try {
      final ayatIdsParam = ayatIds.join(',');
      final http.Response res = await _sahifatyApi.get(
          'user-evaluations?userId=$userId&ayatIds=$ayatIdsParam&limit=1000');

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);

        final List<dynamic> data = body['data'] ?? [];

        // Extract only evaluation from each data item
        return data
            .map<UserEvaluation>((e) => UserEvaluation.fromJson(e))
            .toList();
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
