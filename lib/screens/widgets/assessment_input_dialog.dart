import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/evaluations_controller.dart';
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
    final localizedName =
        evaluation.name[languageProvider.langCode]?.trim() ?? '';
    if (localizedName.isNotEmpty) {
      return localizedName;
    }

    final fallbackName = evaluation.name[Get.locale?.languageCode]?.trim() ??
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
                  evaluationLabel(evaluation),
                  textAlign: TextAlign.center,
                  style: AppTypography.of(context).badgeLabel.copyWith(
                        color: selected
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.black87,
                      ),
                ),
                selected: selected,
                selectedColor: color,
                backgroundColor: Colors.white,
                side: BorderSide(color: color),
                onSelected: (_) => onTap(),
              );
            }

            final canSave = memoChanged || compreChanged || commentChanged;

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
                            Text(
                              'assessment_dimension_memorization'.tr,
                              style: AppTypography.of(context).subsectionTitle,
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
                          const SizedBox(height: 20),
                          if (hasCompreOptions) ...[
                            Text(
                              'assessment_dimension_comprehension'.tr,
                              style: AppTypography.of(context).subsectionTitle,
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
                        if (hasMemoOptions || hasCompreOptions)
                          const SizedBox.shrink(),
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
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('cancel'.tr),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF132A4A),
                    disabledBackgroundColor:
                        const Color(0xFF132A4A).withValues(alpha: 0.32),
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
                                  normalizedComment != normalizedInitialComment,
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
            );
          },
        );
      },
    );
  } finally {
    commentController.dispose();
  }
}
