import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sahifaty/controllers/general_controller.dart';
import 'package:sahifaty/services/ayat_services.dart';
import 'package:sahifaty/services/localization_service.dart';
import '../models/ayat.dart';
import '../models/evaluation.dart';
import '../models/school_level_content.dart';
import '../controllers/evaluations_controller.dart';
import '../providers/evaluations_provider.dart';

class AyatProvider with ChangeNotifier {
  List<Ayat> surahAyat = [];
  int surahAyatTotalPages = 1;
  int surahAyatTotalCount = 1;
  bool isLoading = false;
  final AyatServices _ayatServices = AyatServices();

  Future<void> getAyatBySurahId(int surahId) async {
    setLoading();

    try {
      Map<String, dynamic> res;
      final hasConnection = await GeneralController().checkConnectivity();

      if (!hasConnection) {
        // 📴 No internet → Load from local JSON
        final String jsonString =
            await rootBundle.loadString('assets/json/data.json');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        final List<dynamic> allAyat = jsonMap['data'] ?? [];

        // 🔍 Filter by surah.id
        final filteredAyat = allAyat.where((ayah) {
          final surah = ayah['surah'];
          return surah != null && surah['id'] == surahId;
        }).toList();

        res = {
          'data': filteredAyat,
          'totalPages': 1,
          'total': filteredAyat.length,
        };
      } else {
        // 🌐 Online → Load from API
        final locale = await LocalizationService.getCurrentLocale();
        res = await _ayatServices.getAyatBySurahId(
          surahId,
          languageCode: locale.languageCode,
        );
      }

      var data = res['data'];
      if (data is! List) {
        throw Exception('Unexpected response format: expected a list');
      }

      // 🧩 Map to your Ayat model
      surahAyat = data.map<Ayat>((ayah) => Ayat.fromJson(ayah)).toList();
      surahAyatTotalPages = res['totalPages'];
      surahAyatTotalCount = res['total'];
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error loading Ayat: $e");
      }
    } finally {
      resetLoading();
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

  Future<void> evaluateAll(List<Ayat> ayahs, Evaluation evaluation, EvaluationsProvider evaluationsProvider) async {
    for (var ayah in ayahs) {
        // Optimistically update local state if needed, but the controller handles sending
        // We might want to batch this or just loop calls. 
        // For now, loop calls as per existing pattern, but maybe we should add a bulk endpoint later.
        // The user request implies UI capability, not necessarily backend bulk endpoint yet.
        // We will loop for now.
        await EvaluationsController().sendEvaluation(ayah, evaluation, evaluationsProvider, this);
    }
  }

  Future<List<Ayat>> fetchAyatForContent(SchoolLevelContent content) async {
    try {

      final String jsonString = await rootBundle.loadString('assets/json/data.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final List<dynamic> allAyat = jsonMap['data'] ?? [];
      if (allAyat.isNotEmpty) {
      }
      
      List<dynamic> filteredData = [];

      if (content.type == 'surah' && content.surahId != null) {
        filteredData = allAyat.where((ayah) => ayah['surah']['id'] == content.surahId).toList();
      } else if (content.type == 'hizb' && content.hizb != null) {
        filteredData = allAyat.where((ayah) => ayah['hizb'] == content.hizb).toList();
      } else if (content.type == 'juz' && content.juz != null) {
        filteredData = allAyat.where((ayah) => ayah['juz'] == content.juz).toList();
      } else if ((content.type == 'ayatRange' || content.type == 'ayat-range') &&
          content.surahId != null &&
          content.startAyah != null &&
          content.endAyah != null) {
        filteredData = allAyat.where((ayah) {
          return ayah['surah']['id'] == content.surahId &&
                 ayah['ayahNo'] >= content.startAyah! &&
                 ayah['ayahNo'] <= content.endAyah!;
        }).toList();
      }
      

      return filteredData.map<Ayat>((ayah) => Ayat.fromJson(ayah)).toList();
    } catch (e) {
      return [];
    }
  }

  void resetForAccountSwitch() {
    surahAyat = [];
    surahAyatTotalPages = 1;
    surahAyatTotalCount = 1;
    isLoading = false;
    notifyListeners();
  }
}
