import 'dart:convert';
import 'package:get/get.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

class AyatServices {
  final SahifatyApi _sahifatyApi = SahifatyApi();

  String _buildAyatQuery(Map<String, String> queryParameters) {
    return 'ayat?${Uri(queryParameters: queryParameters).query}';
  }

  Future<Map<String, dynamic>> _getAyat(
    Map<String, String> queryParameters,
  ) async {
    final res = await _sahifatyApi.get(_buildAyatQuery(queryParameters));

    if (res.statusCode == 200) {
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
      });
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
      });
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
      });
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
      });
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
      });
    } catch (ex) {
      rethrow;
    }
  }
}


