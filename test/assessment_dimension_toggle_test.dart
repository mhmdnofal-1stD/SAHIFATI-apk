import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/screens/widgets/assessment_dimension_toggle.dart';

class _ToggleTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'assessment_dimension_memorization': 'Memorization',
          'assessment_dimension_comprehension': 'Comprehension',
        },
        'ar': {
          'assessment_dimension_memorization': 'الحفظ',
          'assessment_dimension_comprehension': 'الفهم',
        },
      };
}

Future<void> _pumpToggle(
  WidgetTester tester, {
  required Locale locale,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: _ToggleTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en'),
      home: Material(
        child: Center(
          child: AssessmentDimensionToggle(
            selectedDimension: EvaluationsController.memorizationDimension,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
  });

  testWidgets('assessment dimension toggle shows translated English labels', (
    tester,
  ) async {
    await _pumpToggle(tester, locale: const Locale('en'));

    expect(find.text('Memorization'), findsOneWidget);
    expect(find.text('Comprehension'), findsOneWidget);
  });

  testWidgets('assessment dimension toggle shows translated Arabic labels', (
    tester,
  ) async {
    await _pumpToggle(tester, locale: const Locale('ar'));

    expect(find.text('الحفظ'), findsOneWidget);
    expect(find.text('الفهم'), findsOneWidget);
  });
}