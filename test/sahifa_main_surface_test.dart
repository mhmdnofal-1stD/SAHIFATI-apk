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
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/screens/sahifa_screen/sahifa_screen.dart';
import 'package:sahifaty/screens/widgets/assessment_dimension_toggle.dart';
import 'package:sahifaty/screens/widgets/custom_hizbs_dropdown.dart';

class _SurfaceTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'well_done': 'Well Done',
          'browse_verses': 'Browse Verses',
          'thirds_icons': 'Thirds',
          'parts_icons': 'Parts',
          'hizbs_icons': 'Hizbs',
          'settings': 'Settings',
          'quick_questions': 'Quick Questions',
          'switch_user': 'Switch User',
          'logout': 'Logout',
        },
      };
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required Widget child,
  UsersProvider? usersProvider,
  EvaluationsProvider? evaluationsProvider,
  GeneralProvider? generalProvider,
  SurahsProvider? surahsProvider,
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
          value: LanguageProvider(),
        ),
        ChangeNotifierProvider<SchoolProvider>.value(
          value: SchoolProvider(),
        ),
      ],
      child: GetMaterialApp(
        translations: _SurfaceTranslations(),
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
    GeneralProvider().setView(FilterTypes.thirds);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('sahifa screen shows truthful empty summary state', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, fullName: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..totalCount = 0
      ..chartEvaluationData = [];

    await _pumpSurface(
      tester,
      child: const SahifaScreen(firstScreen: false),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
    );

    expect(find.text('This Sahifa reads your current state'), findsOneWidget);
    expect(find.text('There is not enough assessment signal yet'), findsOneWidget);
    expect(find.byType(AssessmentDimensionToggle), findsNothing);
    expect(find.text('Browse Verses'), findsOneWidget);
  });

  testWidgets('sahifa screen shows chart summary when data exists', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, fullName: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()
      ..isLoading = false
      ..totalCount = 20
      ..chartEvaluationData = [
        ChartEvaluationData(
          evaluationId: 1,
          name: const {'en': 'Strong', 'ar': 'قوي'},
          code: 'STRONG',
          characterCount: 100,
          verseCount: 12,
          percentage: 60,
        ),
        ChartEvaluationData(
          evaluationId: 0,
          name: const {'en': 'Uncategorized', 'ar': 'غير مصنف'},
          code: 'UNCAT',
          characterCount: 50,
          verseCount: 8,
          percentage: 40,
        ),
      ];

    await _pumpSurface(
      tester,
      child: const SahifaScreen(firstScreen: false),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
    );

    expect(find.byType(AssessmentDimensionToggle), findsOneWidget);
    expect(find.text('Strongest current signal'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('main screen explains active entry path', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, fullName: 'Sara', email: 'sara@test.local');
    final evaluationsProvider = EvaluationsProvider()..isLoading = false;
    final generalProvider = GeneralProvider()..setView(FilterTypes.parts);

    await _pumpSurface(
      tester,
      child: const MainScreen(),
      usersProvider: usersProvider,
      evaluationsProvider: evaluationsProvider,
      generalProvider: generalProvider,
    );

    expect(find.text('Your reading and exploration gateway'), findsOneWidget);
    expect(find.text('Start through parts'), findsOneWidget);
  });

  testWidgets('hizb button stays safe when its surahs are unavailable', (tester) async {
    final usersProvider = UsersProvider()
      ..selectedUser = User(id: 1, fullName: 'Sara', email: 'sara@test.local');

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