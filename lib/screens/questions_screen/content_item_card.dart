import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/ayat_controller.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/controllers/general_controller.dart';
import 'package:sahifaty/controllers/surahs_controller.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/services/teacher_recommendations_service.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../models/school_level_content.dart';
import '../widgets/assessment_input_dialog.dart';
import '../widgets/custom_text.dart';
import '../widgets/teacher_recommendation_badge.dart';

class ContentItemCard extends StatefulWidget {
  final SchoolLevelContent content;
  final int index;
  final bool? isCompleted;
  final bool isLoadingStatus;

  const ContentItemCard({
    super.key,
    required this.content,
    required this.index,
    this.isCompleted,
    this.isLoadingStatus = false,
  });

  @override
  State<ContentItemCard> createState() => _ContentItemCardState();
}

class _ContentItemCardState extends State<ContentItemCard> {
  bool isEvaluating = false;
  String unitName = "الوحدة";
  final TeacherRecommendationsService _teacherRecommendationsService =
      TeacherRecommendationsService();

  @override
  void initState() {
    super.initState();
    _setUnitName();
  }

  Future<List<Ayat>> _fetchAyahs({bool withEvaluations = false}) async {
    final ayatController = AyatController();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    List<Ayat> ayahs =
        evaluationsProvider.getQuestionContentAyahs(widget.content);

    if (ayahs.isEmpty) {
      ayahs = await ayatController.loadAyatForContent(widget.content);
    }

    if (withEvaluations && ayahs.isNotEmpty && mounted) {
      final usersProvider = context.read<UsersProvider>();

      if (usersProvider.selectedUser != null) {
        final userId = usersProvider.selectedUser!.id;
        final ayatIds =
            ayahs.where((ayah) => ayah.id != null).map((e) => e.id!).toList();
        final needsEvaluations =
            ayahs.any((ayah) => ayah.userEvaluation == null && ayah.id != null);
        if (needsEvaluations) {
          await evaluationsProvider.getAllUserEvaluations(userId, ayatIds);

          for (var ayah in ayahs) {
            final userEval = evaluationsProvider.userEvaluations
                .firstWhereOrNull(
                    (e) => e.ayah?.id == ayah.id || e.ayahId == ayah.id);
            ayah.userEvaluation = userEval;
          }
        }

        await _loadTeacherRecommendations(userId, ayahs);
        evaluationsProvider.syncQuestionContentAyahs(widget.content, ayahs);
      }
    }

    return ayahs;
  }

  Color _cardColorForEvaluation(UserEvaluation? userEvaluation) {
    return EvaluationsController()
        .getColorForEvaluationModel(userEvaluation?.memoEvaluation);
  }

  bool _isUnderlined(UserEvaluation? userEvaluation) {
    return EvaluationsController()
        .isPositiveComprehension(userEvaluation?.compreEvaluation);
  }

  Future<void> _loadTeacherRecommendations(int userId, List<Ayat> ayahs) async {
    final ayahIds =
        ayahs.where((ayah) => ayah.id != null).map((ayah) => ayah.id!).toList();
    if (ayahIds.isEmpty) {
      return;
    }

    try {
      final recommendations =
          await _teacherRecommendationsService.getStudentRecommendations(
        userId,
        ayahIds: ayahIds,
      );
      _applyTeacherRecommendations(ayahs, recommendations);
    } catch (_) {
      for (final ayah in ayahs) {
        ayah.teacherRecommendations = [];
      }
    }
  }

  void _applyTeacherRecommendations(
    List<Ayat> ayahs,
    List<TeacherRecommendation> recommendations,
  ) {
    final grouped = <int, List<TeacherRecommendation>>{};
    for (final recommendation in recommendations) {
      grouped
          .putIfAbsent(recommendation.ayahId, () => <TeacherRecommendation>[])
          .add(recommendation);
    }

    for (final ayah in ayahs) {
      ayah.teacherRecommendations =
          grouped[ayah.id] ?? <TeacherRecommendation>[];
    }
  }

