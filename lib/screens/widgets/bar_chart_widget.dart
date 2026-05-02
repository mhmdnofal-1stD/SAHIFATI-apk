import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import '../../controllers/evaluations_controller.dart';

class BarChartWidget extends StatelessWidget {
  const BarChartWidget({
    super.key,
    required this.evaluationsProvider,
    required this.languageProvider,
    this.includeUncategorized = true,
  });

  final EvaluationsProvider evaluationsProvider;
  final LanguageProvider languageProvider;
  final bool includeUncategorized;

  String _formatPercent(num? value) {
    final effectiveValue = (value ?? 0).toDouble();
    final text = effectiveValue.toStringAsFixed(2);
    if (text.endsWith('.00')) {
      return text.substring(0, text.length - 3);
    }
    if (text.endsWith('0')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }

  Widget _buildStateCard(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE2DA)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.of(context).bodyDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final evaluationsController = EvaluationsController();
    final visibleEntries = includeUncategorized
        ? evaluationsProvider.chartEvaluationData
        : evaluationsProvider.chartEvaluationData
            .where((entry) => entry.evaluationId != 0)
            .toList();

    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < visibleEntries.length; i++) {
      final evaluation = visibleEntries[i];

      final raw = evaluation.percentage ?? 0;
      final value = (raw * 100).round() / 100;

      final color = evaluationsController.getColorForChartEntry(evaluation);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    if (evaluationsProvider.isLoading && visibleEntries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (evaluationsProvider.chartLoadError != null &&
        evaluationsProvider.chartLoadError!.trim().isNotEmpty &&
        visibleEntries.isEmpty) {
      return _buildStateCard(context, evaluationsProvider.chartLoadError!);
    }

    if (visibleEntries.isEmpty) {
      final message = evaluationsProvider.chartFilters.hasAnyActive
          ? 'chart_filter_no_results'.tr
          : 'main_screen_chart_empty'.tr;
      return _buildStateCard(context, message);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        final labelWidth = isDesktop ? 100.0 : 72.0;
        final labelFontSize = isDesktop ? 12.0 : 10.0;
        final reservedLabelHeight = isDesktop ? 72.0 : 58.0;
        final reservedTopHeight = isDesktop ? 54.0 : 46.0;
        final chartHeight = isDesktop ? 360.0 : 300.0;
        final barWidth = isDesktop ? 24.0 : 16.0;
        final t = AppTypography.of(context);

        return SizedBox(
          height: chartHeight,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: false,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final evaluation = evaluationsProvider
                          .chartEvaluationData[group.x.toInt()];
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(2)}%\n',
                        t.chartTooltip,
                        children: [
                          TextSpan(
                            text: '${evaluation.verseCount} ${'verses'.tr}',
                            style: t.chartTooltip,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: reservedTopHeight,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= visibleEntries.length) {
                          return const SizedBox.shrink();
                        }

                        final evaluation = visibleEntries[index];
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: SizedBox(
                            width: labelWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'verse_count'.trParams({
                                      'count': (evaluation.verseCount ?? 0)
                                          .toString(),
                                    }),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.chartAxisTick.copyWith(
                                      fontSize: isDesktop ? 10 : 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${_formatPercent(evaluation.percentage)}%',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.chartAxisTick.copyWith(
                                      fontSize: isDesktop ? 10 : 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: reservedLabelHeight,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() < 0 ||
                            value.toInt() >= visibleEntries.length) {
                          return const SizedBox.shrink();
                        }

                        final evaluation = visibleEntries[value.toInt()];
                        return SideTitleWidget(
                          meta: meta,
                          space: 10,
                          child: SizedBox(
                            width: labelWidth,
                            child: Text(
                              evaluation.name[languageProvider.langCode] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: t.chartAxisLabel
                                  .copyWith(fontSize: labelFontSize),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isDesktop ? 36 : 28,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: t.chartAxisTick
                              .copyWith(fontSize: isDesktop ? 11 : 10),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  checkToShowHorizontalLine: (value) => value % 20 == 0,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.45),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    top: BorderSide.none,
                    bottom: BorderSide(color: Colors.black, width: 1),
                    left: BorderSide(color: Colors.black, width: 1),
                    right: BorderSide.none,
                  ),
                ),
                barGroups: barGroups
                    .map(
                      (group) => group.copyWith(
                        barRods: group.barRods
                            .map((rod) => rod.copyWith(width: barWidth))
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
