import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/evaluations_controller.dart';
import '../../models/evaluation.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/language_provider.dart';

class AssessmentSelection {
  const AssessmentSelection({
    required this.memoId,
    required this.compreId,
    required this.memoChanged,
    required this.compreChanged,
    required this.memoEvaluation,
    required this.compreEvaluation,
  });

  final int? memoId;
  final int? compreId;
  final bool memoChanged;
  final bool compreChanged;
  final Evaluation? memoEvaluation;
  final Evaluation? compreEvaluation;

  bool get hasChanges => memoChanged || compreChanged;
}

Future<AssessmentSelection?> showAssessmentInputDialog({
  required BuildContext context,
  required EvaluationsProvider evaluationsProvider,
  required LanguageProvider languageProvider,
  int? initialMemoId,
  int? initialCompreId,
  String? title,
}) async {
  if (evaluationsProvider.evaluations.isEmpty) {
    await evaluationsProvider.getAllEvaluations();
  }

  if (!context.mounted) {
    return null;
  }

  final controller = EvaluationsController();
  final memorizationEvaluations = evaluationsProvider.memorizationEvaluations;
  final comprehensionEvaluations = evaluationsProvider.comprehensionEvaluations;
  final hasMemoOptions = memorizationEvaluations.isNotEmpty;
  final hasCompreOptions = comprehensionEvaluations.isNotEmpty;

  String evaluationLabel(Evaluation evaluation) {
    final localizedName =
        evaluation.name[languageProvider.langCode]?.trim() ?? '';
    if (localizedName.isNotEmpty) {
      return localizedName;
    }

    final fallbackName =
        evaluation.name[Get.locale?.languageCode]?.trim() ??
        evaluation.name['ar']?.trim() ??
        evaluation.name['en']?.trim() ??
        '';
    if (fallbackName.isNotEmpty) {
      return fallbackName;
    }

    return evaluation.code;
  }

  final effectiveTitle = title ??
      (hasMemoOptions && hasCompreOptions
      ? 'assessment_dialog_title_both'.tr
          : hasMemoOptions
        ? 'assessment_dialog_title_memorization'.tr
              : hasCompreOptions
          ? 'assessment_dialog_title_comprehension'.tr
          : 'assessment_dialog_title_unavailable'.tr);

  return showDialog<AssessmentSelection>(
    context: context,
    builder: (dialogContext) {
      int? memoId = initialMemoId;
      int? compreId = initialCompreId;
      bool memoChanged = false;
      bool compreChanged = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildEvaluationChip({
            required Evaluation evaluation,
            required bool selected,
            required VoidCallback onTap,
          }) {
            final color = controller.getColorForEvaluationModel(evaluation);
            final isDark =
                ThemeData.estimateBrightnessForColor(color) == Brightness.dark;

            return ChoiceChip(
              label: Text(
                evaluationLabel(evaluation),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: selected,
              selectedColor: color,
              backgroundColor: Colors.white,
              side: BorderSide(color: color),
              onSelected: (_) => onTap(),
            );
          }

          return AlertDialog(
            title: Text(
              effectiveTitle,
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasMemoOptions && !hasCompreOptions)
                      Text(
                        'assessment_dialog_no_values'.tr,
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      if (hasMemoOptions) ...[
                        Text(
                          'assessment_dimension_memorization'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: memorizationEvaluations
                              .map(
                                (evaluation) => buildEvaluationChip(
                                  evaluation: evaluation,
                                  selected: memoId == evaluation.id,
                                  onTap: () {
                                    setDialogState(() {
                                      memoChanged = true;
                                      memoId = memoId == evaluation.id
                                          ? null
                                          : evaluation.id;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ] else
                        Text(
                          'assessment_dialog_memorization_unavailable'.tr,
                          textAlign: TextAlign.center,
                        ),
                      if (hasMemoOptions || hasCompreOptions)
                        const SizedBox(height: 20),
                      if (hasCompreOptions) ...[
                        Text(
                          'assessment_dimension_comprehension'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: comprehensionEvaluations
                              .map(
                                (evaluation) => buildEvaluationChip(
                                  evaluation: evaluation,
                                  selected: compreId == evaluation.id,
                                  onTap: () {
                                    setDialogState(() {
                                      compreChanged = true;
                                      compreId = compreId == evaluation.id
                                          ? null
                                          : evaluation.id;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ] else
                        Text(
                          'assessment_dialog_comprehension_unavailable'.tr,
                          textAlign: TextAlign.center,
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'assessment_dialog_hint'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('cancel'.tr),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF132A4A),
                  disabledBackgroundColor: const Color(0xFF132A4A)
                      .withValues(alpha: 0.32),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                ),
                onPressed: (memoChanged || compreChanged) &&
                        (hasMemoOptions || hasCompreOptions)
                    ? () {
                        Navigator.of(dialogContext).pop(
                          AssessmentSelection(
                            memoId: memoId,
                            compreId: compreId,
                            memoChanged: memoChanged,
                            compreChanged: compreChanged,
                            memoEvaluation:
                                evaluationsProvider.findEvaluationById(memoId),
                            compreEvaluation: evaluationsProvider
                                .findEvaluationById(compreId),
                          ),
                        );
                      }
                    : null,
                child: Text('save'.tr),
              ),
            ],
          );
        },
      );
    },
  );
}