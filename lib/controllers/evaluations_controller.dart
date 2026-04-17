import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/providers/ayat_provider.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:http/http.dart' as http;
import '../core/constants/colors.dart';
import '../models/ayat.dart';
import '../models/chart_evaluation_data.dart';
import '../models/user_evaluation.dart';

import 'package:get/get.dart';

class EvaluationsController {
  static final EvaluationsController _instance =
      EvaluationsController._internal();



  factory EvaluationsController() => _instance;

  EvaluationsController._internal();

  static const String memorizationDimension = 'memorization';
  static const String comprehensionDimension = 'comprehension';

  Future<void> sendEvaluation(
      Ayat verse,
      Evaluation evaluation,
      EvaluationsProvider evaluationsProvider,
      AyatProvider? ayatProvider,
      {bool clearSelection = false}) async {
    final isComprehension = evaluation.type == comprehensionDimension;

    await sendEvaluationSelection(
      verse,
      evaluationsProvider,
      ayatProvider,
      memoId: isComprehension ? null : (clearSelection ? null : evaluation.id),
      compreId:
          isComprehension ? (clearSelection ? null : evaluation.id) : null,
      memoChanged: !isComprehension,
      compreChanged: isComprehension,
    );
  }

  Future<void> sendEvaluationSelection(
      Ayat verse,
      EvaluationsProvider evaluationsProvider,
      AyatProvider? ayatProvider,
      {int? memoId,
      int? compreId,
      required bool memoChanged,
      required bool compreChanged}) async {
    if (!memoChanged && !compreChanged) {
      return;
    }

    try {
      final Map<String, dynamic> userEvaluation = buildSinglePayload(
        ayahId: verse.id!,
        memoId: memoId,
        compreId: compreId,
        includeMemo: memoChanged,
        includeCompre: compreChanged,
        clearMemo: memoChanged && memoId == null,
        clearCompre: compreChanged && compreId == null,
      );

      final http.Response response =
          await evaluationsProvider.evaluateAyah(userEvaluation);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: 'eval_success_verse'.tr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        // increment evaluated verses if coming from questions screen
        // if(ayatProvider != null) {
        //   ayatProvider.incrementEvaluatedVersesCount();
        // }
      } else {
        await evaluationsProvider.evaluateAyah(userEvaluation);

        Fluttertoast.showToast(
          msg: 'eval_error'.tr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'generic_error'.tr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> sendMultipleEvaluations(
      List<Ayat> verses,
      Evaluation evaluation,
      EvaluationsProvider evaluationsProvider,
      AyatProvider? ayatProvider,
      String unitName,
      {bool clearSelection = false}) async {
    final isComprehension = evaluation.type == comprehensionDimension;

    await sendMultipleEvaluationSelection(
      verses,
      evaluationsProvider,
      ayatProvider,
      unitName,
      memoId: isComprehension ? null : (clearSelection ? null : evaluation.id),
      compreId:
          isComprehension ? (clearSelection ? null : evaluation.id) : null,
      memoChanged: !isComprehension,
      compreChanged: isComprehension,
    );
  }

  Future<void> sendMultipleEvaluationSelection(
      List<Ayat> verses,
      EvaluationsProvider evaluationsProvider,
      AyatProvider? ayatProvider,
      String unitName,
      {int? memoId,
      int? compreId,
      required bool memoChanged,
      required bool compreChanged}) async {
    if (!memoChanged && !compreChanged) {
      return;
    }

    try {
      final ayatIds = verses.map((v) => v.id!).toList();
      final Map<String, dynamic> userEvaluation = buildBulkPayload(
        ayahIds: ayatIds,
        memoId: memoId,
        compreId: compreId,
        includeMemo: memoChanged,
        includeCompre: compreChanged,
        clearMemo: memoChanged && memoId == null,
        clearCompre: compreChanged && compreId == null,
      );

      final http.Response response =
          await evaluationsProvider.evaluateMultipleAyat(userEvaluation);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: 'eval_success_unit'.trParams({'unit': unitName}),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        // increment evaluated verses if coming from questions screen
        // if(ayatProvider != null) {
        //   ayatProvider.incrementEvaluatedVersesCount();
        // }
      } else {
        Fluttertoast.showToast(
          msg: 'eval_error'.tr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'generic_error'.tr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      rethrow;
    }
  }

  ChartEvaluationData? getEvaluationById(
      int id, EvaluationsProvider evaluationsProvider) {
    try {
      return evaluationsProvider.chartEvaluationData.firstWhere(
        (e) => e.evaluationId == id,
      );
    } catch (e) {
      return null;
    }
  }

  List<PieChartSectionData> buildChartSections(EvaluationsProvider provider) {
    return provider.chartEvaluationData.map((evaluation) {
      final double value = evaluation.percentage?.toDouble() ?? 0;
      final double adjustedValue = value < 2.0 ? 2.0 : value;

      // Adjust font size dynamically based on the percentage
      double fontSize;
      // Dynamically calculate font size based on percentage
      // Scaling factor of 2.5 seems appropriate given the radius of 150
      fontSize = (value * 2.5).clamp(5.0, 18.0);

      return PieChartSectionData(
        color: getColorForChartEntry(evaluation),
        value: adjustedValue,
        title: '${evaluation.percentage?.toStringAsFixed(2)}%',
        radius: 150,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Map<String, dynamic> buildSinglePayload({
    required int ayahId,
    int? memoId,
    int? compreId,
    bool includeMemo = false,
    bool includeCompre = false,
    bool clearMemo = false,
    bool clearCompre = false,
  }) {
    final payload = <String, dynamic>{
      'ayahId': ayahId,
    };

    if (includeMemo) {
      payload['memo_id'] = clearMemo ? null : memoId;
    }
    if (includeCompre) {
      payload['compre_id'] = clearCompre ? null : compreId;
    }

    return payload;
  }

  Map<String, dynamic> buildBulkPayload({
    required List<int> ayahIds,
    int? memoId,
    int? compreId,
    bool includeMemo = false,
    bool includeCompre = false,
    bool clearMemo = false,
    bool clearCompre = false,
  }) {
    final payload = <String, dynamic>{
      'ayahIds': ayahIds,
    };

    if (includeMemo) {
      payload['memo_id'] = clearMemo ? null : memoId;
    }
    if (includeCompre) {
      payload['compre_id'] = clearCompre ? null : compreId;
    }

    return payload;
  }

  UserEvaluation mergeUserEvaluation({
    required UserEvaluation? existing,
    required Ayat ayah,
    required EvaluationsProvider evaluationsProvider,
    int? memoId,
    int? compreId,
    bool memoChanged = false,
    bool compreChanged = false,
  }) {
    final nextMemoId = memoChanged ? memoId : existing?.memoId;
    final nextCompreId = compreChanged ? compreId : existing?.compreId;

    return UserEvaluation(
      id: existing?.id,
      ayahId: ayah.id,
      comment: existing?.comment,
      memoId: nextMemoId,
      compreId: nextCompreId,
      memoEvaluation: evaluationsProvider.findEvaluationById(nextMemoId),
      compreEvaluation: evaluationsProvider.findEvaluationById(nextCompreId),
      ayah: existing?.ayah ?? ayah,
    );
  }

  bool isPositiveComprehension(Evaluation? evaluation) {
    if (evaluation == null) {
      return false;
    }

    final code = evaluation.code.trim().toUpperCase();
    if (code == 'YES') {
      return true;
    }

    final localizedNames = evaluation.name.values.map(
      (value) => value.trim().toLowerCase(),
    );
    return localizedNames.contains('yes') || localizedNames.contains('نعم');
  }

  Color getColorForChartEntry(ChartEvaluationData evaluation) {
    return _parseColor(evaluation.color, fallback: getColorForEvaluationId(evaluation.evaluationId));
  }

  Color getColorForEvaluationModel(Evaluation? evaluation) {
    if (evaluation == null) {
      return AppColors.uncategorizedColor;
    }

    return _parseColor(
      evaluation.color,
      fallback: getColorForEvaluationId(evaluation.id),
    );
  }

  Color getColorForEvaluationId(int? evaluationId) {
    switch (evaluationId) {
      case 0:
        return AppColors.uncategorizedColor; // غير مصنف
      case 1:
        return AppColors.strongColor; // متمكن
      case 2:
        return AppColors.revisionColor; // مراجعة
      case 3:
        return AppColors.desireColor; // للحفظ
      case 4:
        return AppColors.easyColor; // سهل
      case 5:
        return AppColors.hardColor; // صعب
      default:
        return AppColors.uncategorizedColor; // fallback color
    }
  }

  Color _parseColor(String? rawColor, {required Color fallback}) {
    if (rawColor == null || rawColor.isEmpty) {
      return fallback;
    }

    final hex = rawColor.replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) {
      return fallback;
    }

    final normalized = hex.length == 6 ? 'FF$hex' : hex;

    try {
      return Color(int.parse(normalized, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}
