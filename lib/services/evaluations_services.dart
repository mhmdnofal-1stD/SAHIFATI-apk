import 'dart:convert';
import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

import 'offline_assessment_store.dart';

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
  }) async {
    try {
      final res = await _sahifatyApi
          .get('user-evaluations/chart/$userId?dimension=$dimension');

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
