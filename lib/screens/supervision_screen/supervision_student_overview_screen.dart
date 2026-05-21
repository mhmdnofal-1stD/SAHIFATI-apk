import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ayat_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../models/ayat.dart';
import '../../models/evaluation.dart';
import '../../models/user_evaluation.dart';
import '../../services/evaluations_services.dart';
import '../widgets/surah_verse_chart.dart';
import 'supervision_metric_utils.dart';

class SupervisionStudentOverviewScreen extends StatefulWidget {
  const SupervisionStudentOverviewScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  final int studentId;
  final String studentName;

  @override
  State<SupervisionStudentOverviewScreen> createState() =>
      _SupervisionStudentOverviewScreenState();
}

class _SupervisionStudentOverviewScreenState
    extends State<SupervisionStudentOverviewScreen> {
  final EvaluationsServices _evaluationsServices = EvaluationsServices();
  final AyatController _ayatController = AyatController();
  late Future<_StudentOverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<List<UserEvaluation>> _loadAllUserEvaluations() async {
    const limit = 1000;
    var page = 1;
    var totalPages = 1;
    final collected = <UserEvaluation>[];

    while (page <= totalPages) {
      final response = await _evaluationsServices.getUserEvaluationsPage(
        widget.studentId,
        limit: limit,
        page: page,
      );
      collected.addAll(response.data);
      totalPages = response.totalPages > 0 ? response.totalPages : 1;
      page += 1;
    }

    return collected;
  }

  Future<_StudentOverviewData> _load() async {
    final results = await Future.wait<Object>([
      _evaluationsServices.getAllEvaluations(type: 'memorization'),
      _loadAllUserEvaluations(),
      _ayatController.loadAllAyat(),
    ]);

    return _buildOverview(
      evaluations: (results[0] as List<Evaluation>)
          .where((evaluation) => evaluation.id != null)
          .toList(growable: false),
      userEvaluations: results[1] as List<UserEvaluation>,
      allAyat: results[2] as List<Ayat>,
    );
  }

  _StudentOverviewData _buildOverview({
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
    final surahStatsById = <int, _MutableSurahProgress>{};
    final overallCharacterCounts = <int, int>{};
    final overallVerseCounts = <int, int>{};
    var totalCharacters = 0;

    for (final ayah in allAyat) {
      final ayahId = ayah.id;
      if (ayahId == null) {
        continue;
      }

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

      // Always add a chart entry (score 0 = unclassified) so every verse
      // appears in the chart regardless of evaluation status.
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

      if (memoId == null || memoId <= 0) {
        continue;
      }

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
        .where((segment) => segment.verseCount > 0 && segment.percent > 0)
        .toList(growable: false)
      ..sort((left, right) {
        final priorityCompare = left.priority.compareTo(right.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }
        return right.percent.compareTo(left.percent);
      });

    _OverviewSegment? highlight;
    for (final segment in segments) {
      if (segment.isProficient) {
        highlight = segment;
        break;
      }
    }
    highlight ??= segments.isNotEmpty ? segments.first : null;

    final surahCards = surahStatsById.values
        .where((surah) => surah.evaluatedVerses > 0)
        .map(
          (surah) => _SurahProgressCardData(
            surahId: surah.surahId,
            surahName: surah.surahName,
            totalVerses: surah.totalVerses,
            proficientVerses: surah.proficientVerses,
            evaluatedVerses: surah.evaluatedVerses,
            verseEntries: List<VerseChartEntry>.unmodifiable(surah.verseEntries),
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.surahId.compareTo(right.surahId));

    return _StudentOverviewData(
      segments: segments,
      highlight: highlight,
      surahCards: surahCards,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: FutureBuilder<_StudentOverviewData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryPurple),
              );
            }

            if (snapshot.hasError) {
              return _OverviewErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _reload,
              color: AppColors.primaryPurple,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 30,
                          color: Color(0xFF161616),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E1D5)),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFFFF7A76),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (data.segments.isEmpty)
                    _OverviewEmptyState(studentName: widget.studentName)
                  else
                    _SummaryCard(
                      studentName: widget.studentName,
                      segments: data.segments,
                      highlight: data.highlight,
                    ),
                  const SizedBox(height: 26),
                  Text(
                    'السور التي يتم تقييمها',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: AppTypography.of(context).subsectionTitle.copyWith(
                          color: const Color(0xFF7A7A7A),
                          fontSize: 19,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (data.surahCards.isEmpty)
                    const _SurahListEmptyState()
                  else
                    ...data.surahCards.map(
                      (surah) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SurahProgressCard(data: surah),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.studentName,
    required this.segments,
    required this.highlight,
  });

  final String studentName;
  final List<_OverviewSegment> segments;
  final _OverviewSegment? highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12213A52),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 360;
          final donut = _DonutSummary(
            segments: segments,
            highlight: highlight,
          );
          final details = _SummaryDetails(
            studentName: studentName,
            segments: segments,
          );

          if (stacked) {
            return Column(
              children: [
                donut,
                const SizedBox(height: 18),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _DonutSummary extends StatelessWidget {
  const _DonutSummary({required this.segments, required this.highlight});

  final List<_OverviewSegment> segments;
  final _OverviewSegment? highlight;

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

    return SizedBox(
      width: 152,
      height: 152,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              startDegreeOffset: 90,
              sections: segments
                  .map(
                    (segment) => PieChartSectionData(
                      color: segment.color,
                      value: math.max(segment.percent, 0.01),
                      radius: 20,
                      title: '',
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${supervisionFormatPercent(effectiveHighlight.percent)}%',
                textDirection: TextDirection.ltr,
                style: AppTypography.of(context).pageHeading.copyWith(
                      color: const Color(0xFF151515),
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                effectiveHighlight.label,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context).bodyDefault.copyWith(
                      color: const Color(0xFF202020),
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryDetails extends StatelessWidget {
  const _SummaryDetails({required this.studentName, required this.segments});

  final String studentName;
  final List<_OverviewSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          studentName,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.of(context).pageHeading.copyWith(
                color: const Color(0xFF151515),
                fontSize: 26,
              ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: segments.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 46,
          ),
          itemBuilder: (context, index) {
            return _MetricPill(segment: segments[index]);
          },
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.segment});

  final _OverviewSegment segment;

  /// Pick a legible text color based on the background luminance.
  static Color _textColor(Color bg) {
    return bg.computeLuminance() > 0.45
        ? const Color(0xFF1E1E1E)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final textCol = _textColor(segment.color);
    return Container(
      decoration: BoxDecoration(
        color: segment.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '${segment.label} (%${supervisionFormatPercent(segment.percent)})',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.of(context).buttonSecondary.copyWith(
              color: textCol,
              fontSize: 12.5,
            ),
      ),
    );
  }
}

class _SurahProgressCard extends StatefulWidget {
  const _SurahProgressCard({required this.data});

  final _SurahProgressCardData data;

  @override
  State<_SurahProgressCard> createState() => _SurahProgressCardState();
}

class _SurahProgressCardState extends State<_SurahProgressCard> {
  bool _expanded = false;

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
          Text(
            data.surahName,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: AppTypography.of(context).pageHeading.copyWith(
                  color: const Color(0xFF191919),
                  fontSize: 26,
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
          // ─── Expandable verse chart ───
          if (_expanded && data.verseEntries.isNotEmpty) ...
            [
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
            const Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: Color(0xFFB45309),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: AppTypography.of(context).bodyDefault,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              child: Text(
                'welcome_chart_retry'.tr,
                style: AppTypography.of(context)
                    .buttonPrimary
                    .copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewEmptyState extends StatelessWidget {
  const _OverviewEmptyState({required this.studentName});

  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6E0D6)),
      ),
      child: Column(
        children: [
          Text(
            studentName,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).pageHeading.copyWith(
                  color: const Color(0xFF151515),
                  fontSize: 24,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد بيانات تقييم محفوظة لهذا الطالب حتى الآن.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).bodySecondary.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
        ],
      ),
    );
  }
}

class _SurahListEmptyState extends StatelessWidget {
  const _SurahListEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E0D6)),
      ),
      child: Text(
        'لم يتم تقييم أي سورة لهذا الطالب بعد.',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: AppTypography.of(context).bodySecondary.copyWith(
              color: const Color(0xFF6B7280),
            ),
      ),
    );
  }
}

class _StudentOverviewData {
  const _StudentOverviewData({
    required this.segments,
    required this.highlight,
    required this.surahCards,
  });

  final List<_OverviewSegment> segments;
  final _OverviewSegment? highlight;
  final List<_SurahProgressCardData> surahCards;
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