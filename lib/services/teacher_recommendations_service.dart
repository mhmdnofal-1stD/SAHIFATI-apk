import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

class TeacherRecommendationsService {
  final SahifatyApi _sahifatyApi = SahifatyApi();

  Future<List<TeacherRecommendation>> getStudentRecommendations(
    int studentId, {
    List<int>? ayahIds,
  }) async {
    final queryParts = <String>['studentId=$studentId'];
    if (ayahIds != null && ayahIds.isNotEmpty) {
      queryParts.add('ayahIds=${ayahIds.join(',')}');
    }

    final res = await _sahifatyApi
        .get('teacher-recommendations?${queryParts.join('&')}');

    if (res.statusCode != 200) {
      throw Exception('Failed to load teacher recommendations');
    }

    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data.map((item) => TeacherRecommendation.fromJson(item)).toList();
  }

  Future<http.Response> deleteRecommendation(int recommendationId) async {
    final response =
        await _sahifatyApi.delete('teacher-recommendations/$recommendationId');
    return response as http.Response;
  }
}
