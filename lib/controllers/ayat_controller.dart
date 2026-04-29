import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ayat.dart';
import '../models/school_level_content.dart';

class AyatController {
  static Future<List<Ayat>>? _cachedAyatFuture;

  Future<List<Ayat>> _loadAllAyat() {
    _cachedAyatFuture ??= _readAllAyat();
    return _cachedAyatFuture!;
  }

  Future<List<Ayat>> _readAllAyat() async {
    final String response = await rootBundle.loadString('assets/json/data.json');
    final Map<String, dynamic> jsonData = json.decode(response);
    final List<dynamic> ayahs = jsonData['data'];

    return ayahs.map((item) => Ayat.fromJson(item)).toList();
  }

  Future<List<Ayat>> loadAyatBySurah(int surahId) async {
    try {
      final ayahs = await _loadAllAyat();

      return ayahs.where((item) => item.surah.id == surahId).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Ayat>> loadAyatByHizb(int hizb) async {
    final ayahs = await _loadAllAyat();

    return ayahs.where((item) => item.hizb == hizb).toList();
  }

  Future<List<Ayat>> loadAyatByHizbQuarter(int hizbQuarter) async {
    final ayahs = await _loadAllAyat();

    return ayahs.where((item) => item.hizbQuarter == hizbQuarter).toList();
  }

  Future<List<Ayat>> loadAyatByJuz(int juz) async {
    final ayahs = await _loadAllAyat();

    return ayahs.where((item) => item.juz == juz).toList();
  }

  Future<List<Ayat>> loadAyatByPage(int page) async {
    final ayahs = await _loadAllAyat();

    return ayahs.where((item) => item.page == page).toList();
  }

  Future<List<Ayat>> loadAllAyat() => _loadAllAyat();

  Future<List<Ayat>> loadAyatByRange(int surahId, int startAyah, int endAyah) async {
    if (kDebugMode) {
      print("AyatController: loadAyatByRange called with surahId: $surahId, start: $startAyah, end: $endAyah");
    }
    final ayahs = await _loadAllAyat();
    if (kDebugMode) {
      print("AyatController: Loaded ${ayahs.length} ayahs from JSON");
    }

    // Filter and map to Surah objects
    final List<Ayat> rangeAyat = ayahs
        .where((item) {
            final itemSurahId = item.surah.id;
            final itemAyahNo = item.ayahNo;
            final match = itemSurahId == surahId &&
            itemAyahNo >= startAyah &&
            itemAyahNo <= endAyah;
            return match;
        })
        .toList();
    
    if (kDebugMode) {
      print("AyatController: Returning ${rangeAyat.length} ayahs");
    }
    return rangeAyat;
  }

  Future<List<Ayat>> loadAyatForContent(SchoolLevelContent content) async {
    if (content.startAyah != null &&
        content.endAyah != null &&
        content.surahId != null) {
      return loadAyatByRange(
        content.surahId!,
        content.startAyah!,
        content.endAyah!,
      );
    }

    if (content.type.contains('surah') && content.surahId != null) {
      return loadAyatBySurah(content.surahId!);
    }

    if (content.type.contains('hizb') && content.hizb != null) {
      return loadAyatByHizb(content.hizb!);
    }

    if (content.type.contains('hizbQuarter') && content.hizbQuarter != null) {
      return loadAyatByHizbQuarter(content.hizbQuarter!);
    }

    if (content.type.contains('juz') && content.juz != null) {
      return loadAyatByJuz(content.juz!);
    }

    return [];
  }

}
