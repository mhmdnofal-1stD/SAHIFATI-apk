import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
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

        throw Exception('service_school_load_failed'.tr);
      }
    } catch (ex) {
      final cachedSchool = await _loadCachedSchool();
      if (cachedSchool != null) {
        return cachedSchool;
      }

      rethrow;
    }
  }

  Future<List<School>> getAllSchools({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedSchools = await _loadCachedSchools();
      if (cachedSchools.isNotEmpty) {
        unawaited(_refreshAllSchoolsInBackground());
        return cachedSchools;
      }
    }

    return _fetchAllSchools();
  }

  /// Returns all schools that are visible to users (isVisible !== false at both
  /// school level and level level). Falls back to cache if network fails.
  Future<List<School>> getPublicSchools({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _loadCachedPublicSchools();
      if (cached.isNotEmpty) {
        unawaited(_refreshPublicSchoolsInBackground());
        return cached;
      }
    }
    return _fetchPublicSchools();
  }

  Future<List<School>> _fetchPublicSchools() async {
    try {
      final http.Response res = await _sahifatyApi.get('schools/public');
      if (res.statusCode != 200) {
        throw Exception('service_school_load_failed'.tr);
      }
      await _offlineStore.cachePublicSchoolsJson(res.body);
      return _parseSchools(res.body);
    } catch (ex) {
      final cached = await _loadCachedPublicSchools();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> _refreshPublicSchoolsInBackground() async {
    try {
      await _fetchPublicSchools();
    } catch (_) {}
  }

  Future<List<School>> _loadCachedPublicSchools() async {
    final cachedJson = await _offlineStore.getCachedPublicSchoolsJson();
    if (cachedJson == null || cachedJson.isEmpty) return const [];
    return _parseSchools(cachedJson);
  }

  Future<List<School>> _fetchAllSchools() async {
    try {
      final http.Response res = await _sahifatyApi.get('schools');

      if (res.statusCode != 200) {
        throw Exception('service_school_load_failed'.tr);
      }

      await _offlineStore.cacheSchoolsJson(res.body);

      return _parseSchools(res.body);
    } catch (ex) {
      final cachedSchools = await _loadCachedSchools();
      if (cachedSchools.isNotEmpty) {
        return cachedSchools;
      }

      rethrow;
    }
  }

  Future<void> _refreshAllSchoolsInBackground() async {
    try {
      await _fetchAllSchools();
    } catch (_) {}
  }

  List<School> _parseSchools(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => School.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
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

  Future<List<School>> _loadCachedSchools() async {
    final cachedJson = await _offlineStore.getCachedSchoolsJson();
    if (cachedJson == null || cachedJson.isEmpty) {
      return const [];
    }

    return _parseSchools(cachedJson);
  }
}
