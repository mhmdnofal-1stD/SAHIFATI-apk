import 'dart:async';
import 'dart:math' as math;

import '../widgets/soft_pattern_background.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;

import '../../controllers/ayat_controller.dart';
import '../../controllers/evaluations_controller.dart';
import '../../controllers/filter_types.dart';
import '../../core/constants/colors.dart';
import '../../core/reading/reading_session.dart';
import '../../core/typography/app_typography.dart';
import '../../models/ayat.dart';
import '../../models/evaluation.dart';
import '../../models/surah.dart';
import '../../models/user_evaluation.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/users_provider.dart';
import '../../services/evaluations_services.dart';
import '../quran_view/index_page.dart';
import '../supervision_screen/supervision_metric_utils.dart';
import '../widgets/assessment_input_dialog.dart';
import '../widgets/global_drawer.dart';
import '../widgets/quran_filter_runtime.dart';
import '../widgets/surah_verse_chart.dart';
import '../widgets/unified_quran_filter_sheet.dart';
import '../widgets/verse_picker_sheet.dart';

/// صحيفة المستخدم — الصفحة الرئيسية بعد تسجيل الدخول
class UserOverviewScreen extends StatefulWidget {
  static const String routeName = '/me';

  const UserOverviewScreen({super.key});

  @override
  State<UserOverviewScreen> createState() => _UserOverviewScreenState();
}

class _UserOverviewScreenState extends State<UserOverviewScreen> {
  final EvaluationsServices _evaluationsServices = EvaluationsServices();
  final AyatController _ayatController = AyatController();
  final QuranFilterAvailabilityBuilder _filterAvailabilityBuilder =
      const QuranFilterAvailabilityBuilder();

  late Future<_UserOverviewData> _future;
  UnifiedFilterSelection _surahFilter = UnifiedFilterSelection.empty();
  bool? _globalExpand; // null=individual, true=expand all, false=collapse all

