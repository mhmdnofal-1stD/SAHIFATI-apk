import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/general_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/surahs_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/first_pie_chart_screen/first_pie_chart_screen.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/screens/widgets/bar_chart_widget.dart';

class _FlowTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'well_done': 'Well done',
          'browse_verses': 'Browse verses',
          'thirds_icons': 'Thirds',
          'parts_icons': 'Parts',
          'hizbs_icons': 'Hizbs',
          'settings': 'Settings',
          'quick_questions': 'Quick questions',
          'switch_user': 'Switch user',
          'logout': 'Logout',
          'verses': 'verses',
          'main_screen_gateway_badge': 'Your reading and exploration gateway',
          'sahifa_screen_header_badge_first': 'This is the start of your Sahifa',
          'sahifa_screen_header_body': 'This screen is not a separate dashboard. It is a quick summary that helps you understand your current state, then move into reading from a clearer starting point.',
          'sahifa_screen_summary_title': 'Your Sahifa summary right now',
          'sahifa_screen_memorization_summary': 'This summary is built from @evaluated verses that were actually categorized inside the Sahifa, while @remaining verses still remain outside this summary until they are assessed later.',
          'sahifa_screen_metric_remaining': 'Verses still without assessment',
          'sahifa_screen_top_signal_title': 'Strongest current signal',
          'sahifa_screen_top_signal_body': '@name currently covers @count verses in this view.',
          'assessment_dimension_memorization': 'Memorization',
          'assessment_dimension_comprehension': 'Comprehension',
          'main_screen_hizb_error_title': 'We could not prepare the hizb path',
          'welcome_chart_retry': 'Retry',
        },
      };
}

Future<void> _pumpWithProviders(
  WidgetTester tester, {
  required Widget child,
  UsersProvider? usersProvider,
  EvaluationsProvider? evaluationsProvider,
  GeneralProvider? generalProvider,
  SurahsProvider? surahsProvider,
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
        ChangeNotifierProvider<GeneralProvider>.value(
          value: generalProvider ?? GeneralProvider(),
        ),
        ChangeNotifierProvider<SurahsProvider>.value(
          value: surahsProvider ?? SurahsProvider(),
        ),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: languageProvider ?? LanguageProvider(),
        ),
        ChangeNotifierProvider<SchoolProvider>.value(
          value: SchoolProvider(),
        ),
      ],
      child: GetMaterialApp(
        translations: _FlowTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        home: child,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    GeneralProvider().setView(FilterTypes.thirds);
  });

  tearDown(() {
    Get.reset();
    GeneralProvider().setView(FilterTypes.thirds);
  });

  testWidgets('first pie chart screen resolves to the initial Sahifa summary and hides uncategorized chart labels',
      (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, username: 'Amina', email: 'amina@test.dev');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..chartDimension = 'memorization'
      ..totalCount = 10
      ..chartEvaluationData = [
        ChartEvaluationData(
          evaluationId: 0,
          name: const {'en': 'Uncategorized', 'ar': 'غير مصنف'},
          code: 'UNCAT',
          color: '#999999',
          characterCount: 0,
          verseCount: 6,
          percentage: 60,
        ),
        ChartEvaluationData(
          evaluationId: 1,
          name: const {'en': 'Strong', 'ar': 'قوي'},
          code: 'STRONG',
          color: '#00AA55',
          characterCount: 0,
          verseCount: 4,
          percentage: 40,
        ),
      ];
    final languageProvider = LanguageProvider()..setLangCode('en');

    await _pumpWithProviders(
      tester,
      child: const FirstPieChartScreen(),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
    );

    expect(find.text('This is the start of your Sahifa'), findsOneWidget);
    expect(find.textContaining('4 verses that were actually categorized'), findsOneWidget);
    expect(find.text('Verses still without assessment'), findsOneWidget);
    expect(find.text('Strongest current signal'), findsOneWidget);
    expect(find.byType(BarChartWidget), findsOneWidget);
    expect(find.text('Uncategorized'), findsNothing);
  });

  testWidgets('main screen shows a resilient error state for the hizb path',
      (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 2, username: 'Huda', email: 'huda@test.dev');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..totalCount = 0;
    final generalProvider = GeneralProvider()..setView(FilterTypes.hizbs);
    final surahsProvider = SurahsProvider()
      ..isLoading = false
      ..hizbLoadError = 'Hizb path failed';
    final languageProvider = LanguageProvider()..setLangCode('en');

    await _pumpWithProviders(
      tester,
      child: const MainScreen(),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      generalProvider: generalProvider,
      surahsProvider: surahsProvider,
      languageProvider: languageProvider,
    );

    expect(find.text('Your reading and exploration gateway'), findsOneWidget);
    expect(find.text('Hizbs'), findsOneWidget);
    expect(find.text('We could not prepare the hizb path'), findsOneWidget);
    expect(find.text('Hizb path failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}