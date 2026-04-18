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
import '../widgets/custom_button.dart';
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
      title: 'تقييم $unitName',
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
                                            title: 'تقييم الآية ${ayah.ayahNo}',
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
                                              title: 'تقييم ${surah.nameAr}',
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
                                          child: const Text("تقييم"),
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
                                            Text('آية ${ayah.ayahNo}'),
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
                                              title:
                                                  'تقييم الآية ${ayah.ayahNo}',
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
                                          child: const Text('تقييم'),
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
        SnackBar(content: Text('حدث خطأ أثناء تحميل الآيات: $e')),
      );
    }
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

    return GestureDetector(
        onTap: () {
          if (widget.content.type == 'juz' && widget.content.juz != null) {
            _showJuzBreakdown(context, widget.content.juz!, languageProvider);
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(
            vertical: SizeConfig.getProportionalHeight(10),
            horizontal: SizeConfig.getProportionalWidth(2),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: 0, vertical: SizeConfig.getProportionalHeight(15)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.getProportionalWidth(8),
                ),
                child: completionIcon,
              ),
              if (widget.content.surahId != null) ...[
                CustomText(
                  text:
                      '${GeneralController().getSurahNameArabic(widget.content.surahId!)} : ${widget.content.startAyah} - ${widget.content.endAyah}',
                  withBackground: false,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ],
              if (widget.content.type != "ayat range") ...[
                isEvaluating
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: EdgeInsets.only(
                            left: SizeConfig.getProportionalWidth(3.5)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CustomButton(
                              onPressed: () =>
                                  _evaluateUnit(context, languageProvider),
                              text: "full".tr,
                              width: 90,
                              height: 35,
                            ),
                            SizedBox(
                                width: SizeConfig.getProportionalHeight(5)),
                            CustomButton(
                              onPressed: () => _showIndividualEvaluation(
                                  context, languageProvider),
                              text: "by_ayah".tr,
                              width: 90,
                              height: 35,
                            ),
                          ],
                        ),
                      ),
              ] else ...[
                SizedBox(height: SizeConfig.getProportionalHeight(15)),
                CustomButton(
                  onPressed: () =>
                      _showIndividualEvaluation(context, languageProvider),
                  text: "verses_evaluation".tr,
                  width: 150,
                  height: 35,
                ),
              ],
            ],
          ),
        ));
  }

  void _setUnitName() {
    if (widget.content.type == "ayatRange") {
      unitName = "verses_definite".tr;
    } else if (widget.content.type == "surah") {
      unitName = "surah_definite".tr;
    } else if (widget.content.type == "hizb") {
      unitName = "hizb".tr;
    } else if (widget.content.type == "hizbQuarter") {
      unitName = "hizb_quarter".tr;
    } else if (widget.content.type == "juz") {
      unitName = "juz_prefix".tr;
    } else {
      unitName = "unit".tr;
    }
  }
}
