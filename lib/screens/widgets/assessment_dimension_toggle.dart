import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/evaluations_controller.dart';

class AssessmentDimensionToggle extends StatelessWidget {
  const AssessmentDimensionToggle({
    super.key,
    required this.selectedDimension,
    required this.onChanged,
  });

  final String selectedDimension;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    String label(String dimension) {
      if (dimension == EvaluationsController.comprehensionDimension) {
        return 'assessment_dimension_comprehension'.tr;
      }
      return 'assessment_dimension_memorization'.tr;
    }

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/evaluations_controller.dart';

class AssessmentDimensionToggle extends StatelessWidget {
  const AssessmentDimensionToggle({
    super.key,
    required this.selectedDimension,
    required this.onChanged,
  });

  final String selectedDimension;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    String label(String dimension) {
      if (dimension == EvaluationsController.comprehensionDimension) {
        return 'assessment_dimension_comprehension'.tr;
      }
      return 'assessment_dimension_memorization'.tr;
    }

    final dims = [
      EvaluationsController.memorizationDimension,
      EvaluationsController.comprehensionDimension,
    ];

    return SegmentedButton<String>(
      segments: dims
          .map(
            (d) => ButtonSegment<String>(
              value: d,
              label: Text(label(d)),
            ),
          )
          .toList(),
      selected: {selectedDimension},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Theme.of(context).colorScheme.primary,
        selectedForegroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}