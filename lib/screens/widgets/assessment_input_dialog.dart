import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/localized_value.dart';
import '../../core/typography/app_typography.dart';
import '../../models/evaluation.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/subjects_lookup_service.dart';
import 'info_icon_button.dart';

class AssessmentSelection {
  const AssessmentSelection({
    required this.memoId,
    required this.compreId,
    required this.comment,
    required this.memoChanged,
    required this.compreChanged,
    required this.commentChanged,
    required this.memoEvaluation,
    required this.compreEvaluation,
  });

  final int? memoId;
  final int? compreId;
  final String? comment;
  final bool memoChanged;
  final bool compreChanged;
  final bool commentChanged;
  final Evaluation? memoEvaluation;
  final Evaluation? compreEvaluation;

  bool get hasChanges => memoChanged || compreChanged || commentChanged;
}

Future<AssessmentSelection?> showAssessmentInputDialog({
  required BuildContext context,
  required EvaluationsProvider evaluationsProvider,
  required LanguageProvider languageProvider,
  int? initialMemoId,
  int? initialCompreId,
  String? initialComment,
  Iterable<Object?> subjectKeys = const <Object?>[],
  bool enableCommentField = false,
  bool showSubjectSummary = true,
  String? subjectSummaryLabel,
  String? title,
  Widget? titleWidget,
  bool titleUsesQuranVerseStyle = false,
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
  final normalizedInitialComment = (initialComment ?? '').trim();
  final normalizedSubjectKeys = subjectKeys
      .map((key) => key?.toString().trim() ?? '')
      .where((key) => key.isNotEmpty)
      .toList(growable: false);
  final subjectNamesFuture =
      showSubjectSummary && normalizedSubjectKeys.isNotEmpty
          ? SubjectsLookupService.instance.resolveSubjectNames(
              normalizedSubjectKeys,
              localeCode: languageProvider.langCode,
            )
          : null;
  final commentController = TextEditingController(
    text: normalizedInitialComment,
  );

  String evaluationLabel(Evaluation evaluation) {
    final resolved = localizedValue(
      evaluation.name,
      preferredLocale: languageProvider.langCode,
      fallbackLocale: Get.locale?.languageCode,
    );
    if (resolved.isNotEmpty) {
      return resolved;
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

  try {
    return await showDialog<AssessmentSelection>(
      context: context,
      builder: (dialogContext) {
        int? memoId = initialMemoId;
        int? compreId = initialCompreId;
        bool memoChanged = false;
        bool compreChanged = false;
        bool commentChanged = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSave = memoChanged || compreChanged || commentChanged;
            final titleStyle = titleUsesQuranVerseStyle
                ? AppTypography.of(context).quranVerse
                : AppTypography.of(context).dialogTitle;

            Widget buildAssessmentSection({
              required String label,
              required List<Evaluation> evaluations,
              required bool selectedIsMemo,
              required int? selectedId,
              required ValueChanged<int?> onSelected,
            }) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppTypography.of(context).subsectionTitle,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: evaluations
                          .map(
                            (evaluation) {
                              final color = controller
                                  .getColorForEvaluationModel(evaluation);
                              final isDark =
                                  ThemeData.estimateBrightnessForColor(
                                        color,
                                      ) ==
                                      Brightness.dark;
                              final isSelected = selectedId == evaluation.id;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 4,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      evaluationLabel(evaluation),
                                      textAlign: TextAlign.center,
                                      style: AppTypography.of(context)
                                          .badgeLabel
                                          .copyWith(
                                            color: isSelected
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                : Colors.black87,
                                          ),
                                    ),
                                    labelPadding: EdgeInsets.zero,
                                    selected: isSelected,
                                    selectedColor: color,
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: color),
                                    onSelected: (_) {
                                      onSelected(
                                        selectedId == evaluation.id
                                            ? null
                                            : evaluation.id,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              title: Text(
                effectiveTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasMemoOptions &&
                          !hasCompreOptions &&
                          !enableCommentField)
                        Text(
                          'assessment_dialog_no_values'.tr,
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        if (hasMemoOptions || hasCompreOptions) ...[
                          if (hasMemoOptions) ...[
                            buildAssessmentSection(
                              label: 'assessment_dimension_memorization'.tr,
                              evaluations: memorizationEvaluations,
                              selectedIsMemo: true,
                              selectedId: memoId,
                              onSelected: (value) {
                                setDialogState(() {
                                  memoChanged = true;
                                  memoId = value;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (hasCompreOptions) ...[
                            buildAssessmentSection(
                              label: 'assessment_dimension_comprehension'.tr,
                              evaluations: comprehensionEvaluations,
                              selectedIsMemo: false,
                              selectedId: compreId,
                              onSelected: (value) {
                                setDialogState(() {
                                  compreChanged = true;
                                  compreId = value;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        if (subjectNamesFuture != null) ...[
                          Text(
                            subjectSummaryLabel ??
                                'assessment_dialog_subjects_label'.tr,
                            style: AppTypography.of(context).subsectionTitle,
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<List<String>>(
                            future: subjectNamesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('assessment_dialog_subjects_loading'
                                        .tr),
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              if (snapshot.hasError) {
                                return Text(
                                  'assessment_dialog_subjects_unavailable'.tr,
                                  textAlign: TextAlign.right,
                                  style: AppTypography.of(context)
                                      .bodySecondary
                                      .copyWith(color: Colors.grey.shade700),
                                );
                              }

                              final subjectNames = snapshot.data ?? const [];
                              if (subjectNames.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: subjectNames
                                    .map(
                                      (name) => Chip(
                                        label: Text(
                                          name,
                                          textAlign: TextAlign.right,
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (titleWidget != null) ...[
                          titleWidget,
                          const SizedBox(height: 20),
                        ],
                        if (enableCommentField) ...[
                          Text(
                            'assessment_dialog_comment_label'.tr,
                            style: AppTypography.of(context).subsectionTitle,
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: commentController,
                            minLines: 3,
                            maxLines: 5,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'assessment_dialog_comment_hint'.tr,
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (value) {
                              final normalizedComment = value.trim();
                              setDialogState(() {
                                commentChanged = normalizedComment !=
                                    normalizedInitialComment;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (hasMemoOptions || hasCompreOptions)
                  InfoIconButton(
                    message: 'assessment_dialog_hint'.tr,
                    color: Colors.grey.shade600,
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text('cancel'.tr),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          disabledBackgroundColor:
                              AppColors.primaryPurple.withValues(alpha: 0.32),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                        ),
                        onPressed: canSave
                            ? () {
                                final normalizedComment =
                                    commentController.text.trim();
                                Navigator.of(dialogContext).pop(
                                  AssessmentSelection(
                                    memoId: memoId,
                                    compreId: compreId,
                                    comment: normalizedComment.isEmpty
                                        ? null
                                        : normalizedComment,
                                    memoChanged: memoChanged,
                                    compreChanged: compreChanged,
                                    commentChanged:
                                        normalizedComment !=
                                            normalizedInitialComment,
                                    memoEvaluation: evaluationsProvider
                                        .findEvaluationById(memoId),
                                    compreEvaluation: evaluationsProvider
                                        .findEvaluationById(compreId),
                                  ),
                                );
                              }
                            : null,
                        child: Text('save'.tr),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    commentController.dispose();
  }
}
