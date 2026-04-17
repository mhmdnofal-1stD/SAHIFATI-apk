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
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';

    String label(String dimension) {
      if (dimension == EvaluationsController.comprehensionDimension) {
        return isArabic ? 'الفهم' : 'Comprehension';
      }
      return isArabic ? 'الحفظ' : 'Memorization';
    }

    Widget buildChip(String dimension) {
      return ChoiceChip(
        label: Text(label(dimension)),
        selected: selectedDimension == dimension,
        onSelected: (_) => onChanged(dimension),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        buildChip(EvaluationsController.memorizationDimension),
        buildChip(EvaluationsController.comprehensionDimension),
      ],
    );
  }
}