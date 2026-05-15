import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/general_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/surahs_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/screens/widgets/assessment_dimension_toggle.dart';
import 'package:sahifaty/screens/widgets/custom_hizbs_dropdown.dart';

class _SurfaceTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'well_done': 'Well Done',
          'browse_verses': 'Browse Verses',
          'welcome_chart_retry': 'Retry',
          'thirds_icons': 'Thirds',
          'parts_icons': 'Parts',
          'hizbs_icons': 'Hizbs',
          'settings': 'Settings',
          'quick_questions': 'Quick Questions',
          'switch_user': 'Switch User',
          'logout': 'Logout',
          'assessment_dimension_memorization': 'Memorization',
          'assessment_dimension_comprehension': 'Comprehension',
          'main_screen_gateway_badge': 'Your reading and exploration gateway',
          'main_screen_resume_title': 'Resume your last reading',
          'main_screen_resume_body': 'Your last saved reading context was in Surah @surah through the @path path. You can return directly to the same reading position instead of starting over.',
          'main_screen_resume_action': 'Resume reading',
          'main_screen_chart_empty': 'Your Sahifa will start drawing a clearer reading summary here once real verse assessments are available.',
          'main_screen_chart_intro_first': 'Once your first assessments are recorded, this area will start showing a real summary of your reading path.',
          'main_screen_hizb_loading_title': 'Preparing the hizb paths',
          'main_screen_hizb_loading_body': 'We are loading the surahs behind each hizb so you only open paths that already have data.',
          'main_screen_hizb_error_title': 'The hizb paths are temporarily unavailable',
          'sahifa_screen_header_badge_first': 'This is the start of your Sahifa',
          'sahifa_screen_header_badge_returning': 'This Sahifa reads your current state',
          'sahifa_screen_header_body': 'This screen is not a separate dashboard. It is a quick summary that helps you understand your current state, then move into reading from a clearer starting point.',
          'sahifa_screen_metric_real_signal': 'Verses with real signal',
          'sahifa_screen_metric_current_dimension': 'Current dimension',
          'sahifa_screen_metric_remaining': 'Verses still without assessment',
          'sahifa_screen_resume_title': 'A saved reading session is waiting',
          'sahifa_screen_resume_body': 'If you left reading or came back after a refresh, you can resume directly from Surah @surah through the @path path.',
          'sahifa_screen_summary_title': 'Your Sahifa summary right now',
          'sahifa_screen_summary_body': 'This summary only explains your current state: what has actually been assessed, which dimension you are looking at now, and where you can continue into reading.',
          'sahifa_screen_loading_title': 'Preparing your summary',
          'sahifa_screen_loading_body': 'We are loading your current state before showing any chart so the screen does not imply progress that is not real.',
          'sahifa_screen_empty_title': 'There is not enough assessment signal yet',
          'sahifa_screen_error_title': 'We could not load the summary right now',
          'sahifa_screen_empty_body': 'Once you start assessing or build real reading data, this area will show an actual summary instead of a chart that implies missing data exists.',
          'sahifa_screen_top_signal_title': 'Strongest current signal',
          'sahifa_screen_top_signal_body': '@name currently covers @count verses in this view.',
          'sahifa_screen_comprehension_summary': 'This view counts only verses that currently carry a real comprehension assessment. Current total: @evaluated verses, with @remaining still outside this summary.',
          'sahifa_screen_memorization_summary': 'This summary is built from @evaluated verses that were actually categorized inside the Sahifa, while @remaining verses still remain outside this summary until they are assessed later.',
          'sahifa_screen_next_step_title': 'Next step: open reading from the path that fits you best',
          'sahifa_screen_next_step_body': 'The Sahifa clarifies the picture here, then lets you move quickly into exploration and reading without unnecessary detours.',
          'custom_hizb_preparing': 'Preparing this hizb...',
          'custom_hizb_error_subtitle': 'This path is not ready right now. Try again after loading completes.',
          'custom_hizb_empty_subtitle': 'No surahs are available for this hizb right now.',
          'custom_hizb_loading_snackbar': 'We are still preparing this hizb. Please try again in a moment.',
          'custom_hizb_error_snackbar': 'This hizb could not be prepared right now. Try reopening the hizbs tab.',
          'custom_hizb_empty_snackbar': 'No surahs are ready for this hizb right now.',
        },
      };
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required Widget child,
  UsersProvider? usersProvider,
  EvaluationsProvider? evaluationsProvider,
  GeneralProvider? generalProvider,
  SurahsProvider? surahsProvider,
}) async {
  Get.clearTranslations();
  Get.addTranslations(_SurfaceTranslations().keys);
  Get.locale = const Locale('en');
  Get.fallbackLocale = const Locale('en');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UsersProvider>.value(
          value: usersProvider ?? UsersProvider(),
        ),
        ChangeNotifierProvider<EvaluationsProvider>.value(
          value: evaluationsProvider ?? EvaluationsProvider(),
        ),
        ChangeNotifierProvider<GeneralProvider>.value(
          value: generalProvider ?? GeneralProvider(),
        ),
        ChangeNotifierProvider<SurahsProvider>.value(
          value: surahsProvider ?? SurahsProvider(),
        ),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: LanguageProvider(),
        ),
        ChangeNotifierProvider<SchoolProvider>.value(
          value: SchoolProvider(),
        ),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollConfiguration(
            behavior: const _NoStretchScrollBehavior(),
            child: ScaffoldMessenger(
              child: Material(
                child: Scaffold(
                  body: child,
                ),
              ),
            ),
          ),
        ),
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
    GeneralProvider().setView(FilterTypes.thirds);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('sahifa screen shows truthful empty summary state', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..totalCount = 0
      ..chartEvaluationData = [];

    await _pumpSurface(
      tester,
      child: const MainScreen(
        comesFirst: false,
        autoBootstrapChart: false,
        useResponsiveShell: false,
        useScaffoldFrame: false,
      ),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
    );

    expect(find.text('This Sahifa reads your current state'), findsOneWidget);
    expect(find.text('There is not enough assessment signal yet'), findsOneWidget);
    expect(find.byType(AssessmentDimensionToggle), findsNothing);
    expect(find.text('Browse Verses'), findsOneWidget);
  });

  testWidgets('sahifa screen exposes a saved reading resume path',
      (tester) async {
    await ReadingSessionStore().save(
      const ReadingSession(
        userId: 1,
        surah: Surah(id: 2, nameAr: 'Ø§Ù„Ø¨Ù‚Ø±Ø©', ayahCount: 286),
        filterTypeId: FilterTypes.parts,
        juz: 1,
        currentHizbQuarter: 3,
        shouldAutoResume: false,
      ),
    );

    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..totalCount = 0
      ..chartEvaluationData = [];

    await _pumpSurface(
      tester,
      child: const MainScreen(
        comesFirst: false,
        autoBootstrapChart: false,
        useResponsiveShell: false,
        useScaffoldFrame: false,
      ),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('A saved reading session is waiting'), findsOneWidget);
    expect(find.text('Resume reading'), findsWidgets);
  });

  testWidgets('sahifa screen shows chart summary when data exists', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..totalCount = 20
      ..chartEvaluationData = [
        ChartEvaluationData(
          evaluationId: 1,
          name: const {'en': 'Strong', 'ar': 'Ù‚ÙˆÙŠ'},
          code: 'STRONG',
          characterCount: 100,
          verseCount: 12,
          percentage: 60,
        ),
        ChartEvaluationData(
          evaluationId: 0,
          name: const {'en': 'Uncategorized', 'ar': 'ØºÙŠØ± Ù…ØµÙ†Ù'},
          code: 'UNCAT',
          characterCount: 50,
          verseCount: 8,
          percentage: 40,
        ),
      ];

    await _pumpSurface(
      tester,
      child: const MainScreen(
        comesFirst: false,
        autoBootstrapChart: false,
        useResponsiveShell: false,
        useScaffoldFrame: false,
      ),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
    );

    expect(find.byType(AssessmentDimensionToggle), findsOneWidget);
    expect(find.text('Strongest current signal'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('main screen explains active entry path', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()..isLoading = false;
    final generalProvider = GeneralProvider()..setView(FilterTypes.parts);

    await _pumpSurface(
      tester,
      child: const MainScreen(
        autoBootstrapChart: false,
        useResponsiveShell: false,
        useScaffoldFrame: false,
      ),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      generalProvider: generalProvider,
    );

    expect(find.text('Your reading and exploration gateway'), findsOneWidget);
    expect(find.text('Parts'), findsOneWidget);
  });

  testWidgets('main screen exposes a saved reading resume path',
      (tester) async {
    await ReadingSessionStore().save(
      const ReadingSession(
        userId: 1,
        surah: Surah(id: 36, nameAr: 'ÙŠØ³', ayahCount: 83),
        filterTypeId: FilterTypes.thirds,
        juz: 3,
        currentHizbQuarter: 18,
        shouldAutoResume: false,
      ),
    );

    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()..isLoading = false;
    final generalProvider = GeneralProvider()..setView(FilterTypes.parts);

    await _pumpSurface(
      tester,
      child: const MainScreen(
        autoBootstrapChart: false,
        useResponsiveShell: false,
        useScaffoldFrame: false,
      ),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      generalProvider: generalProvider,
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Resume your last reading'), findsOneWidget);
    expect(find.text('Resume reading'), findsOneWidget);
  });

  testWidgets('hizb button stays safe when its surahs are unavailable', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Sara', email: 'sara@test.local');

    await _pumpSurface(
      tester,
      child: const Scaffold(
        body: CustomHizbsButton(
          hizb: {'id': 1, 'name': 'First Hizb'},
        ),
      ),
      usersProvider: usersProvider,
      evaluationsProvider: EvaluationsProvider()..isLoading = false,
      surahsProvider: SurahsProvider(),
    );

    await tester.tap(find.text('First Hizb'));
    await tester.pump();

    expect(find.text('No surahs are ready for this hizb right now.'), findsOneWidget);
  });
}
