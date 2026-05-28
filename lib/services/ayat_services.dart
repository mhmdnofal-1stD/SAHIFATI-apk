import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import 'offline_assessment_store.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

class AyatServices {
  final SahifatyApi _sahifatyApi = SahifatyApi();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();

  String _buildAyatQuery(Map<String, String> queryParameters) {
    return 'ayat?${Uri(queryParameters: queryParameters).query}';
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<Map<String, dynamic>> _getAyat(
    Map<String, String> queryParameters,
    {
    required String type,
    required String key,
  }
  ) async {
    if (!await _isOnline()) {
      final cached = await _offlineStore.getCachedAyatJson(
        type: type,
        key: key,
      );
      if (cached != null && cached.isNotEmpty) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
      throw Exception('service_ayat_load_failed'.tr);
    }

    final res = await _sahifatyApi.get(_buildAyatQuery(queryParameters));

    if (res.statusCode == 200) {
      await _offlineStore.cacheAyatJson(
        type: type,
        key: key,
        rawJson: res.body,
      );
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('service_ayat_load_failed'.tr);
  }

  Future<Map<String, dynamic>> getAyatBySurahId(
    int surahId, {
    String? languageCode,
  }) async {
    try {
      return _getAyat({
        'surahId': surahId.toString(),
        'limit': '1000',
        if (languageCode != null && languageCode.isNotEmpty)
          'language': languageCode,
      }, type: 'surah', key: surahId.toString());
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByHizb(
    int hizb, {
    String? languageCode,
  }) async {
    try {
      return _getAyat({
        'hizb': hizb.toString(),
        'limit': '1000',
        if (languageCode != null && languageCode.isNotEmpty)
          'language': languageCode,
      }, type: 'hizb', key: hizb.toString());
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByHizbQuarter(
    int hizbQuarter, {
    String? languageCode,
  }) async {
    try {
      return _getAyat({
        'hizbQuarter': hizbQuarter.toString(),
        'limit': '1000',
        if (languageCode != null && languageCode.isNotEmpty)
          'language': languageCode,
      }, type: 'hizbQuarter', key: hizbQuarter.toString());
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByJuz(
    int juz, {
    String? languageCode,
  }) async {
    try {
      return _getAyat({
        'juz': juz.toString(),
        'limit': '1000',
        if (languageCode != null && languageCode.isNotEmpty)
          'language': languageCode,
      }, type: 'juz', key: juz.toString());
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByPage(
    int page, {
    String? languageCode,
  }) async {
    try {
      return _getAyat({
        'mushafPage': page.toString(),
        'limit': '1000',
        if (languageCode != null && languageCode.isNotEmpty)
          'language': languageCode,
      }, type: 'page', key: page.toString());
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByRange(
    int startId,
    int endId, {
    String? languageCode,
  }) async {
    try {
      return _getAyat({
        'startId': startId.toString(),
        'endId': endId.toString(),
        'limit': '1000',
        if (languageCode != null && languageCode.isNotEmpty)
          'language': languageCode,
      }, type: 'range', key: '$startId-$endId');
    } catch (ex) {
      rethrow;
    }
  }
}


