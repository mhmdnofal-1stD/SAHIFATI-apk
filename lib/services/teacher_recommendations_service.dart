import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/teacher_recommendation.dart';
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

class TeacherRecommendationsService {
  final SahifatyApi _sahifatyApi = SahifatyApi();

  Future<List<TeacherRecommendation>> getStudentRecommendations(
    int studentId, {
    List<int>? ayahIds,
  }) async {
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
    return data.map((item) => TeacherRecommendation.fromJson(item)).toList();
  }

  Future<http.Response> deleteRecommendation(int recommendationId) async {
    final response =
        await _sahifatyApi.delete('teacher-recommendations/$recommendationId');
    return response as http.Response;
  }
}
