import 'dart:convert';
import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

class EvaluationsServices {
  final SahifatyApi _sahifatyApi = SahifatyApi();

  Future<List<Evaluation>> getAllEvaluations({String? type}) async {
    try {
      final query = type == null || type.isEmpty ? '' : '?type=$type';
      final http.Response res = await _sahifatyApi.get('evaluations$query');

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);

        // Map each item to Evaluation model
        return data.map<Evaluation>((e) => Evaluation.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load evaluations');
      }
    } catch (ex) {
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
        throw Exception('Failed to load evaluations');
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<List<UserEvaluation>> getAllUserEvaluations(
      int userId, List<int> ayatIds) async {
    try {
      final ayatIdsParam = ayatIds.join(',');
      final http.Response res = await _sahifatyApi
          .get('user-evaluations?userId=$userId&ayatIds=$ayatIdsParam&limit=1000');

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);

        final List<dynamic> data = body['data'] ?? [];

        // Extract only evaluation from each data item
        return data
            .map<UserEvaluation>((e) => UserEvaluation.fromJson(e))
            .toList();
      } else {
        throw Exception('Failed to load evaluations');
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
}
