import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/screens/widgets/teacher_recommendation_badge.dart';

class _BadgeTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'teacher_recommendation_badge_tooltip':
              'Teacher recommendation (@count)',
          'teacher_recommendation_badge_sheet_title':
              'Teacher recommendations',
          'teacher_recommendation_badge_empty':
              'No active recommendations for this ayah.',
          'teacher_recommendation_badge_unknown_teacher': 'Unknown teacher',
          'teacher_recommendation_badge_delete': 'Delete recommendation',
          'teacher_recommendation_badge_source_teacher': 'From teacher',
          'teacher_recommendation_badge_status_seen': 'Seen',
          'teacher_recommendation_badge_status_sent': 'Sent',
          'teacher_recommendation_badge_status_failed': 'Delivery failed',
          'teacher_recommendation_badge_status_pending':
              'Pending notification',
        },
      };
}

Future<void> _pumpBadge(
  WidgetTester tester, {
  required List<TeacherRecommendation> recommendations,
  Future<bool> Function(TeacherRecommendation recommendation)? onDelete,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: _BadgeTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: TeacherRecommendationBadge(
            recommendations: recommendations,
            onDelete: onDelete,
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

  testWidgets('badge shows localized tooltip and recommendation sheet', (
    tester,
  ) async {
    await _pumpBadge(
      tester,
      recommendations: const [
        TeacherRecommendation(
          id: 1,
          teacherId: 3,
          studentId: 5,
          ayahId: 11,
          source: 'teacher',
          status: 'active',
          notified: 'pending',
        ),
      ],
    );

    await tester.longPress(find.byType(TeacherRecommendationBadge));
    await tester.pumpAndSettle();

    expect(find.text('Teacher recommendation (1)'), findsOneWidget);

    await tester.tap(find.byType(TeacherRecommendationBadge));
    await tester.pumpAndSettle();

    expect(find.text('Teacher recommendations'), findsOneWidget);
    expect(find.text('Unknown teacher'), findsOneWidget);
    expect(find.text('From teacher • Pending notification'), findsOneWidget);
  });

  testWidgets('badge shows localized empty state after deleting last recommendation', (
    tester,
  ) async {
    await _pumpBadge(
      tester,
      recommendations: const [
        TeacherRecommendation(
          id: 1,
          teacherId: 3,
          studentId: 5,
          ayahId: 11,
          source: 'teacher',
          status: 'active',
          notified: 'sent',
        ),
      ],
      onDelete: (_) async => true,
    );

    await tester.tap(find.byType(TeacherRecommendationBadge));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('No active recommendations for this ayah.'), findsOneWidget);
  });
}