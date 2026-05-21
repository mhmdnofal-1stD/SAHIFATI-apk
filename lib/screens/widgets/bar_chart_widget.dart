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

  String _formatVerseCount(num? value) {
    final effectiveValue = (value ?? 0).round();
    return effectiveValue.toString();
  }

  Widget _buildValueTag(
    BuildContext context, {
    required String labelText,
    required String percentText,
    required String verseCountText,
    required Color color,
    required bool compact,
    required bool inverted,
  }) {
    final t = AppTypography.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: inverted ? const Color(0xFFF2F6FB) : color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: inverted
            ? Border.all(color: color.withValues(alpha: 0.56), width: 1)
            : null,
        boxShadow: inverted
            ? const [
                BoxShadow(
                  color: Color(0x14132A4A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Flexible(
                child: Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.chartTooltip.copyWith(
                    color: inverted ? color : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact
                        ? (t.chartTooltip.fontSize ?? 12) - 1
                        : t.chartTooltip.fontSize,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(width: compact ? 4 : 6),
              Text(
                percentText,
                textDirection: TextDirection.ltr,
                style: t.chartTooltip.copyWith(
                  color: inverted ? color : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact
                      ? (t.chartTooltip.fontSize ?? 12) - 1
                      : t.chartTooltip.fontSize,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Text(
            verseCountText,
            textAlign: TextAlign.center,
            style: t.chartTooltip.copyWith(
              color: inverted ? color.withValues(alpha: 0.92) : Colors.white,
              fontSize: compact
                  ? (t.chartTooltip.fontSize ?? 12) - 2
                  : (t.chartTooltip.fontSize ?? 12) - 1,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).bodyDefault,
          ),
        ],
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
        final barHeight = isDesktop ? 40.0 : 32.0;
        final infoBoxMinWidth = isDesktop ? 154.0 : 132.0;
        final outsideTagWidth = isDesktop ? 148.0 : 126.0;
        final tinyBarThreshold = isDesktop ? 152.0 : 126.0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: EdgeInsets.all(isDesktop ? 22 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCE2DA)),
          ),
          child: Column(
            children: [
              for (final evaluation in visibleEntries) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, barConstraints) {
                          final percent = (evaluation.percentage ?? 0)
                              .toDouble()
                              .clamp(0, 100);
                          final color = evaluationsController
                              .getColorForChartEntry(evaluation);
                          final availableWidth = barConstraints.maxWidth;
                          final fillWidth = availableWidth * (percent / 100);
                          final infoBoxWidth =
                              fillWidth.clamp(infoBoxMinWidth, availableWidth);
                          final showOutsideTag = fillWidth < tinyBarThreshold;
                          final percentText =
                              '${_formatPercent(evaluation.percentage)}%';
                            final verseCountText =
                              '${_formatVerseCount(evaluation.verseCount)} آية';
                            final labelText =
                              evaluation.name[languageProvider.langCode] ?? '';

                          return Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6E6DE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Container(
                                width: fillWidth,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              if (fillWidth > 0 && !showOutsideTag)
                                Positioned(
                                  left: (availableWidth - fillWidth)
                                      .clamp(0, availableWidth),
                                  child: SizedBox(
                                    width: infoBoxWidth,
                                    height: barHeight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: _buildValueTag(
                                        context,
                                        labelText: labelText,
                                        percentText: percentText,
                                        verseCountText: verseCountText,
                                        color: color,
                                        compact: !isDesktop,
                                        inverted: false,
                                      ),
                                    ),
                                  ),
                                ),
                              if (fillWidth > 0 && showOutsideTag)
                                Positioned(
                                  left: ((availableWidth - fillWidth) -
                                          outsideTagWidth -
                                          8)
                                      .clamp(
                                    0,
                                    (availableWidth - outsideTagWidth)
                                        .clamp(0, availableWidth),
                                  ),
                                  child: SizedBox(
                                    width: outsideTagWidth,
                                    height: barHeight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: _buildValueTag(
                                        context,
                                        labelText: labelText,
                                        percentText: percentText,
                                        verseCountText: verseCountText,
                                        color: color,
                                        compact: true,
                                        inverted: true,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (evaluation != visibleEntries.last)
                  SizedBox(height: isDesktop ? 18 : 14),
              ],
            ],
          ),
        );
      },
    );
  }
}
