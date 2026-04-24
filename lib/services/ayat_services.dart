import 'dart:convert';
import 'package:get/get.dart';
import 'package:sahifaty/services/sahifaty_api.dart';

class AyatServices {
  final SahifatyApi _sahifatyApi = SahifatyApi();


  Future<Map<String, dynamic>> getAyatBySurahId(int surahId) async {
    try {
      int limit = 1000;
      final res = await _sahifatyApi.get('ayat?surahId=$surahId&limit=$limit');

      // Decode JSON body
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return data;
      } else {
        throw Exception('service_ayat_load_failed'.tr);
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByHizb(int hizb) async {
    try {
      int limit = 1000;

      final res = await _sahifatyApi.get('ayat?hizb=$hizb&limit=$limit');

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        throw Exception(
          'service_ayat_load_hizb_failed'.trParams({
            'hizb': hizb.toString(),
          }),
        );
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByJuz(int juz) async {
    try {
      int limit = 1000;
      final res = await _sahifatyApi.get('ayat?juz=$juz&limit=$limit');

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        throw Exception(
          'service_ayat_load_juz_failed'.trParams({
            'juz': juz.toString(),
          }),
        );
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAyatByRange(int surahId, int start, int end) async {
    try {
      int limit = 1000;
      final res = await _sahifatyApi.get('ayat?surahId=$surahId&fromAyah=$start&toAyah=$end&limit=$limit');

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        throw Exception('service_ayat_load_range_failed'.tr);
      }
    } catch (ex) {
      rethrow;
    }
  }
}


