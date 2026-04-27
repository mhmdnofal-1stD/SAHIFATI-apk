import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/models/school.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/language_provider.dart';
import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../../services/evaluations_services.dart';
import '../../services/school_services.dart';
import '../../services/subjects_lookup_service.dart';
import '../main_screen/main_screen.dart';
import '../quran_view/index_page.dart';
import '../widgets/assessment_dimension_toggle.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/custom_button.dart';
import '../widgets/user_profile_badge.dart';
import '../widgets/global_drawer.dart';
import '../widgets/notifications_bell_button.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';

class SahifaScreen extends StatelessWidget {
  const SahifaScreen({super.key, required this.firstScreen});

  final bool firstScreen;

  int _evaluatedVerses(EvaluationsProvider provider) {
    final categorizedVerses = provider.chartEvaluationData
        .where((entry) => entry.evaluationId != 0)
        .fold<int>(0, (sum, entry) => sum + (entry.verseCount ?? 0));

    if (categorizedVerses > 0) {
      return categorizedVerses;
    }

    final uncategorized =
        EvaluationsController().getEvaluationById(0, provider)?.verseCount ?? 0;
    final fallback = provider.totalCount - uncategorized;
    return fallback < 0 ? 0 : fallback;
  }

  ChartEvaluationData? _topSignal(EvaluationsProvider provider) {
    final entries = provider.chartEvaluationData
        .where((entry) => entry.evaluationId != 0 && (entry.verseCount ?? 0) > 0)
        .toList()
      ..sort((a, b) => (b.verseCount ?? 0).compareTo(a.verseCount ?? 0));

    if (entries.isEmpty) {
      return null;
    }

    return entries.first;
  }

  int _remainingVerses(EvaluationsProvider provider) {
    final remaining = provider.totalCount - _evaluatedVerses(provider);
    return remaining < 0 ? 0 : remaining;
  }

  @override
  Widget build(BuildContext context) {
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context);
    LanguageProvider languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    final isComprehension = evaluationsProvider.chartDimension ==
        EvaluationsController.comprehensionDimension;
    final evaluatedVerses = _evaluatedVerses(evaluationsProvider);
    final hasChartData =
        evaluatedVerses > 0 && evaluationsProvider.chartEvaluationData.isNotEmpty;
    final topSignal = _topSignal(evaluationsProvider);
    final remainingVerses = _remainingVerses(evaluationsProvider);
    final currentDimensionLabel = isComprehension
      ? 'assessment_dimension_comprehension'.tr
      : 'assessment_dimension_memorization'.tr;

