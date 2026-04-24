import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sahifaty/services/sahifaty_api.dart';

import 'offline_assessment_store.dart';
import '../models/school.dart';

class SchoolServices {
  final _sahifatyApi = SahifatyApi();
  final _offlineStore = OfflineAssessmentStore();

  Future<School> getQuickQuestionsSchool() async {
    try {
      final http.Response res = await _sahifatyApi.get('schools/1');

      if (res.statusCode == 200) {
        await _offlineStore.cacheQuickQuestionsSchoolJson(res.body);
        return _parseSchool(res.body);
      } else {
        final cachedSchool = await _loadCachedSchool();
        if (cachedSchool != null) {
          return cachedSchool;
        }

        throw Exception('Failed to load school data');
      }
    } catch (ex) {
      final cachedSchool = await _loadCachedSchool();
      if (cachedSchool != null) {
        return cachedSchool;
      }

      rethrow;
    }
  }

  School _parseSchool(String rawJson) {
    final Map<String, dynamic> data = jsonDecode(rawJson);
    return School.fromJson(data);
  }

  Future<School?> _loadCachedSchool() async {
    final cachedJson = await _offlineStore.getCachedQuickQuestionsSchoolJson();
    if (cachedJson == null || cachedJson.isEmpty) {
      return null;
    }

    return _parseSchool(cachedJson);
  }
}
