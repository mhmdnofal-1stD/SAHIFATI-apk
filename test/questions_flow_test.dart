import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart' as app_models;
import 'package:sahifaty/models/school.dart';
import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/school_level_content.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/questions_screen/questions_completion_screen.dart';
import 'package:sahifaty/screens/questions_screen/questions_screen.dart';
import 'package:sahifaty/screens/widgets/assessment_input_dialog.dart';

class _QuestionsTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'settings': 'Settings',
          'quick_questions': 'Quick questions',
          'switch_user': 'Switch user',
          'logout': 'Logout',
          'surah_number': 'Surah number',
          'surah_label': 'Surah',
          'evaluate': 'Evaluate',
          'no_verses_found_to_evaluate': 'No verses found to evaluate',
          'error_during_evaluation': 'Evaluation error: @error',
          'recommendations_label': 'Recommendations',
          'edit_recommendations': 'Edit recommendations',
          'recommendation_note_hint': 'Add note',
          'recommendation_note_save': 'Save',
          'recommendation_note_cancel': 'Cancel',
          'teacher_recommendations_empty': 'No recommendations',
          'juz_surahs_title': 'Surahs in Juz @juz',
          'juz_surahs_subtitle': 'Open any surah and assess it.',
          'surah_ayahs_title': 'Verses of @surah in Juz @juz',
          'no_verses_for_surah_in_juz': 'No verses available for this surah in the current juz.',
        },
      };
}

School _buildSchool({required List<SchoolLevel> levels}) {
  return School(
    schoolName: const {'en': 'Quick questions', 'ar': 'الأسئلة السريعة'},
    levels: levels,
  );
}

SchoolLevel _buildLevel({
  required String englishName,
  required List<SchoolLevelContent> content,
}) {
  return SchoolLevel(
    name: {
      'en': englishName,
      'ar': englishName,
    },
    content: content,
  );
}

Future<void> _pumpFlow(
  WidgetTester tester, {
  required Widget child,
  UsersProvider? usersProvider,
  EvaluationsProvider? evaluationsProvider,
  SchoolProvider? schoolProvider,
  LanguageProvider? languageProvider,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UsersProvider>.value(
          value: usersProvider ?? UsersProvider(),
        ),
        ChangeNotifierProvider<EvaluationsProvider>.value(
          value: evaluationsProvider ?? EvaluationsProvider(),
        ),
        ChangeNotifierProvider<SchoolProvider>.value(
          value: schoolProvider ?? SchoolProvider(),
        ),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: languageProvider ?? LanguageProvider(),
        ),
      ],
      child: GetMaterialApp(
        translations: _QuestionsTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        home: child,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('questions screen shows guided progress and summary CTA on final level',
      (tester) async {
    final usersProvider = UsersProvider();
    final evaluationsProvider = EvaluationsProvider();
    final schoolProvider = SchoolProvider();
    final content = SchoolLevelContent(
      id: 'content-1',
      type: 'ayahRange',
      surahId: 1,
      startAyah: 1,
      endAyah: 3,
    );

    schoolProvider.quickQuestionsSchool = _buildSchool(
      levels: [
        _buildLevel(englishName: 'Opening level', content: [content]),
      ],
    );

    evaluationsProvider.syncQuestionContentAyahs(
      content,
      [
        Ayat(
          id: 1,
          text: 'Example verse',
          ayahNo: 1,
          juz: 1,
          hizb: 1,
          surah: Surah(id: 1, nameAr: 'الفاتحة', ayahCount: 7),
          userEvaluation: UserEvaluation(ayahId: 1, memoId: 1),
        ),
      ],
    );

    await _pumpFlow(
      tester,
      child: const QuestionsScreen(),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      schoolProvider: schoolProvider,
    );

    expect(find.text('Kickoff assessment'), findsOneWidget);
    expect(find.text('Level 1 of 1'), findsOneWidget);
    expect(find.text('Completed units in this level'), findsOneWidget);
    expect(find.text('Completed levels'), findsOneWidget);
    expect(find.text('1 / 1'), findsNWidgets(2));

    await tester.scrollUntilVisible(
      find.text('View assessment summary'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('View assessment summary'), findsOneWidget);
    expect(find.text('Finish this round for now'), findsOneWidget);
  });

  testWidgets('questions screen keeps action labels visible on narrow widths',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final usersProvider = UsersProvider();
    final evaluationsProvider = EvaluationsProvider();
    final schoolProvider = SchoolProvider();
    final content = SchoolLevelContent(
      id: 'content-mobile-1',
      type: 'surah',
      surahId: 1,
      startAyah: 1,
      endAyah: 7,
    );

    schoolProvider.quickQuestionsSchool = _buildSchool(
      levels: [
        _buildLevel(englishName: 'Opening level', content: [content]),
      ],
    );

    await _pumpFlow(
      tester,
      child: const QuestionsScreen(),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      schoolProvider: schoolProvider,
    );

    expect(find.text('Rate the full unit at once'), findsOneWidget);
    expect(find.text('Review verse by verse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion summary shows honest skipped-state counts',
      (tester) async {
    await _pumpFlow(
      tester,
      child: const QuestionsCompletionScreen(
        skipped: true,
        totalLevels: 4,
        completedLevels: 1,
        totalItems: 8,
        completedItems: 3,
        lastReachedLevel: 2,
      ),
    );

    expect(find.text('Assessment summary'), findsOneWidget);
    expect(find.text('You ended this round early'), findsOneWidget);
    expect(find.text('3 / 8'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Continue to the Sahifa'), findsOneWidget);
    expect(find.text('Back to the questions'), findsOneWidget);
  });

  testWidgets('assessment dialog explains when comprehension options are unavailable',
      (tester) async {
    final evaluationsProvider = EvaluationsProvider()
      ..evaluations = [
        app_models.Evaluation(
          id: 1,
          code: 'STRONG',
          name: const {'en': 'Strong', 'ar': 'قوي'},
          type: 'memorization',
          color: '#00AA55',
        ),
      ];

    await _pumpFlow(
      tester,
      evaluationsProvider: evaluationsProvider,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showAssessmentInputDialog(
                  context: context,
                  evaluationsProvider: evaluationsProvider,
                  languageProvider: context.read<LanguageProvider>(),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Memorization assessment'), findsOneWidget);
    expect(
      find.text(
        'Comprehension options are not available in the current taxonomy, so this dialog will save memorization only.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tap the same value again to clear it. No changes are saved until you confirm.',
      ),
      findsOneWidget,
    );
  });
}