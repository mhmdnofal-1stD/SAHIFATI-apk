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
  final memorizationEvaluations = evaluationsProvider.memorizationEvaluations;
  final comprehensionEvaluations = evaluationsProvider.comprehensionEvaluations;
  final hasMemoOptions = memorizationEvaluations.isNotEmpty;
  final hasCompreOptions = comprehensionEvaluations.isNotEmpty;

  String text(String arabic, String english) => isArabic ? arabic : english;
  String evaluationLabel(Evaluation evaluation) {
    final localizedName =
        evaluation.name[languageProvider.langCode]?.trim() ?? '';
    if (localizedName.isNotEmpty) {
      return localizedName;
    }

    final fallbackName = evaluation.name[isArabic ? 'ar' : 'en']?.trim() ?? '';
    if (fallbackName.isNotEmpty) {
      return fallbackName;
    }

    return evaluation.code;
  }

  final effectiveTitle = title ??
      (hasMemoOptions && hasCompreOptions
          ? text('تقييم الحفظ والفهم', 'Memorization & Comprehension')
          : hasMemoOptions
              ? text('تقييم الحفظ', 'Memorization assessment')
              : hasCompreOptions
                  ? text('تقييم الفهم', 'Comprehension assessment')
                  : text(
                      'لا توجد خيارات تقييم متاحة',
                      'No assessment options are available',
                    ));

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
                        text(
                          'لا توجد أي قيم تقييم جاهزة في البيئة الحالية. لا يمكن حفظ تقييم جديد من هذه النافذة الآن.',
                          'No assessment values are configured for the current environment, so a new evaluation cannot be saved from this dialog yet.',
                        ),
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      if (hasMemoOptions) ...[
                        Text(
                          text('الحفظ', 'Memorization'),
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
                          text(
                            'خيارات الحفظ غير متاحة في taxonomy الحالي، لذلك سيقتصر هذا التقييم على الفهم فقط.',
                            'Memorization options are not available in the current taxonomy, so this dialog will save comprehension only.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (hasMemoOptions || hasCompreOptions)
                        const SizedBox(height: 20),
                      if (hasCompreOptions) ...[
                        Text(
                          text('الفهم', 'Comprehension'),
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
                          text(
                            'خيارات الفهم غير متاحة في taxonomy الحالي، لذلك سيقتصر هذا التقييم على الحفظ فقط.',
                            'Comprehension options are not available in the current taxonomy, so this dialog will save memorization only.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      text(
                        'اضغط على القيمة نفسها مرة ثانية لإزالتها. لن تُحفظ أي تغييرات حتى تختار حفظ.',
                        'Tap the same value again to clear it. No changes are saved until you confirm.',
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
                child: Text(text('حفظ', 'Save')),
              ),
            ],
          );
        },
      );
    },
  );
}