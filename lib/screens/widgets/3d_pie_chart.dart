// ignore_for_file: file_names

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import '../../controllers/evaluations_controller.dart';
import '../../controllers/general_controller.dart';

class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.evaluationsProvider,
    required this.languageProvider,
  });

  final EvaluationsProvider evaluationsProvider;
  final LanguageProvider languageProvider;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final evaluationsController = EvaluationsController();
    final generalController = GeneralController();

    final List<PieChartSectionData> sections = [];
    List<int> sectionEvaluationIds = [];
    for (int i = 0; i < generalController.dropdownOptions.length; i++) {
      final evaluation = evaluationsController.getEvaluationById(
          i, widget.evaluationsProvider);

      if (evaluation == null) continue;

      final value = evaluation.percentage?.toDouble() ?? 0;
      // if (value <= 0) continue; // Optional: Hide 0% sections

      final isTouched = sectionEvaluationIds.length == touchedIndex;
      final fontSize = isTouched ? 20.0 : 16.0;
      final radius = isTouched ? 90.0 : 80.0;
      final color = generalController.dropdownOptions[i]['color'] as Color;

      sections.add(
        PieChartSectionData(
          color: color,
          value: value,
          title: '\u200F${value.toStringAsFixed(1)}%\n'
              '\u200F${widget.evaluationsProvider.getName(evaluation.evaluationId, widget.languageProvider)}\n'
              '\u200F${"verse_count".trParams({
                'count': evaluation.verseCount.toString()
              })}',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xffffffff),
            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
          ),
          badgeWidget: isTouched
              ? _Badge(
                  widget.evaluationsProvider.getName(
                      evaluation.evaluationId, widget.languageProvider),
                  size: 40,
                  borderColor: color,
                )
              : null,
          badgePositionPercentageOffset: .98,
        ),
      );
      sectionEvaluationIds.add(evaluation.evaluationId);
    }

    return AspectRatio(
      aspectRatio: .8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(
                show: false,
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: sections,
            ),
          ),
          // Center Text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${sections[touchedIndex].value.toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (touchedIndex != -1)
                Text(
                  widget.evaluationsProvider
                          .getName(sectionEvaluationIds[touchedIndex],
                              widget.languageProvider)
                          .isEmpty
                      ? ""
                      : widget.evaluationsProvider.getName(
                          sectionEvaluationIds[touchedIndex],
                          widget.languageProvider),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
    this.text, {
    required this.size,
    required this.borderColor,
  });

  final String text;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size * 2.5,
      // wider for text
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
