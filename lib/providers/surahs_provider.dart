import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/services/surahs_services.dart';


class SurahsProvider with ChangeNotifier {
  List<Surah> surahsByJuz = [];
  int totalSurahs = 1;
  bool isLoading = false;
  String? hizbLoadError;
  final SurahsServices _surahsServices = SurahsServices();
  final Map<int, List<Surah>> hizbSurahs = {};

  Future<void> getSurahsByJuz(int juz) async {
    setLoading();
    var res = await _surahsServices.getSurahsByJuz(juz);
    var data = res['data'];
    if (data is! List) {
      throw Exception('Unexpected response format: expected a list');
    }
    surahsByJuz = data.map<Surah>((surah) => Surah.fromJson(surah)).toList();
    totalSurahs = res['total'];
    resetLoading();
  }

  Future<void> loadAllHizbSurahs(
    List<Map<String, dynamic>> hizbs, {
    bool force = false,
  }) async {
    if (!force && hizbSurahs.length == hizbs.length && hizbLoadError == null) {
      return;
    }

    isLoading = true;
    hizbLoadError = null;
    if (force) {
      hizbSurahs.clear();
    }
    notifyListeners();

    try {
      final String response = await rootBundle.loadString('assets/json/data.json');
      final Map<String, dynamic> jsonData = json.decode(response);
      final List<dynamic> ayahs = jsonData['data'];
      final Map<int, List<Surah>> loadedHizbs = {};

      for (var hizb in hizbs) {
        int hizbId = hizb['id'];
        final List<Surah> allSurahs = ayahs
            .where((item) => item['hizb'] == hizbId)
            .map((item) => Surah.fromJson(item['surah']))
            .toList();

        final uniqueSurahs = {
          for (var surah in allSurahs) surah.id: surah,
        }.values.toList();

        loadedHizbs[hizbId] = uniqueSurahs;
      }

      hizbSurahs
        ..clear()
        ..addAll(loadedHizbs);
    } catch (e) {
      hizbSurahs.clear();
      hizbLoadError = e.toString().replaceFirst('Exception: ', '').trim();
      debugPrint('Error loading hizbs: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  void setLoading() {
    isLoading = true;
    notifyListeners();
  }

  void resetLoading() {
    isLoading = false;
    notifyListeners();
  }

  void resetForAccountSwitch() {
    surahsByJuz = [];
    totalSurahs = 1;
    hizbSurahs.clear();
    hizbLoadError = null;
    isLoading = false;
    notifyListeners();
  }
}