    return NoPopScope(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: AppColors.backgroundColor,
              automaticallyImplyLeading: usersProvider.isFirstLogin,
              leadingWidth: usersProvider.isFirstLogin ? 56 : 140,
              // adjust
              leading: usersProvider.isFirstLogin
                  ? const CustomBackButton()
                  : const Padding(
                      padding: EdgeInsetsDirectional.only(start: 12),
                      child: UserProfileBadge(),
                    ),
              actions: [
                const NotificationsBellButton(),
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      if ((Get.locale?.languageCode ?? 'ar') == 'ar') {
                        Scaffold.of(context).openDrawer();
                      } else {
                        Scaffold.of(context).openEndDrawer();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        drawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
            ? const GlobalDrawer()
            : null,
        endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
            ? null
            : const GlobalDrawer(),
        body: ResponsiveContentShell(
          builder: (context) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 980),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4EFE6), Color(0xFFE5F0E8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD7DED6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (firstScreen
                                  ? 'sahifa_screen_header_badge_first'
                                  : 'sahifa_screen_header_badge_returning')
                              .tr,
                          style: const TextStyle(
                            color: AppColors.buttonColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${"well_done".tr} ${usersProvider.selectedUser?.username ?? usersProvider.selectedUser?.email ?? ''}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blackFontColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'sahifa_screen_header_body'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: Color(0xFF39433D),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SahifaMetricChip(
                              label: 'sahifa_screen_metric_real_signal'.tr,
                              value: '$evaluatedVerses',
                            ),
                            _SahifaMetricChip(
                              label: 'sahifa_screen_metric_current_dimension'.tr,
                              value: currentDimensionLabel,
                            ),
                            _SahifaMetricChip(
                              label: 'sahifa_screen_metric_remaining'.tr,
                              value: '$remainingVerses',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<ReadingSession?>(
                    future:
                        ReadingSessionStore().loadForUser(usersProvider.selectedUser?.id),
                    builder: (context, snapshot) {
                      final session = snapshot.data;
                      if (session == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 980),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFDCE2DA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'sahifa_screen_resume_title'.tr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'sahifa_screen_resume_body'.trParams({
                                  'surah': session.surah.nameAr,
                                  'path': session.pathLabel(isArabic),
                                }),
                                style: const TextStyle(height: 1.55),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () async {
                                  await ReadingSessionStore()
                                      .updateAutoResumeForUser(
                                    usersProvider.selectedUser?.id,
                                    false,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }

                                  Get.toNamed(
                                    IndexPage.routeName,
                                    parameters:
                                        IndexPage.routeParametersForSession(
                                      session,
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.buttonColor,
                                ),
                                icon: const Icon(Icons.menu_book_rounded),
                                label: Text('main_screen_resume_action'.tr),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    height: SizeConfig.getProportionalHeight(24),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 980),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFDCE2DA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'sahifa_screen_summary_title'.tr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'sahifa_screen_summary_body'.tr,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: Color(0xFF4A554E),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (usersProvider.selectedUser != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _SahifaChartFiltersPanel(
                              userId: usersProvider.selectedUser!.id,
                              evaluationsProvider: evaluationsProvider,
                              languageProvider: languageProvider,
                            ),
                          ),
                        if (evaluationsProvider.isLoading && !hasChartData)
                          _SahifaStateCard(
                            icon: Icons.sync,
                            title: 'sahifa_screen_loading_title'.tr,
                            body: 'sahifa_screen_loading_body'.tr,
                          )
                        else if (!hasChartData)
                          _SahifaStateCard(
                            icon: evaluationsProvider.chartLoadError == null
                                ? Icons.info_outline
                                : Icons.error_outline,
                            title: evaluationsProvider.chartLoadError == null
                                ? 'sahifa_screen_empty_title'.tr
                                : 'sahifa_screen_error_title'.tr,
                            body: evaluationsProvider.chartLoadError == null
                                ? 'sahifa_screen_empty_body'.tr
                                : evaluationsProvider.chartLoadError!,
                            actionLabel: usersProvider.selectedUser == null
                                ? null
                                : 'welcome_chart_retry'.tr,
                            onAction: usersProvider.selectedUser == null
                                ? null
                                : () async {
                                    await evaluationsProvider.getQuranChartData(
                                      usersProvider.selectedUser!.id,
                                      dimension: evaluationsProvider.chartDimension,
                                    );
                                  },
                          )
                        else ...[
                          AssessmentDimensionToggle(
                            selectedDimension: evaluationsProvider.chartDimension,
                            onChanged: (dimension) async {
                              final user = usersProvider.selectedUser;
                              if (user == null) {
                                return;
                              }

                              await evaluationsProvider.getQuranChartData(
                                user.id,
                                dimension: dimension,
                              );
                            },
                          ),
                          SizedBox(
                            height: SizeConfig.getProportionalHeight(16),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: BarChartWidget(
                              evaluationsProvider: evaluationsProvider,
                              languageProvider: languageProvider,
                              includeUncategorized: false,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (topSignal != null)
                            _SahifaStateCard(
                              icon: Icons.auto_graph,
                              title: 'sahifa_screen_top_signal_title'.tr,
                              body: 'sahifa_screen_top_signal_body'.trParams({
                                'name': topSignal.name[languageProvider.langCode] ??
                                    topSignal.name['ar'] ??
                                    topSignal.name['en'] ??
                                    '',
                                'count': '${topSignal.verseCount ?? 0}',
                              }),
                            ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Text(
                              isComprehension
                                  ? 'sahifa_screen_comprehension_summary'.trParams({
                                      'evaluated': '$evaluatedVerses',
                                      'remaining': '$remainingVerses',
                                    })
                                  : 'sahifa_screen_memorization_summary'.trParams({
                                      'evaluated': '$evaluatedVerses',
                                      'remaining': '$remainingVerses',
                                    }),
                              textAlign: TextAlign.center,
                              strutStyle: const StrutStyle(
                                forceStrutHeight: true,
                                height: 1.35,
                                leading: 0.0,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDCE2DA)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'sahifa_screen_next_step_title'.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'sahifa_screen_next_step_body'.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 18),
                            CustomButton(
                              onPressed: () => {Get.to(const MainScreen())},
                              text: "browse_verses".tr,
                              width: 220,
                              height: 48,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SahifaMetricChip extends StatelessWidget {
  const _SahifaMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E5DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A645F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SahifaStateCard extends StatelessWidget {
  const _SahifaStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E0E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.buttonColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(height: 1.55),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => onAction!(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartFilterCatalog {
  const _ChartFilterCatalog({
    required this.surahs,
    required this.schools,
    required this.subjects,
  });

  final List<Surah> surahs;
  final List<School> schools;
  final List<SubjectHierarchyItem> subjects;
}

class _SahifaChartFiltersPanel extends StatefulWidget {
  const _SahifaChartFiltersPanel({
    required this.userId,
    required this.evaluationsProvider,
    required this.languageProvider,
  });

  final int userId;
  final EvaluationsProvider evaluationsProvider;
  final LanguageProvider languageProvider;

  @override
  State<_SahifaChartFiltersPanel> createState() =>
      _SahifaChartFiltersPanelState();
}

class _SahifaChartFiltersPanelState extends State<_SahifaChartFiltersPanel> {
  late Future<_ChartFilterCatalog> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  Future<_ChartFilterCatalog> _loadCatalog() async {
    final results = await Future.wait<Object>([
      _loadSurahs(),
      SchoolServices().getAllSchools(),
      SubjectsLookupService.instance.loadHierarchy(),
    ]);

    return _ChartFilterCatalog(
      surahs: results[0] as List<Surah>,
      schools: results[1] as List<School>,
      subjects: results[2] as List<SubjectHierarchyItem>,
    );
  }

  Future<List<Surah>> _loadSurahs() async {
    final raw = await rootBundle.loadString('assets/json/data.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final rawAyat = decoded['data'];
    if (rawAyat is! List) {
      return const [];
    }

    final surahsById = <int, Surah>{};
    for (final item in rawAyat.whereType<Map>()) {
      final surahRaw = item['surah'];
      if (surahRaw is Map) {
        final surah = Surah.fromJson(Map<String, dynamic>.from(surahRaw));
        surahsById[surah.id] = surah;
      }
    }

    final surahs = surahsById.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return surahs;
  }

  Future<void> _openFilters() async {
    try {
      if (widget.evaluationsProvider.evaluations.isEmpty) {
        await widget.evaluationsProvider.getAllEvaluations();
      }

      final catalog = await _catalogFuture;
      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _SahifaChartFiltersSheet(
          catalog: catalog,
          userId: widget.userId,
          evaluationsProvider: widget.evaluationsProvider,
          languageProvider: widget.languageProvider,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sahifa_chart_filters_load_failed'.tr)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = widget.evaluationsProvider.chartFilters;
    final chips = <Widget>[];

    void addSummaryChip(String label, int count) {
      if (count <= 0) {
        return;
      }
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4EFE6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE1D5BC)),
          ),
          child: Text(
            '$label: $count',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF31433D),
            ),
          ),
        ),
      );
    }

    addSummaryChip('surah_label'.tr, filters.surahIds.length);
    addSummaryChip('juz_prefix'.tr, filters.juzs.length);
    addSummaryChip('sahifa_chart_filters_type'.tr, filters.ayahTypes.length);
    addSummaryChip(
      'sahifa_chart_filters_subject'.tr,
      filters.subjectKeys.length,
    );
    addSummaryChip(
      'sahifa_chart_filters_school'.tr,
      filters.schoolIds.length + filters.schoolLevelPairs.length,
    );
    addSummaryChip(
      'sahifa_chart_filters_memorization'.tr,
      filters.memoEvaluationIds.length,
    );
    addSummaryChip(
      'sahifa_chart_filters_comprehension'.tr,
      filters.comprehensionEvaluationIds.length,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE2DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'sahifa_chart_filters_title'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
                label: Text('sahifa_chart_filters_open'.tr),
              ),
              if (filters.hasAnyActive)
                TextButton(
                  onPressed: () => widget.evaluationsProvider
                      .clearChartFilters(widget.userId),
                  child: Text('sahifa_chart_filters_reset'.tr),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            filters.hasAnyActive
                ? 'sahifa_chart_filters_active_hint'.tr
                : 'sahifa_chart_filters_empty_hint'.tr,
            style: const TextStyle(
              color: Color(0xFF5A645E),
              height: 1.45,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }
}

class _SahifaChartFiltersSheet extends StatefulWidget {
  const _SahifaChartFiltersSheet({
    required this.catalog,
    required this.userId,
    required this.evaluationsProvider,
    required this.languageProvider,
  });

  final _ChartFilterCatalog catalog;
  final int userId;
  final EvaluationsProvider evaluationsProvider;
  final LanguageProvider languageProvider;

  @override
  State<_SahifaChartFiltersSheet> createState() =>
      _SahifaChartFiltersSheetState();
}

class _SahifaChartFiltersSheetState extends State<_SahifaChartFiltersSheet> {
  late Set<int> _surahIds;
  late Set<int> _juzs;
  late Set<String> _ayahTypes;
  late Set<String> _subjectKeys;
  late Set<int> _schoolIds;
  late Set<String> _schoolLevelPairs;
  late Set<int> _memoEvaluationIds;
  late Set<int> _comprehensionEvaluationIds;

  @override
  void initState() {
    super.initState();
    final filters = widget.evaluationsProvider.chartFilters;
    _surahIds = filters.surahIds.toSet();
    _juzs = filters.juzs.toSet();
    _ayahTypes = filters.ayahTypes.toSet();
    _subjectKeys = filters.subjectKeys.toSet();
    _schoolIds = filters.schoolIds.toSet();
    _schoolLevelPairs = filters.schoolLevelPairs.toSet();
    _memoEvaluationIds = filters.memoEvaluationIds.toSet();
    _comprehensionEvaluationIds = filters.comprehensionEvaluationIds.toSet();
  }

  void _toggleValue<T>(Set<T> values, T value) {
    setState(() {
      if (!values.add(value)) {
        values.remove(value);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _surahIds.clear();
      _juzs.clear();
      _ayahTypes.clear();
      _subjectKeys.clear();
      _schoolIds.clear();
      _schoolLevelPairs.clear();
      _memoEvaluationIds.clear();
      _comprehensionEvaluationIds.clear();
    });
  }

  Future<void> _apply() async {
    final expandedSubjects = _expandSubjectKeys(
      _subjectKeys,
      widget.catalog.subjects,
    );

    await widget.evaluationsProvider.applyChartFilters(
      widget.userId,
      QuranChartFilters(
        surahIds: (_surahIds.toList()..sort()),
        juzs: (_juzs.toList()..sort()),
        ayahTypes: (_ayahTypes.toList()..sort()),
        subjectKeys: expandedSubjects.toList()..sort(),
        schoolIds: (_schoolIds.toList()..sort()),
        schoolLevelPairs: (_schoolLevelPairs.toList()..sort()),
        memoEvaluationIds: (_memoEvaluationIds.toList()..sort()),
        comprehensionEvaluationIds:
            (_comprehensionEvaluationIds.toList()..sort()),
      ),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Set<String> _expandSubjectKeys(
    Set<String> selectedKeys,
    List<SubjectHierarchyItem> allSubjects,
  ) {
    final childrenByParent = <String, List<SubjectHierarchyItem>>{};
    for (final subject in allSubjects) {
      final parent = subject.parent;
      if (parent == null || parent.isEmpty) {
        continue;
      }
      final siblings = childrenByParent.putIfAbsent(
        parent,
        () => <SubjectHierarchyItem>[],
      );
      siblings.add(subject);
    }

    final expanded = <String>{...selectedKeys};

    void visit(String key) {
      for (final child in childrenByParent[key] ?? const <SubjectHierarchyItem>[]) {
        if (expanded.add(child.key)) {
          visit(child.key);
        }
      }
    }

    for (final key in selectedKeys) {
      visit(key);
    }

    return expanded;
  }

  String _localizedText(Map<String, dynamic>? value, String fallback) {
    if (value == null) {
      return fallback;
    }
    final localeCode = widget.languageProvider.langCode;
    final preferred = value[localeCode]?.toString().trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    final arabic = value['ar']?.toString().trim();
    if (arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    final english = value['en']?.toString().trim();
    if (english != null && english.isNotEmpty) {
      return english;
    }
    return fallback;
  }

  List<Widget> _buildSubjectTree(
    String? parentKey,
    Map<String?, List<SubjectHierarchyItem>> tree,
    int depth,
  ) {
    final items = tree[parentKey] ?? const <SubjectHierarchyItem>[];
    final widgets = <Widget>[];

    for (final item in items) {
      widgets.add(
        Padding(
          padding: EdgeInsetsDirectional.only(start: depth * 12.0, bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(item.displayName(widget.languageProvider.langCode)),
                selected: _subjectKeys.contains(item.key),
                onSelected: (_) => _toggleValue(_subjectKeys, item.key),
              ),
              ..._buildSubjectTree(item.key, tree, depth + 1),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final memorizationEvaluations =
        widget.evaluationsProvider.memorizationEvaluations;
    final comprehensionEvaluations =
        widget.evaluationsProvider.comprehensionEvaluations;
    final subjectTree = <String?, List<SubjectHierarchyItem>>{};
    for (final subject in widget.catalog.subjects) {
      final parentKey =
          (subject.parent == null || subject.parent!.isEmpty) ? null : subject.parent;
      final siblings = subjectTree.putIfAbsent(
        parentKey,
        () => <SubjectHierarchyItem>[],
      );
      siblings.add(subject);
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'sahifa_chart_filters_title'.tr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: Text('sahifa_chart_filters_reset'.tr),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  _FilterSection(
                    title: 'surah_label'.tr,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.catalog.surahs
                          .map(
                            (surah) => FilterChip(
                              label: Text(surah.nameAr),
                              selected: _surahIds.contains(surah.id),
                              onSelected: (_) => _toggleValue(_surahIds, surah.id),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _FilterSection(
                    title: 'juz_prefix'.tr,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        30,
                        (index) => index + 1,
                      )
                          .map(
                            (juz) => FilterChip(
                              label: Text('${'juz_prefix'.tr} $juz'),
                              selected: _juzs.contains(juz),
                              onSelected: (_) => _toggleValue(_juzs, juz),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _FilterSection(
                    title: 'sahifa_chart_filters_type'.tr,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'value': 'Makki', 'label': 'sahifa_chart_filters_type_makki'.tr},
                        {'value': 'Madani', 'label': 'sahifa_chart_filters_type_madani'.tr},
                        {
                          'value': 'Debatable',
                          'label': 'sahifa_chart_filters_type_debatable'.tr,
                        },
                      ]
                          .map(
                            (item) => FilterChip(
                              label: Text(item['label']!),
                              selected: _ayahTypes.contains(item['value']),
                              onSelected: (_) =>
                                  _toggleValue(_ayahTypes, item['value']!),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _FilterSection(
                    title: 'sahifa_chart_filters_school'.tr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.catalog.schools.map((school) {
                        final schoolName = _localizedText(
                          school.schoolName,
                          'sahifa_chart_filters_school'.tr,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FilterChip(
                                label: Text(
                                  '$schoolName · ${'sahifa_chart_filters_all_levels'.tr}',
                                ),
                                selected: school.id != null &&
                                    _schoolIds.contains(school.id),
                                onSelected: school.id == null
                                    ? null
                                    : (_) => _toggleValue(_schoolIds, school.id!),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: school.levels.asMap().entries.map((entry) {
                                  final levelNumber = entry.key + 1;
                                  final pair = '${school.id}:$levelNumber';
                                  final levelLabel = _localizedText(
                                    entry.value.name,
                                    '${'level_assessment'.tr} $levelNumber',
                                  );

                                  return FilterChip(
                                    label: Text(levelLabel),
                                    selected: _schoolLevelPairs.contains(pair),
                                    onSelected: school.id == null
                                        ? null
                                        : (_) =>
                                            _toggleValue(_schoolLevelPairs, pair),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  _FilterSection(
                    title: 'sahifa_chart_filters_subject'.tr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildSubjectTree(null, subjectTree, 0),
                    ),
                  ),
                  _FilterSection(
                    title: 'sahifa_chart_filters_memorization'.tr,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: memorizationEvaluations
                          .map(
                            (evaluation) => FilterChip(
                              label: Text(
                                evaluation.name[widget.languageProvider.langCode] ??
                                    evaluation.name['ar'] ??
                                    evaluation.name['en'] ??
                                    '',
                              ),
                              selected: evaluation.id != null &&
                                  _memoEvaluationIds.contains(evaluation.id),
                              onSelected: evaluation.id == null
                                  ? null
                                  : (_) => _toggleValue(
                                        _memoEvaluationIds,
                                        evaluation.id!,
                                      ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _FilterSection(
                    title: 'sahifa_chart_filters_comprehension'.tr,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: comprehensionEvaluations
                          .map(
                            (evaluation) => FilterChip(
                              label: Text(
                                evaluation.name[widget.languageProvider.langCode] ??
                                    evaluation.name['ar'] ??
                                    evaluation.name['en'] ??
                                    '',
                              ),
                              selected: evaluation.id != null &&
                                  _comprehensionEvaluationIds.contains(
                                    evaluation.id,
                                  ),
                              onSelected: evaluation.id == null
                                  ? null
                                  : (_) => _toggleValue(
                                        _comprehensionEvaluationIds,
                                        evaluation.id!,
                                      ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.check_rounded),
                  label: Text('sahifa_chart_filters_apply'.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