  Future<bool> _deleteRecommendation(
    Ayat ayah,
    TeacherRecommendation recommendation,
  ) async {
    try {
      final response = await _teacherRecommendationsService
          .deleteRecommendation(recommendation.id);
      if (response.statusCode != 200 && response.statusCode != 204) {
        return false;
      }

      if (!mounted) {
        return true;
      }

      setState(() {
        ayah.teacherRecommendations.removeWhere(
          (item) => item.id == recommendation.id,
        );
      });
      context
          .read<EvaluationsProvider>()
          .syncQuestionContentAyahs(widget.content, _fetchCachedAyahs());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (Get.locale?.languageCode ?? 'ar') == 'ar'
                ? 'تم حذف التوصية.'
                : 'Recommendation deleted.',
          ),
        ),
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? 'تعذر حذف التوصية حالياً.'
                  : 'Unable to delete the recommendation right now.',
            ),
          ),
        );
      }
      return false;
    }
  }

  List<Ayat> _fetchCachedAyahs() {
    return context.read<EvaluationsProvider>().getQuestionContentAyahs(
          widget.content,
        );
  }

  Future<AssessmentSelection?> _openAssessmentDialog(
    BuildContext context,
    LanguageProvider languageProvider, {
    UserEvaluation? currentEvaluation,
    String? title,
  }) async {
    final evaluationsProvider = context.read<EvaluationsProvider>();

    if (evaluationsProvider.evaluations.isEmpty) {
      await evaluationsProvider.getAllEvaluations();
    }

    if (!context.mounted) {
      return null;
    }

    return showAssessmentInputDialog(
      context: context,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
      initialMemoId: currentEvaluation?.memoId,
      initialCompreId: currentEvaluation?.compreId,
      title: title,
    );
  }

  Future<void> _applySingleAssessment({
    required BuildContext context,
    required Ayat ayah,
    required List<Ayat> visibleAyahs,
    required EvaluationsProvider evaluationsProvider,
    required AssessmentSelection selection,
    StateSetter? setModalState,
  }) async {
    if (!selection.hasChanges) {
      return;
    }

    await EvaluationsController().sendEvaluationSelection(
      ayah,
      evaluationsProvider,
      null,
      memoId: selection.memoId,
      compreId: selection.compreId,
      memoChanged: selection.memoChanged,
      compreChanged: selection.compreChanged,
    );

    if (!mounted) {
      return;
    }

    final merged = EvaluationsController().mergeUserEvaluation(
      existing: ayah.userEvaluation,
      ayah: ayah,
      evaluationsProvider: evaluationsProvider,
      memoId: selection.memoId,
      compreId: selection.compreId,
      memoChanged: selection.memoChanged,
      compreChanged: selection.compreChanged,
    );

    if (setModalState != null) {
      setModalState(() {
        ayah.userEvaluation = merged;
      });
    } else {
      setState(() {
        ayah.userEvaluation = merged;
      });
    }

    evaluationsProvider.upsertUserEvaluation(merged);

    final refreshedAyahs = await _fetchAyahs(withEvaluations: true);
    if (!mounted) {
      return;
    }

    evaluationsProvider.syncQuestionContentAyahs(
      widget.content,
      refreshedAyahs.isNotEmpty ? refreshedAyahs : visibleAyahs,
    );
  }

  Future<void> _applyBulkAssessment({
    required List<Ayat> ayahs,
    required EvaluationsProvider evaluationsProvider,
    required AssessmentSelection selection,
    required String unitLabel,
  }) async {
    if (!selection.hasChanges) {
      return;
    }

    await EvaluationsController().sendMultipleEvaluationSelection(
      ayahs,
      evaluationsProvider,
      null,
      unitLabel,
      memoId: selection.memoId,
      compreId: selection.compreId,
      memoChanged: selection.memoChanged,
      compreChanged: selection.compreChanged,
    );

    for (final ayah in ayahs) {
      final merged = EvaluationsController().mergeUserEvaluation(
        existing: ayah.userEvaluation,
        ayah: ayah,
        evaluationsProvider: evaluationsProvider,
        memoId: selection.memoId,
        compreId: selection.compreId,
        memoChanged: selection.memoChanged,
        compreChanged: selection.compreChanged,
      );
      ayah.userEvaluation = merged;
      evaluationsProvider.upsertUserEvaluation(merged);
    }

    final refreshedAyahs = await _fetchAyahs(withEvaluations: true);
    if (!mounted) {
      return;
    }

    evaluationsProvider.syncQuestionContentAyahs(
      widget.content,
      refreshedAyahs.isNotEmpty ? refreshedAyahs : ayahs,
    );
  }

  Future<void> _evaluateUnit(
      BuildContext context, LanguageProvider languageProvider) async {
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final selection = await _openAssessmentDialog(
      context,
      languageProvider,
      title: text('تقييم $unitName', 'Assess $unitName'),
    );

    if (selection == null) return;

    setState(() {
      isEvaluating = true;
    });

    try {
      final ayahs = await _fetchAyahs();

      if (!context.mounted) return;

      if (ayahs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('no_verses_found_to_evaluate'.tr)),
        );
        return;
      }

      await _applyBulkAssessment(
        ayahs: ayahs,
        evaluationsProvider: evaluationsProvider,
        selection: selection,
        unitLabel: unitName,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'error_during_evaluation'.trParams({'error': e.toString()}))),
      );
    } finally {
      setState(() {
        isEvaluating = false;
      });
    }
  }

  Future<void> _showIndividualEvaluation(
      BuildContext context, LanguageProvider languageProvider) async {
    if (widget.content.type == 'juz' && widget.content.juz != null) {
      _showJuzBreakdown(context, widget.content.juz!, languageProvider);
      return;
    }

    final evaluationsProvider = context.read<EvaluationsProvider>();

    try {
      final ayahs = await _fetchAyahs(withEvaluations: true);

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomText(
                    text: 'verses_evaluation'.tr,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    withBackground: false,
                  ),
                ),
                Expanded(
                  child: ayahs.isEmpty
                      ? Center(child: Text("no_verses_to_display".tr))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: ayahs.length,
                          itemBuilder: (context, index) {
                            final ayah = ayahs[index];
                            final cardColor =
                                _cardColorForEvaluation(ayah.userEvaluation);

                            return Card(
                              color: cardColor,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    ayah.text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.whiteFontColor,
                                      fontSize: 18,
                                      fontFamily: 'UthmanicHafs',
                                      decoration:
                                          _isUnderlined(ayah.userEvaluation)
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                      decorationColor: AppColors.whiteFontColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TeacherRecommendationBadge(
                                            recommendations:
                                                ayah.teacherRecommendations,
                                            compact: true,
                                            onDelete: (recommendation) =>
                                                _deleteRecommendation(
                                              ayah,
                                              recommendation,
                                            ),
                                          ),
                                          if (ayah.teacherRecommendations
                                              .isNotEmpty)
                                            const SizedBox(width: 8),
                                          CustomText(
                                            text:
                                                '${'ayah_label'.tr} ${ayah.ayahNo}',
                                            withBackground: false,
                                            fontSize: 18,
                                            color: AppColors.whiteFontColor,
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final selection =
                                              await _openAssessmentDialog(
                                            context,
                                            languageProvider,
                                            currentEvaluation:
                                                ayah.userEvaluation,
                                            title: text(
                                              'تقييم الآية ${ayah.ayahNo}',
                                              'Assess verse ${ayah.ayahNo}',
                                            ),
                                          );

                                          if (selection == null) {
                                            return;
                                          }

                                          if (!context.mounted) {
                                            return;
                                          }

                                          await _applySingleAssessment(
                                            context: context,
                                            ayah: ayah,
                                            visibleAyahs: ayahs,
                                            evaluationsProvider:
                                                evaluationsProvider,
                                            selection: selection,
                                            setModalState: setModalState,
                                          );
                                        },
                                        child: CustomText(
                                          text: 'evaluate'.tr,
                                          withBackground: false,
                                          color: AppColors.blackFontColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('error_loading_verses'.trParams({'error': e.toString()}))),
      );
    }
  }

  Future<void> _showJuzBreakdown(
      BuildContext context, int juz, LanguageProvider languageProvider) async {
    final surahsController = SurahsController();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    try {
      final surahs = await surahsController.loadSurahsByJuz(juz);

      if (!context.mounted) return;

      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                Map<int, Color> surahColors = {};
                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setModalState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CustomText(
                          text: 'juz_surahs'.tr,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          withBackground: false,
                        ),
                      ),
                      Expanded(
                          child: surahs.isEmpty
                              ? Center(child: Text("no_surahs_to_display".tr))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: surahs.length,
                                  itemBuilder: (context, index) {
                                    final surah = surahs[index];
                                    final cardColor = surahColors[surah.id];

                                    return Card(
                                      color: cardColor,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: ListTile(
                                        title: Text(
                                          surah.nameAr,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          "${'surah_number'.tr} ${surah.id}",
                                          textAlign: TextAlign.right,
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () async {
                                            final selection =
                                                await _openAssessmentDialog(
                                              context,
                                              languageProvider,
                                              title: text(
                                                'تقييم ${surah.nameAr}',
                                                'Assess ${surah.nameAr}',
                                              ),
                                            );

                                            if (selection != null) {
                                              // Load ayahs for the surah
                                              final ayatController =
                                                  AyatController();
                                              List<Ayat> surahAyahs =
                                                  await ayatController
                                                      .loadAyatBySurah(
                                                          surah.id);

                                              if (!context.mounted) return;

                                              // Filter ayahs to current Juz
                                              surahAyahs = surahAyahs
                                                  .where((a) => a.juz == juz)
                                                  .toList();

                                              if (surahAyahs.isNotEmpty) {
                                                await _applyBulkAssessment(
                                                  ayahs: surahAyahs,
                                                  evaluationsProvider:
                                                      evaluationsProvider,
                                                  selection: selection,
                                                  unitLabel:
                                                      "${'surah_label'.tr} ${surah.nameAr}",
                                                );

                                                // Update card color in StatefulBuilder
                                                setModalState(() {
                                                  if (selection.memoChanged) {
                                                    surahColors[
                                                        surah.id] = selection
                                                                .memoId ==
                                                            null
                                                        ? AppColors
                                                            .uncategorizedColor
                                                        : EvaluationsController()
                                                            .getColorForEvaluationModel(
                                                                selection
                                                                    .memoEvaluation);
                                                  }
                                                });
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'no_verses_for_surah_in_juz'
                                                            .tr),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: Text(text('تقييم', 'Assess')),
                                        ),
                                        onTap: () {
                                          _showJuzSurahAyahs(context, surah,
                                              juz, languageProvider);
                                        },
                                      ),
                                    );
                                  },
                                )),
                    ],
                  );
                });
              }));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('error_loading_surahs'.trParams({'error': e.toString()}))),
      );
    }
  }

  Future<void> _showJuzSurahAyahs(BuildContext context, Surah surah, int juz,
      LanguageProvider languageProvider) async {
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final ayatController = AyatController();

    try {
      List<Ayat> ayahs = await ayatController.loadAyatBySurah(surah.id);

      if (!context.mounted) return;

      // Filter by Juz
      ayahs = ayahs.where((a) => a.juz == juz).toList();

      if (ayahs.isNotEmpty) {
        final usersProvider = context.read<UsersProvider>();
        if (usersProvider.selectedUser != null) {
          final userId = usersProvider.selectedUser!.id;
          final ayatIds = ayahs.map((e) => e.id!).toList();
          await evaluationsProvider.getAllUserEvaluations(userId, ayatIds);
          await _loadTeacherRecommendations(userId, ayahs);
          for (var ayah in ayahs) {
            final userEval = evaluationsProvider.userEvaluations
                .firstWhereOrNull(
                    (e) => e.ayah?.id == ayah.id || e.ayahId == ayah.id);
            ayah.userEvaluation = userEval;
          }
        }
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomText(
                    text: 'surah_verses_juz_title'.trParams(
                        {'surah': surah.nameAr, 'juz': juz.toString()}),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    withBackground: false,
                  ),
                ),
                Expanded(
                  child: ayahs.isEmpty
                      ? Center(child: Text("no_verses_to_display".tr))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: ayahs.length,
                          itemBuilder: (context, index) {
                            final ayah = ayahs[index];
                            final cardColor =
                                _cardColorForEvaluation(ayah.userEvaluation);

                            return Card(
                              color: cardColor,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      ayah.text,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontFamily: 'UthmanicHafs',
                                        decoration:
                                            _isUnderlined(ayah.userEvaluation)
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TeacherRecommendationBadge(
                                              recommendations:
                                                  ayah.teacherRecommendations,
                                              compact: true,
                                              onDelete: (recommendation) =>
                                                  _deleteRecommendation(
                                                ayah,
                                                recommendation,
                                              ),
                                            ),
                                            if (ayah.teacherRecommendations
                                                .isNotEmpty)
                                              const SizedBox(width: 8),
                                            Text(
                                              text(
                                                'آية ${ayah.ayahNo}',
                                                'Verse ${ayah.ayahNo}',
                                              ),
                                            ),
                                          ],
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final selection =
                                                await _openAssessmentDialog(
                                              context,
                                              languageProvider,
                                              currentEvaluation:
                                                  ayah.userEvaluation,
                                              title: text(
                                                'تقييم الآية ${ayah.ayahNo}',
                                                'Assess verse ${ayah.ayahNo}',
                                              ),
                                            );

                                            if (selection == null) {
                                              return;
                                            }

                                            if (!context.mounted) {
                                              return;
                                            }

                                            await _applySingleAssessment(
                                              context: context,
                                              ayah: ayah,
                                              visibleAyahs: ayahs,
                                              evaluationsProvider:
                                                  evaluationsProvider,
                                              selection: selection,
                                              setModalState: setModalState,
                                            );
                                          },
                                          child: Text(text('تقييم', 'Assess')),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              'حدث خطأ أثناء تحميل الآيات: $e',
              'An error occurred while loading verses: $e',
            ),
          ),
        ),
      );
    }
  }

  String text(String arabic, String english) {
    return (Get.locale?.languageCode ?? 'ar') == 'ar' ? arabic : english;
  }

  String get _normalizedContentType {
    return widget.content.type
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
  }

  bool get _isAyahRangeType => _normalizedContentType == 'ayatrange';

  bool get _isJuzType => _normalizedContentType == 'juz';

  String _contentHeadline() {
    if (widget.content.surahId != null) {
      final surahName =
          GeneralController().getSurahNameArabic(widget.content.surahId!);
      if (widget.content.startAyah != null && widget.content.endAyah != null) {
        return '$surahName ${widget.content.startAyah} - ${widget.content.endAyah}';
      }
      return surahName;
    }

    if (_normalizedContentType == 'juz' && widget.content.juz != null) {
      return '${text('الجزء', 'Juz')} ${widget.content.juz}';
    }

    if (_normalizedContentType == 'hizb' && widget.content.hizb != null) {
      return '${text('الحزب', 'Hizb')} ${widget.content.hizb}';
    }

    if (_normalizedContentType == 'hizbquarter' &&
        widget.content.hizbQuarter != null) {
      return '${text('ربع الحزب', 'Hizb quarter')} ${widget.content.hizbQuarter}';
    }

    return unitName;
  }

  String _contentSupportCopy() {
    if (_isAyahRangeType) {
      return text(
        'هذا المقطع يحتاج تقييمًا آية بآية حتى تبقى النتائج دقيقة.',
        'This slice is reviewed verse by verse so the result stays accurate.',
      );
    }

    if (_isJuzType) {
      return text(
        'يمكنك تقييم الجزء كاملًا أو فتح السور والآيات عند الحاجة.',
        'You can rate the full juz or drill into individual surahs and verses.',
      );
    }

    return text(
      'اختر بين تقييم واحد للوحدة كاملة أو مراجعة الآيات بالتفصيل.',
      'Choose one rating for the whole unit or review each verse in detail.',
    );
  }

  String _statusLabel() {
    if (widget.isLoadingStatus) {
      return text('جاري تحديث الحالة', 'Refreshing status');
    }

    if (widget.isCompleted == true) {
      return text('تم تقييم هذه الوحدة', 'This unit has been assessed');
    }

    return text(
      'هذه الوحدة ما زالت بانتظار التقييم',
      'This unit is still waiting for assessment',
    );
  }

  Color _statusColor() {
    if (widget.isCompleted == true) {
      return const Color(0xFFE9F8EF);
    }

    return const Color(0xFFF5EEF9);
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String title,
    required String subtitle,
    required IconData icon,
    bool outlined = false,
  }) {
    final buttonStyle = outlined
        ? OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            side: const BorderSide(color: AppColors.primaryPurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );

    final titleColor = outlined ? AppColors.primaryPurple : Colors.white;
    final subtitleColor = outlined
      ? AppColors.primaryPurple.withValues(alpha: 0.74)
      : Colors.white.withValues(alpha: 0.88);

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: buttonStyle,
              icon: const Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: AppColors.primaryPurple,
              ),
              label: label,
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              style: buttonStyle,
              icon: Icon(icon, size: 18),
              label: label,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.read<LanguageProvider>();
    final completionIcon = widget.isLoadingStatus
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            widget.isCompleted == true
                ? Icons.check_circle_rounded
                : Icons.pending_outlined,
            color: widget.isCompleted == true
                ? Colors.green
                : AppColors.primaryPurple,
          );
    final canInteract = !widget.isLoadingStatus && !isEvaluating;
    final title = _contentHeadline();

    return GestureDetector(
      onTap: () {
        if (_isJuzType && widget.content.juz != null) {
          _showJuzBreakdown(context, widget.content.juz!, languageProvider);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: SizeConfig.getProportionalHeight(10),
          horizontal: SizeConfig.getProportionalWidth(2),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.getProportionalWidth(14),
          vertical: SizeConfig.getProportionalHeight(16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE8DFF1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A6E4B8B),
              spreadRadius: 1,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: SizeConfig.getProportionalHeight(2),
                    right: SizeConfig.getProportionalWidth(10),
                    left: SizeConfig.getProportionalWidth(2),
                  ),
                  child: completionIcon,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _contentSupportCopy(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _statusColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isCompleted == true
                        ? Icons.verified_rounded
                        : Icons.pending_actions_rounded,
                    size: 18,
                    color: AppColors.primaryPurple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusLabel(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (isEvaluating)
              const Center(child: CircularProgressIndicator())
            else if (!_isAyahRangeType) ...[
              _buildActionButton(
                onPressed:
                    canInteract ? () => _evaluateUnit(context, languageProvider) : null,
                title: text('تقييم الوحدة دفعة واحدة', 'Rate the full unit at once'),
                subtitle: text(
                  'اختر درجة واحدة تُطبق على جميع الآيات في هذه الوحدة.',
                  'Choose one rating to apply across every verse in this unit.',
                ),
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                onPressed: canInteract
                    ? () => _showIndividualEvaluation(context, languageProvider)
                    : null,
                title: text('مراجعة آية بآية', 'Review verse by verse'),
                subtitle: text(
                  'افتح الآيات الفردية عندما تحتاج تقييماً أدق أو ملاحظات مختلفة.',
                  'Open the individual verses when you need a more precise review.',
                ),
                icon: Icons.menu_book_rounded,
                outlined: true,
              ),
            ] else
              _buildActionButton(
                onPressed: canInteract
                    ? () => _showIndividualEvaluation(context, languageProvider)
                    : null,
                title: text('ابدأ تقييم الآيات', 'Start verse assessment'),
                subtitle: text(
                  'هذا النوع لا يدعم تقييماً موحداً للوحدة كاملة.',
                  'This content type does not support a single unit-wide rating.',
                ),
                icon: Icons.playlist_add_check_circle_rounded,
              ),
            if (_isJuzType) ...[
              const SizedBox(height: 12),
              Text(
                text(
                  'يمكنك الضغط على البطاقة نفسها لفتح السور داخل الجزء.',
                  'Tap the card itself to open the surahs inside this juz.',
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setUnitName() {
    if (_isAyahRangeType) {
      unitName = "verses_definite".tr;
    } else if (_normalizedContentType == "surah") {
      unitName = "surah_definite".tr;
    } else if (_normalizedContentType == "hizb") {
      unitName = "hizb".tr;
    } else if (_normalizedContentType == "hizbquarter") {
      unitName = "hizb_quarter".tr;
    } else if (_normalizedContentType == "juz") {
      unitName = "juz_prefix".tr;
    } else {
      unitName = "unit".tr;
    }
  }
}
