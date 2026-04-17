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

  final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
  final controller = EvaluationsController();

  String text(String arabic, String english) => isArabic ? arabic : english;

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
            final isDark = ThemeData.estimateBrightnessForColor(color) ==
                Brightness.dark;

            return ChoiceChip(
              label: Text(
                evaluation.name[languageProvider.langCode] ??
                    evaluation.name['ar'] ??
                    evaluation.code,
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
              title ?? text('تقييم الحفظ والفهم', 'Memorization & Comprehension'),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text('الحفظ', 'Memorization'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 10),
                    if (evaluationsProvider.memorizationEvaluations.isEmpty)
                      Text(
                        text(
                          'لا توجد تقييمات حفظ متاحة.',
                          'No memorization evaluations are available.',
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: evaluationsProvider.memorizationEvaluations
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
                    const SizedBox(height: 20),
                    Text(
                      text('الفهم', 'Comprehension'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 10),
                    if (evaluationsProvider.comprehensionEvaluations.isEmpty)
                      Text(
                        text(
                          'لا توجد قيم فهم متاحة.',
                          'No comprehension values are available.',
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: evaluationsProvider.comprehensionEvaluations
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
                    const SizedBox(height: 16),
                    Text(
                      text(
                        'اضغط على القيمة نفسها مرة ثانية لإزالتها.',
                        'Tap the same value again to clear it.',
                      ),
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
                child: Text(text('إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: memoChanged || compreChanged
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
                child: Text(text('حفظ', 'Save')),
              ),
            ],
          );
        },
      );
    },
  );
}