  // Simulated loading progress (0.0 → 1.0)
  double _loadProgress = 0.0;
  Timer? _progressTimer;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _startProgressAnimation();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressAnimation() {
    // Animate: 0→30% fast, 30→70% medium, 70→95% slow
    const targets = [0.3, 0.5, 0.7, 0.85, 0.95];
    int step = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_dataLoaded) {
        setState(() => _loadProgress = 1.0);
        t.cancel();
        return;
      }
      if (step < targets.length) {
        setState(() => _loadProgress = targets[step]);
        step++;
      }
    });
  }

  int? _currentUserId() {
    return context.read<UsersProvider>().selectedUser?.id;
  }

  Future<void> _showFilterSheet() async {
    final evaluationsProvider = context.read<EvaluationsProvider>();

    if (evaluationsProvider.evaluations.isEmpty) {
      try {
        await evaluationsProvider.getAllEvaluations();
      } catch (_) {}
    }

    final availableData = await _filterAvailabilityBuilder.buildForDisplay(
      memorizationEvaluations: evaluationsProvider.memorizationEvaluations,
      comprehensionEvaluations: evaluationsProvider.comprehensionEvaluations,
      onProgress: (_, __) {},
    );

    if (!mounted) return;

    final result = await showUnifiedQuranFilterSheet(
      context,
      initial: _surahFilter,
      available: availableData,
    );
    if (result != null && mounted) {
      setState(() => _surahFilter = result);
    }
  }

  Future<void> _resumeReading() async {
    final userId = _currentUserId();
    final session = await ReadingSessionStore().loadForUser(userId);
    if (!mounted) return;

    if (session != null) {
      await ReadingSessionStore().updateAutoResumeForUser(userId, false);
      if (!mounted) return;
      Get.toNamed(
        IndexPage.routeName,
        parameters: IndexPage.routeParametersForSession(session),
      );
      return;
    }

    Get.toNamed(
      IndexPage.routeName,
      parameters: IndexPage.routeParameters(
        surah: const Surah(id: 1, nameAr: 'الفاتحة', ayahCount: 7),
        filterTypeId: FilterTypes.thirds,
      ),
    );
  }

  bool _surahMatchesFilter(_SurahProgressCardData surahCard) {
    if (_surahFilter.isEmpty) return true;
    if (_surahFilter.thirds.isNotEmpty) {
      if (!_surahFilter.thirds.contains(_surahThird(surahCard.surahId))) {
        return false;
      }
    }
    if (_surahFilter.ayahTypes.isNotEmpty) {
      final revType =
          _madaniSurahs.contains(surahCard.surahId) ? 'madani' : 'makki';
      if (!_surahFilter.ayahTypes.contains(revType)) return false;
    }
    return true;
  }

  List<_OverviewSegment> _computeFilteredSegments(
    _UserOverviewData data,
    List<_SurahProgressCardData> filteredCards,
  ) {
    if (_surahFilter.isEmpty) return data.segments;

    final charByLabel = <String, int>{};
    var totalChars = 0;
    for (final card in filteredCards) {
      for (final entry in card.verseEntries) {
        if (entry.evaluationLabel == 'غير مصنف') continue;
        final c = entry.letterCount > 0 ? entry.letterCount : 1;
        charByLabel[entry.evaluationLabel] =
            (charByLabel[entry.evaluationLabel] ?? 0) + c;
        totalChars += c;
      }
    }
    if (totalChars == 0) return [];

    final result = <_OverviewSegment>[];
    for (final seg in data.segments) {
      final count = charByLabel[seg.label] ?? 0;
      if (count == 0) continue;
      result.add(_OverviewSegment(
        label: seg.label,
        percent: (count * 100.0) / totalChars,
        verseCount: count,
        color: seg.color,
        priority: seg.priority,
        isProficient: seg.isProficient,
        isReview: seg.isReview,
      ));
    }
    return result
      ..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        return p != 0 ? p : b.percent.compareTo(a.percent);
      });
  }

  static int _surahThird(int surahId) {
    try {
      final page = quran.getPageNumber(surahId, 1);
      if (page <= 201) return 1;
      if (page <= 402) return 2;
      return 3;
    } catch (_) {
      return 1;
    }
  }

  static const Set<int> _madaniSurahs = {
    2, 3, 4, 5, 8, 9, 13, 22, 24, 33, 47, 48, 49, 55, 57, 58, 59, 60, 61,
    62, 63, 64, 65, 66, 76, 98, 99, 110,
  };

  Future<void> _reload() async {
    _dataLoaded = false;
    _loadProgress = 0.0;
    _progressTimer?.cancel();
    _startProgressAnimation();
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<_UserOverviewData> _load() async {
    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    final evaluationsProvider = context.read<EvaluationsProvider>();

    final results = await Future.wait<Object>([
      _evaluationsServices.getAllEvaluations(type: 'memorization'),
      evaluationsProvider.loadResolvedUserEvaluations(userId),
      _ayatController.loadAllAyat(),
    ]);

    final data = _buildOverview(
      evaluations: (results[0] as List<Evaluation>)
          .where((e) => e.id != null)
          .toList(growable: false),
      userEvaluations: results[1] as List<UserEvaluation>,
      allAyat: results[2] as List<Ayat>,
    );

    if (mounted) {
      setState(() => _dataLoaded = true);
    }
    return data;
  }

  _UserOverviewData _buildOverview({
    required List<Evaluation> evaluations,
    required List<UserEvaluation> userEvaluations,
    required List<Ayat> allAyat,
  }) {
    final evaluationPayloadById = <int, Map<String, dynamic>>{
      for (final evaluation in evaluations)
        if (evaluation.id != null)
          evaluation.id!: <String, dynamic>{
            'evaluationId': evaluation.id,
            'code': evaluation.code,
            'name': evaluation.name,
            'nameAr': evaluation.name['ar'],
            'color': evaluation.color,
          },
    };
    final userEvaluationByAyahId = <int, UserEvaluation>{
      for (final evaluation in userEvaluations)
        if ((evaluation.ayah?.id ?? evaluation.ayahId) != null)
          (evaluation.ayah?.id ?? evaluation.ayahId)!: evaluation,
    };

    // Build ayat lookup by surahId for the verse picker popup
    final ayatBySurahId = <int, List<Ayat>>{};
    for (final ayah in allAyat) {
      ayatBySurahId.putIfAbsent(ayah.surah.id, () => []).add(ayah);
    }

    final surahStatsById = <int, _MutableSurahProgress>{};
    final overallCharacterCounts = <int, int>{};
    final overallVerseCounts = <int, int>{};
    var totalCharacters = 0;

    for (final ayah in allAyat) {
      final ayahId = ayah.id;
      if (ayahId == null) continue;

      final surahId = ayah.surah.id;
      final surahStats = surahStatsById.putIfAbsent(
        surahId,
        () => _MutableSurahProgress(
          surahId: surahId,
          surahName: ayah.surah.nameAr,
        ),
      );
      surahStats.totalVerses += 1;

      final letterCount = ayah.letterCount ?? 0;
      totalCharacters += letterCount;

      final userEvaluation = userEvaluationByAyahId[ayahId];
      final memoId = userEvaluation?.memoId;

      if (letterCount > 0) {
        final evaluation =
            memoId != null && memoId > 0 ? evaluationPayloadById[memoId] : null;
        surahStats.verseEntries.add(VerseChartEntry(
          ayahId: ayahId,
          ayahNumber: ayah.ayahNo,
          letterCount: letterCount,
          score: evaluation != null
              ? supervisionEvaluationScore(evaluation)
              : 0.0,
          color: evaluation != null
              ? supervisionResolveEvaluationColor(evaluation)
              : const Color(0xFFCBCED4),
          evaluationLabel: evaluation != null
              ? supervisionEvaluationDisplayName(evaluation)
              : 'غير مصنف',
          text: ayah.text,
        ));
      }

      if (memoId == null || memoId <= 0) continue;

      surahStats.evaluatedVerses += 1;
      overallCharacterCounts[memoId] =
          (overallCharacterCounts[memoId] ?? 0) + letterCount;
      overallVerseCounts[memoId] = (overallVerseCounts[memoId] ?? 0) + 1;

      final evaluation = evaluationPayloadById[memoId];
      if (evaluation != null && supervisionIsProficientEvaluation(evaluation)) {
        surahStats.proficientVerses += 1;
      }
    }

    final segments = overallCharacterCounts.entries
        .map((entry) {
          final evaluation = evaluationPayloadById[entry.key] ??
              <String, dynamic>{
                'code': '',
                'name': <String, String>{'ar': 'تقييم ${entry.key}'},
              };
          final label = supervisionEvaluationDisplayName(evaluation).isEmpty
              ? 'تقييم ${entry.key}'
              : supervisionEvaluationDisplayName(evaluation);
          final percent = totalCharacters == 0
              ? 0.0
              : (entry.value * 100) / totalCharacters;
          return _OverviewSegment(
            label: label,
            percent: percent,
            verseCount: overallVerseCounts[entry.key] ?? 0,
            color: supervisionResolveEvaluationColor(evaluation),
            priority: supervisionEvaluationPriority(evaluation),
            isProficient: supervisionIsProficientEvaluation(evaluation),
            isReview: supervisionIsReviewEvaluation(evaluation),
          );
        })
        .where((s) => s.verseCount > 0 && s.percent > 0)
        .toList(growable: false)
      ..sort((l, r) {
        final p = l.priority.compareTo(r.priority);
        return p != 0 ? p : r.percent.compareTo(l.percent);
      });

    _OverviewSegment? highlight;
    for (final seg in segments) {
      if (seg.isProficient) {
        highlight = seg;
        break;
      }
    }
    highlight ??= segments.isNotEmpty ? segments.first : null;

    final surahCards = surahStatsById.values
        .where((s) => s.evaluatedVerses > 0)
        .map((s) => _SurahProgressCardData(
              surahId: s.surahId,
              surahName: s.surahName,
              totalVerses: s.totalVerses,
              proficientVerses: s.proficientVerses,
              evaluatedVerses: s.evaluatedVerses,
              verseEntries: List<VerseChartEntry>.unmodifiable(s.verseEntries),
            ))
        .toList(growable: false)
      ..sort((l, r) => l.surahId.compareTo(r.surahId));

    return _UserOverviewData(
      segments: segments,
      highlight: highlight,
      surahCards: surahCards,
      ayatBySurahId: ayatBySurahId,
    );
  }

  Future<void> _openVersePicker(
    _SurahProgressCardData surahCard,
    List<Ayat> ayat,
  ) async {
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final languageProvider = context.read<LanguageProvider>();

    final selectedAyahIds = await showVersePickerSheet(
      context: context,
      sheetTitle: surahCard.surahName,
      verseEntries: surahCard.verseEntries,
    );

    if (selectedAyahIds == null || selectedAyahIds.isEmpty || !mounted) return;

    final selectedAyat = ayat
        .where((a) => a.id != null && selectedAyahIds.contains(a.id))
        .toList();
    if (selectedAyat.isEmpty) return;

    final userId = _currentUserId();
    if (userId == null) return;

    if (!mounted) return;
    final selection = await showAssessmentInputDialog(
      context: context,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
      enableCommentField: false,
      showSubjectSummary: false,
      title: 'تقييم ${selectedAyat.length} آية من ${surahCard.surahName}',
    );

    if (selection == null || !mounted || !selection.hasChanges) return;

    try {
      await EvaluationsController().sendMultipleEvaluationSelection(
        selectedAyat,
        evaluationsProvider,
        null,
        'verses'.tr,
        targetUserId: userId,
        memoId: selection.memoId,
        compreId: selection.compreId,
        comment: null,
        memoChanged: selection.memoChanged,
        commentChanged: false,
        compreChanged: selection.compreChanged,
      );
    } catch (_) {
      return;
    }

    if (!mounted) return;

    // Reload to reflect new evaluations
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SoftPatternBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              'صحيفتي',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF151515),
              ),
            ),
            centerTitle: true,
            actions: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF161616)),
                  onPressed: () {
                    if ((Get.locale?.languageCode ?? 'ar') == 'ar') {
                      Scaffold.of(ctx).openDrawer();
                    } else {
                      Scaffold.of(ctx).openEndDrawer();
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
      body: SafeArea(
        child: FutureBuilder<_UserOverviewData>(
          future: _future,
          builder: (context, snapshot) {
            // ── Loading state ─────────────────────────────────────────
            if (snapshot.connectionState != ConnectionState.done) {
              return _LoadingProgressBar(progress: _loadProgress);
            }

            if (snapshot.hasError) {
              return _OverviewErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }

            final data = snapshot.data!;
            final filteredSurahCards =
                data.surahCards.where(_surahMatchesFilter).toList();
            final filteredSegments =
                _computeFilteredSegments(data, filteredSurahCards);
            final filteredHighlight = filteredSegments.firstWhere(
              (s) => s.isProficient,
              orElse: () => filteredSegments.isNotEmpty
                  ? filteredSegments.first
                  : data.segments.firstWhere(
                      (s) => s.isProficient,
                      orElse: () => data.segments.isNotEmpty
                          ? data.segments.first
                          : const _OverviewSegment(
                              label: 'متمكن',
                              percent: 0,
                              verseCount: 0,
                              color: Color(0xFF4FD99A),
                              priority: 0,
                              isProficient: true,
                              isReview: false,
                            ),
                    ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Sticky compact summary header ─────────────────────
                Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _UserSummaryHeader(
                      segments: filteredSegments,
                      highlight: filteredHighlight,
                      hasActiveFilter: !_surahFilter.isEmpty,
                      hasCards: filteredSurahCards.isNotEmpty,
                      onFilterTap: _showFilterSheet,
                      onResumeTap: _resumeReading,
                      onExpandAll: () => setState(() => _globalExpand = true),
                      onCollapseAll: () => setState(() => _globalExpand = false),
                    ),
                  ),
                ),
                // ── Scrollable surah list ─────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    color: AppColors.primaryPurple,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: [
                        if (filteredSurahCards.isEmpty)
                          const _SurahListEmptyState()
                        else
                          ...filteredSurahCards.map(
                            (surah) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _UserSurahProgressCard(
                                data: surah,
                                externalExpand: _globalExpand,
                                onSurahNameTap: () => _openVersePicker(
                                  surah,
                                  data.ayatBySurahId[surah.surahId] ?? [],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Progress Bar — animated 0→100%
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingProgressBar extends StatelessWidget {
  const _LoadingProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'صحيفتي',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF191919),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جاري تحميل بياناتك...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: const Color(0xFFE5E5E5),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryPurple,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary header — donut + pills + resume button
// ─────────────────────────────────────────────────────────────────────────────
class _UserSummaryHeader extends StatelessWidget {
  const _UserSummaryHeader({
    required this.segments,
    required this.highlight,
    required this.hasActiveFilter,
    required this.onFilterTap,
    required this.onResumeTap,
    required this.onExpandAll,
    required this.onCollapseAll,
    required this.hasCards,
  });

  final List<_OverviewSegment> segments;
  final _OverviewSegment? highlight;
  final bool hasActiveFilter;
  final VoidCallback onFilterTap;
  final VoidCallback onResumeTap;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;
  final bool hasCards;

  @override
  Widget build(BuildContext context) {
    final effectiveHighlight = highlight ??
        const _OverviewSegment(
          label: 'متمكن',
          percent: 0,
          verseCount: 0,
          color: Color(0xFF4FD99A),
          priority: 0,
          isProficient: true,
          isReview: false,
        );

    final donut = SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 24,
              startDegreeOffset: 90,
              sections: segments.isEmpty
                  ? [
                      PieChartSectionData(
                        color: const Color(0xFFE5E5E5),
                        value: 1,
                        radius: 16,
                        title: '',
                      ),
                    ]
                  : segments
                      .map((s) => PieChartSectionData(
                            color: s.color,
                            value: math.max(s.percent, 0.01),
                            radius: 16,
                            title: '',
                          ))
                      .toList(growable: false),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${supervisionFormatPercent(effectiveHighlight.percent)}%',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF151515),
                ),
              ),
              Text(
                effectiveHighlight.label,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E213A52),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1️⃣ القسم الأيمن: الرسم البياني الدائري
          donut,

          const SizedBox(width: 12),

          // 2️⃣ القسم الأوسط: عمود الأزرار الملونة
          SizedBox(
            width: 82,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: segments
                  .map((seg) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _CompactPill(segment: seg),
                      ))
                  .toList(growable: false),
            ),
          ),

          const SizedBox(width: 16),

          // 3️⃣ القسم الأيسر: كتلة التحكم
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الصف العلوي: زر صحيفتي الأخضر + زر تصفية
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onResumeTap,
                        borderRadius: BorderRadius.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF15523F),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: const Text(
                            'صحيفتي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderChip(
                      icon: Icons.tune_rounded,
                      label: hasActiveFilter ? 'تصفية (نشط)' : 'تصفية',
                      active: hasActiveFilter,
                      onTap: onFilterTap,
                    ),
                  ],
                ),

                if (hasCards) ...[
                  const SizedBox(height: 8),
                  // الصف السفلي: زرا فتح الكل وطي الكل
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: _HeaderChip(
                          icon: Icons.unfold_more_rounded,
                          label: 'فتح الكل',
                          onTap: onExpandAll,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderChip(
                          icon: Icons.unfold_less_rounded,
                          label: 'طي الكل',
                          onTap: onCollapseAll,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Surah Progress Card — with tappable surah name for verse picker
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Header chip — filter / expand / collapse
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppColors.primaryPurple.withValues(alpha: 0.1)
        : const Color(0xFFF5F2EE);
    final fg = active ? AppColors.primaryPurple : const Color(0xFF555555);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSurahProgressCard extends StatefulWidget {
  const _UserSurahProgressCard({
    required this.data,
    required this.onSurahNameTap,
    this.externalExpand,
  });

  final _SurahProgressCardData data;
  final VoidCallback onSurahNameTap;
  final bool? externalExpand;

  @override
  State<_UserSurahProgressCard> createState() =>
      _UserSurahProgressCardState();
}

class _UserSurahProgressCardState extends State<_UserSurahProgressCard> {
  bool _expanded = false;
  bool? _lastExternalExpand;

  @override
  void initState() {
    super.initState();
    final ext = widget.externalExpand;
    if (ext != null) {
      _expanded = ext;
      _lastExternalExpand = ext;
    }
  }

  @override
  void didUpdateWidget(_UserSurahProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ext = widget.externalExpand;
    if (ext != null && ext != _lastExternalExpand) {
      _expanded = ext;
      _lastExternalExpand = ext;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Surah name — tappable ───
          GestureDetector(
            onTap: widget.onSurahNameTap,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Text(
                    data.surahName,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: AppTypography.of(context).pageHeading.copyWith(
                          color: AppColors.primaryPurple,
                          fontSize: 26,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.touch_app_rounded,
                  size: 18,
                  color: AppColors.primaryPurple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.proficientRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F1F1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF33A37E),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // ─── Summary row + expand toggle ───
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                AnimatedRotation(
                  turns: _expanded ? -0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 34,
                    color: _expanded
                        ? const Color(0xFF7C5DFA)
                        : const Color(0xFF111111),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'متبقي ${data.remainingVerses} آية (%${supervisionFormatPercent(data.remainingPercent, fractionDigits: 0)})',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.left,
                    style: AppTypography.of(context).bodySecondary.copyWith(
                          color: const Color(0xFFC2C2C2),
                          fontSize: 14,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'متمكن ${data.proficientVerses} آية (%${supervisionFormatPercent(data.proficientPercent, fractionDigits: 0)})',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: AppTypography.of(context).bodyDefault.copyWith(
                          color: const Color(0xFF232323),
                          fontSize: 14.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded && data.verseEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF0EBE3), height: 1),
            const SizedBox(height: 14),
            SurahVerseChart(
              entries: data.verseEntries,
              height: 130,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared compact pill
// ─────────────────────────────────────────────────────────────────────────────
class _CompactPill extends StatelessWidget {
  const _CompactPill({required this.segment});

  final _OverviewSegment segment;

  static Color _textColor(Color bg) =>
      bg.computeLuminance() > 0.45
          ? const Color(0xFF1A1A1A)
          : Colors.white;

  @override
  Widget build(BuildContext context) {
    final textCol = _textColor(segment.color);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: segment.color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '${segment.label} ${supervisionFormatPercent(segment.percent)}%',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textCol,
          height: 1.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error & Empty states
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewErrorState extends StatelessWidget {
  const _OverviewErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 38, color: Color(0xFFB45309)),
            const SizedBox(height: 12),
            Text(message,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: AppTypography.of(context).bodyDefault),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple),
              child: const Text('إعادة المحاولة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahListEmptyState extends StatelessWidget {
  const _SurahListEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded,
              size: 40, color: Color(0xFFDDD9D2)),
          const SizedBox(height: 12),
          Text(
            'لم تبدأ التقييم بعد',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).subsectionTitle.copyWith(
                  color: const Color(0xFF9A9A9A),
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'اضغط "صحيفتي" لتبدأ رحلتك',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).bodySecondary.copyWith(
                  color: const Color(0xFFB0B0B0),
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _UserOverviewData {
  const _UserOverviewData({
    required this.segments,
    required this.highlight,
    required this.surahCards,
    required this.ayatBySurahId,
  });

  final List<_OverviewSegment> segments;
  final _OverviewSegment? highlight;
  final List<_SurahProgressCardData> surahCards;
  final Map<int, List<Ayat>> ayatBySurahId;
}

class _OverviewSegment {
  const _OverviewSegment({
    required this.label,
    required this.percent,
    required this.verseCount,
    required this.color,
    required this.priority,
    required this.isProficient,
    required this.isReview,
  });

  final String label;
  final double percent;
  final int verseCount;
  final Color color;
  final int priority;
  final bool isProficient;
  final bool isReview;
}

class _MutableSurahProgress {
  _MutableSurahProgress({required this.surahId, required this.surahName});

  final int surahId;
  final String surahName;
  int totalVerses = 0;
  int evaluatedVerses = 0;
  int proficientVerses = 0;
  final verseEntries = <VerseChartEntry>[];
}

class _SurahProgressCardData {
  const _SurahProgressCardData({
    required this.surahId,
    required this.surahName,
    required this.totalVerses,
    required this.proficientVerses,
    required this.evaluatedVerses,
    required this.verseEntries,
  });

  final int surahId;
  final String surahName;
  final int totalVerses;
  final int proficientVerses;
  final int evaluatedVerses;
  final List<VerseChartEntry> verseEntries;

  double get proficientRatio =>
      totalVerses == 0 ? 0 : proficientVerses / totalVerses;

  double get proficientPercent => proficientRatio * 100;

  int get remainingVerses => math.max(totalVerses - proficientVerses, 0);

  double get remainingPercent =>
      totalVerses == 0 ? 0 : (remainingVerses * 100) / totalVerses;
}
