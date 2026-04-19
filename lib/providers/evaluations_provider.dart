import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/controllers/ayat_controller.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/school_level_content.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/services/evaluations_services.dart';

import '../models/chart_evaluation_data.dart';

class EvaluationsProvider with ChangeNotifier {
  List<Evaluation> evaluations = [];
  List<UserEvaluation> userEvaluations = [];
  List<ChartEvaluationData> chartEvaluationData = [];
  String chartDimension = 'memorization';
  bool isLoading = true;
  bool isQuestionsLevelLoading = false;
  int totalCount = 0;
  String? _loadedQuestionsLevelKey;
  Map<String, List<Ayat>> _questionContentAyahs = {};
  Map<String, bool> _questionContentCompletion = {};
  final EvaluationsServices _evaluationsServices = EvaluationsServices();

  List<Evaluation> get memorizationEvaluations => evaluations
      .where((evaluation) =>
          evaluation.id != 0 && evaluation.type != 'comprehension')
      .toList();

  List<Evaluation> get comprehensionEvaluations => evaluations
      .where((evaluation) => evaluation.type == 'comprehension')
      .toList();

  Future<List<Evaluation?>> getAllEvaluations({String? type}) async {
    setLoading();
    evaluations = await _evaluationsServices.getAllEvaluations(type: type);
    _refreshUserEvaluationMetadata();
    resetLoading();
    return evaluations;
  }


  Future<http.Response> evaluateAyah(Map<String, dynamic> body) async {
    try {
      setLoading();
      http.Response response = await _evaluationsServices.evaluateAyah(body);
      resetLoading();
      return response;
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<http.Response> evaluateMultipleAyat(Map<String, dynamic> body) async {
    try {

      setLoading();
      http.Response response = await _evaluationsServices.evaluateMultipleAyat(body);
      resetLoading();
      return response;
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }


  Future<void> getQuranChartData(
    int userId, {
    String dimension = 'memorization',
  }) async {
    try {
      setLoading();
      chartDimension = dimension;
      chartEvaluationData.clear();
      final response = await _evaluationsServices.getQuranChartData(
        userId,
        dimension: dimension,
      );

      totalCount = response['totalVerses'];
      chartEvaluationData = (response['evaluations'] as List)
          .map<ChartEvaluationData>((e) => ChartEvaluationData.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching chart data: $e");
      }
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<void> getAllUserEvaluations(int userId, List<int> ayatIds) async {
    userEvaluations.clear();
    setLoading();
    userEvaluations =
        await _evaluationsServices.getAllUserEvaluations(userId, ayatIds);
    _refreshUserEvaluationMetadata();
    resetLoading();
  }

  Future<void> preloadQuestionLevelData(
    int userId,
    List<SchoolLevelContent> contents,
  ) async {
    final nextLevelKey = contents.map((content) => content.cacheKey).join('||');
    if (_loadedQuestionsLevelKey == nextLevelKey &&
        _questionContentAyahs.isNotEmpty) {
      return;
    }

    isQuestionsLevelLoading = true;
    notifyListeners();

    try {
      final ayatController = AyatController();
      final Map<String, List<Ayat>> ayahsByContent = {};
      final Set<int> ayahIds = <int>{};

      for (final content in contents) {
        final ayahs = await ayatController.loadAyatForContent(content);
        ayahsByContent[content.cacheKey] = ayahs;
        ayahIds.addAll(
          ayahs.where((ayah) => ayah.id != null).map((ayah) => ayah.id!),
        );
      }

      final Map<int, UserEvaluation> evaluationsByAyahId = {};
      if (ayahIds.isNotEmpty) {
        final fetchedEvaluations =
            await _evaluationsServices.getAllUserEvaluations(userId, ayahIds.toList());

        for (final evaluation in fetchedEvaluations) {
          _enrichUserEvaluation(evaluation);
          final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
          if (ayahId != null) {
            evaluationsByAyahId[ayahId] = evaluation;
          }
        }
      }

      final Map<String, bool> completionByContent = {};

      for (final entry in ayahsByContent.entries) {
        for (final ayah in entry.value) {
          if (ayah.id != null) {
            ayah.userEvaluation = evaluationsByAyahId[ayah.id!];
          }
        }

        completionByContent[entry.key] =
          entry.value.isNotEmpty &&
            entry.value.every((ayah) => ayah.userEvaluation?.hasAnyAssessment == true);
      }

      _questionContentAyahs = ayahsByContent;
      _questionContentCompletion = completionByContent;
      _loadedQuestionsLevelKey = nextLevelKey;
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading question level data: $e');
      }
      rethrow;
    } finally {
      isQuestionsLevelLoading = false;
      notifyListeners();
    }
  }

  List<Ayat> getQuestionContentAyahs(SchoolLevelContent content) {
    return _questionContentAyahs[content.cacheKey] ?? const [];
  }

  bool? getQuestionContentCompletion(SchoolLevelContent content) {
    return _questionContentCompletion[content.cacheKey];
  }

  void syncQuestionContentAyahs(
    SchoolLevelContent content,
    List<Ayat> ayahs,
  ) {
    _questionContentAyahs[content.cacheKey] = ayahs;
    _questionContentCompletion[content.cacheKey] =
        ayahs.isNotEmpty &&
            ayahs.every((ayah) => ayah.userEvaluation?.hasAnyAssessment == true);
    notifyListeners();
  }

  Evaluation? findEvaluationById(int? id) {
    if (id == null) {
      return null;
    }

    return evaluations.firstWhereOrNull((evaluation) => evaluation.id == id);
  }

  UserEvaluation? getUserEvaluationForAyah(int? ayahId) {
    if (ayahId == null) {
      return null;
    }

    return userEvaluations.firstWhereOrNull(
      (evaluation) => evaluation.ayah?.id == ayahId || evaluation.ayahId == ayahId,
    );
  }

  void upsertUserEvaluation(UserEvaluation userEvaluation) {
    _enrichUserEvaluation(userEvaluation);

    final ayahId = userEvaluation.ayah?.id ?? userEvaluation.ayahId;
    if (ayahId == null) {
      return;
    }

    final index = userEvaluations.indexWhere(
      (evaluation) => evaluation.ayah?.id == ayahId || evaluation.ayahId == ayahId,
    );

    if (index == -1) {
      userEvaluations.add(userEvaluation);
    } else {
      userEvaluations[index] = userEvaluation;
    }

    notifyListeners();
  }

  void _refreshUserEvaluationMetadata() {
    for (final userEvaluation in userEvaluations) {
      _enrichUserEvaluation(userEvaluation);
    }
  }

  void _enrichUserEvaluation(UserEvaluation userEvaluation) {
    userEvaluation.memoEvaluation =
        userEvaluation.memoEvaluation ?? findEvaluationById(userEvaluation.memoId);
    userEvaluation.compreEvaluation =
        userEvaluation.compreEvaluation ?? findEvaluationById(userEvaluation.compreId);
  }


  void setLoading() {
    isLoading = true;
    notifyListeners();
  }

  void resetLoading() {
    isLoading = false;
    notifyListeners();
  }


  String getName(int? id, LanguageProvider languageProvider) {
    isLoading = true;
    try {
      if (id == null) return '';

      final evaluation = findEvaluationById(id);

      return evaluation?.name[languageProvider.langCode] ?? '';
    } finally {
      isLoading = false;
    }
  }

}
