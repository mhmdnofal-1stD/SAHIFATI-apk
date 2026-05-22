import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/core/constants/colors.dart';
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
          'welcome_chart_retry': 'Retry',
          'questions_screen_level_load_generic_error': 'We could not prepare this level right now. Please try again.',
          'questions_screen_title': 'Kickoff assessment',
          'questions_screen_empty_loading_title': 'Preparing the kickoff questions',
          'questions_screen_empty_no_levels_title': 'No question levels are available right now',
          'questions_screen_empty_loading_body': 'We are loading the short school used for the opening assessment.',
          'questions_screen_empty_no_levels_body': 'You can retry now, or come back and reopen the assessment in a moment.',
          'questions_screen_level_eyebrow': 'Level @current of @total',
          'questions_screen_level_fallback_title': 'Kickoff level',
          'questions_screen_level_subtitle': 'Assess each unit with the right level of detail: one score for the full unit, or verse-by-verse review when precision matters.',
          'questions_screen_status_loading_title': 'Preparing this level',
          'questions_screen_status_loading_body': 'We load the verses and their current assessment state together so the cards stay accurate and stable.',
          'questions_screen_status_error_title': 'This level could not be loaded',
          'questions_screen_empty_level_title': 'This level does not contain units yet',
          'questions_screen_empty_level_body': 'You can move to the next level or finish this round and continue to the Sahifa.',
          'questions_screen_footer_hint': 'When you finish this round, you will see a summary page before entering the Sahifa instead of a transient snackbar.',
          'questions_screen_summary_label': 'View assessment summary',
          'questions_screen_finish_now_label': 'Finish this round for now',
          'questions_screen_metric_completed_units': 'Completed units in this level',
          'questions_screen_metric_completed_levels': 'Completed levels',
          'questions_completion_open_sahifa_error': 'We could not open the Sahifa right now. Please try again in a moment.',
          'questions_completion_title': 'Assessment summary',
          'questions_completion_badge_skipped': 'You ended this round early',
          'questions_completion_badge_complete': 'The kickoff assessment is complete',
          'questions_completion_heading_skipped': 'This summary shows your current state honestly before you continue to the Sahifa. You can come back later to finish the remaining units.',
          'questions_completion_heading_complete': 'You completed the opening assessment round. Before entering the Sahifa, here is a quick view of what was covered and what still remains, without misleading assumptions.',
          'questions_completion_metric_completed_units': 'Completed units',
          'questions_completion_metric_completed_levels': 'Completed levels',
          'questions_completion_metric_last_level': 'Last level reached',
          'questions_completion_metric_remaining_units': 'Remaining units',
          'questions_completion_meaning_title': 'What does this mean?',
          'questions_completion_meaning_body_skipped': 'The Sahifa will open based only on what was actually assessed. Incomplete units remain outside your progress until you come back to them later.',
          'questions_completion_meaning_body_complete': 'The next Sahifa view will rely on this kickoff assessment plus any real evaluation data you already had. If some units remain, they still need assessment later.',
          'questions_completion_opening_label': 'Opening the Sahifa...',
          'questions_completion_continue_label': 'Continue to the Sahifa',
          'questions_completion_back_label': 'Back to the questions',
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
          'cancel': 'Cancel',
          'save': 'Save',
          'verses_definite': 'Verses',
          'hizb': 'Hizb',
          'hizb_quarter': 'Hizb Quarter',
          'juz_prefix': 'Juz',
          'unit': 'Unit',
          'assessment_dialog_title_both': 'Memorization & Comprehension',
          'assessment_dialog_title_memorization': 'Memorization assessment',
          'assessment_dialog_title_comprehension': 'Comprehension assessment',
          'assessment_dialog_title_unavailable': 'No assessment options are available',
          'assessment_dialog_no_values': 'No assessment values are configured for the current environment, so a new evaluation cannot be saved from this dialog yet.',
          'assessment_dimension_memorization': 'Memorization',
          'assessment_dimension_comprehension': 'Comprehension',
          'assessment_dialog_memorization_unavailable': 'Memorization options are not available in the current taxonomy, so this dialog will save comprehension only.',
          'assessment_dialog_comprehension_unavailable': 'Comprehension options are not available in the current taxonomy, so this dialog will save memorization only.',
          'assessment_dialog_hint': 'Tap the same value again to clear it. No changes are saved until you confirm.',
          'content_item_card_recommendation_deleted': 'Recommendation deleted.',
          'content_item_card_recommendation_delete_error': 'Unable to delete the recommendation right now.',
          'content_item_card_assess_unit_title': 'Assess @unit',
          'content_item_card_assess_verse_title': 'Assess verse @ayah',
          'content_item_card_assess_surah_title': 'Assess @surah',
          'content_item_card_verse_label': 'Verse @ayah',
          'content_item_card_support_ayah_range': 'This slice is reviewed verse by verse so the result stays accurate.',
          'content_item_card_support_juz': 'You can rate the full juz or drill into individual surahs and verses.',
          'content_item_card_support_default': 'Choose one rating for the whole unit or review each verse in detail.',
          'content_item_card_status_refreshing': 'Refreshing status',
          'content_item_card_status_completed': 'This unit has been assessed',
          'content_item_card_status_pending': 'This unit is still waiting for assessment',
          'content_item_card_action_rate_unit_title': 'Rate the full unit at once',
          'content_item_card_action_rate_unit_subtitle': 'Choose one rating to apply across every verse in this unit.',
          'content_item_card_action_review_verses_title': 'Review verse by verse',
          'content_item_card_action_review_verses_subtitle': 'Open the individual verses when you need a more precise review.',
          'content_item_card_action_start_verses_title': 'Start verse assessment',
          'content_item_card_action_start_verses_subtitle': 'This content type does not support a single unit-wide rating.',
          'content_item_card_juz_hint': 'Tap the card itself to open the surahs inside this juz.',
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

    schoolProvider.schools = [
      _buildSchool(
        levels: [
          _buildLevel(englishName: 'Opening level', content: [content]),
        ],
      ),
    ];

    evaluationsProvider.syncQuestionContentAyahs(
      content,
      [
        Ayat(
          id: 1,
          text: 'Example verse',
          ayahNo: 1,
          juz: 1,
          hizb: 1,
          surah: const Surah(id: 1, nameAr: 'الفاتحة', ayahCount: 7),
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

    schoolProvider.schools = [
      _buildSchool(
        levels: [
          _buildLevel(englishName: 'Opening level', content: [content]),
        ],
      ),
    ];

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

  testWidgets('assessment dialog shows localized evaluation names instead of codes',
      (tester) async {
    final evaluationsProvider = EvaluationsProvider()
      ..evaluations = [
        app_models.Evaluation(
          id: 1,
          code: 'g',
          name: const {'en': 'Mastered', 'ar': 'متمكن'},
          type: 'memorization',
          color: '#1A7F37',
        ),
        app_models.Evaluation(
          id: 2,
          code: '1',
          name: const {'en': 'Yes', 'ar': 'نعم'},
          type: 'comprehension',
          color: '#1A73E8',
        ),
      ];
    final languageProvider = LanguageProvider()..setLangCode('ar');

    await _pumpFlow(
      tester,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
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

    expect(find.text('متمكن'), findsOneWidget);
    expect(find.text('نعم'), findsOneWidget);
    expect(find.text('g'), findsNothing);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('assessment dialog save button uses a clear enabled color after changes',
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
    final languageProvider = LanguageProvider()..setLangCode('en');

    await _pumpFlow(
      tester,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
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

    final saveFinder = find.widgetWithText(FilledButton, 'Save');
    FilledButton saveButton = tester.widget<FilledButton>(saveFinder);

    expect(saveButton.onPressed, isNull);
    expect(
      saveButton.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      AppColors.primaryPurple.withValues(alpha: 0.32),
    );

    await tester.tap(find.text('Strong'));
    await tester.pumpAndSettle();

    saveButton = tester.widget<FilledButton>(saveFinder);
    expect(saveButton.onPressed, isNotNull);
    expect(
      saveButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.primaryPurple,
    );
  });
}