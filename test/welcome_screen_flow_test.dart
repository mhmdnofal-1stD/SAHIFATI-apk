import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/welcome_screen/welcome_screen.dart';
import 'package:sahifaty/screens/widgets/assessment_dimension_toggle.dart';

class _WelcomeTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'welcome_back': 'Welcome Back',
          'welcome_msg':
              'Start with a short kickoff assessment so we can build a more useful Sahifa from day one.',
          'start_evaluation': 'Start the kickoff assessment',
          'welcome_kickoff_badge':
              'A guided kickoff, not a placeholder screen',
          'welcome_kickoff_title':
              'Start with a short assessment that builds your Sahifa on real signal',
          'welcome_kickoff_subtitle':
              'This is not a decorative step. It gives Sahifaty a first reading of your memorization and comprehension so your starting point feels earned, not generic.',
          'welcome_kickoff_value_1_title': 'Short and focused',
          'welcome_kickoff_value_1_body':
              'A few minutes are enough to capture a practical first picture before you continue.',
          'welcome_kickoff_value_2_title': 'Builds your starting point',
          'welcome_kickoff_value_2_body':
              'Its result shapes the first progress view and early recommendations around your real level.',
          'welcome_kickoff_value_3_title': 'You can return later',
          'welcome_kickoff_value_3_body':
              'You may enter the Sahifa now and come back later, but the experience becomes more useful if you start here.',
          'welcome_kickoff_step_1_title': '1. Answer the kickoff questions',
          'welcome_kickoff_step_1_body':
              'We prepare the quick-questions school first, then take you straight into the opening assessment.',
          'welcome_kickoff_step_2_title': '2. We read your first signal',
          'welcome_kickoff_step_2_body':
              'After that, your Sahifa starts from a more truthful point instead of a generic default state.',
          'welcome_kickoff_step_3_title': '3. Continue where it helps most',
          'welcome_kickoff_step_3_body':
              'From there you can keep reading, review your Sahifa, and return to deeper assessment later.',
          'welcome_chart_title': 'Your current snapshot',
          'welcome_chart_subtitle':
              'We only show it when real evaluation data exists, not as a grey placeholder that looks like progress.',
          'welcome_chart_loading_title': 'Preparing your first snapshot',
          'welcome_chart_loading_body':
              'We are checking whether there is any real signal worth showing on this screen yet.',
          'welcome_chart_empty_title': 'No evaluation data yet',
          'welcome_chart_empty_body':
              'Once you finish the kickoff assessment, this area will show your first truthful summary instead of invented percentages or a misleading chart.',
          'welcome_chart_error_title':
              'We could not load the snapshot right now',
          'welcome_chart_error_body':
              'You can retry, or start the assessment now and let the chart appear after real data exists.',
          'welcome_chart_retry': 'Retry',
          'welcome_chart_top_label': 'Strongest current signal',
          'welcome_chart_total_count':
              '@count verses included in the current summary',
          'welcome_dimension_hint':
              'Switch between memorization and comprehension only when there is real data to compare.',
          'welcome_cta_title': 'What would you like to do now?',
          'welcome_cta_body':
              'The recommended path is to start the kickoff assessment now so the Sahifa becomes useful immediately.',
          'welcome_primary_cta_loading':
              'Preparing the kickoff questions...',
          'welcome_primary_cta_caption':
              'Expected time: about 3 minutes. We will take you straight into the opening questions.',
          'welcome_secondary_cta': 'Open the Sahifa now',
          'welcome_secondary_cta_loading': 'Opening your Sahifa...',
          'welcome_secondary_cta_caption':
              'If you prefer to explore first, you can enter now and return to the assessment later from inside your journey.',
          'welcome_kickoff_error_missing_user':
              'This step cannot start until the current session is restored correctly.',
          'welcome_kickoff_generic_error':
              'We could not prepare this step right now. Please try again in a moment.',
        },
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('welcome screen shows truthful empty state without chart toggle',
      (tester) async {
    final usersProvider = UsersProvider();
    usersProvider.selectedUser = null;
    final evaluationsProvider = EvaluationsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UsersProvider>.value(value: usersProvider),
          ChangeNotifierProvider<EvaluationsProvider>.value(
            value: evaluationsProvider,
          ),
          ChangeNotifierProvider<SchoolProvider>.value(value: SchoolProvider()),
        ],
        child: GetMaterialApp(
          translations: _WelcomeTranslations(),
          locale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          home: const WelcomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No evaluation data yet'), findsOneWidget);
    expect(find.byType(AssessmentDimensionToggle), findsNothing);
    expect(find.text('Start the kickoff assessment'), findsOneWidget);
    expect(find.text('Open the Sahifa now'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('welcome screen shows truthful chart and toggle when data exists',
      (tester) async {
    final usersProvider = UsersProvider();
    usersProvider.selectedUser = null;
    final evaluationsProvider = EvaluationsProvider()
      ..chartDimension = 'memorization'
      ..totalCount = 24
      ..chartEvaluationData = [
        ChartEvaluationData(
          evaluationId: 1,
          name: const {'en': 'Strong', 'ar': 'متمكن'},
          code: 'STRONG',
          color: '#00AA55',
          characterCount: 120,
          verseCount: 14,
          percentage: 58,
        ),
        ChartEvaluationData(
          evaluationId: 2,
          name: const {'en': 'Needs review', 'ar': 'مراجعة'},
          code: 'REVIEW',
          color: '#FFAA00',
          characterCount: 80,
          verseCount: 10,
          percentage: 42,
        ),
      ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UsersProvider>.value(value: usersProvider),
          ChangeNotifierProvider<EvaluationsProvider>.value(
            value: evaluationsProvider,
          ),
          ChangeNotifierProvider<SchoolProvider>.value(value: SchoolProvider()),
        ],
        child: GetMaterialApp(
          translations: _WelcomeTranslations(),
          locale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          home: const WelcomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AssessmentDimensionToggle), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Strongest current signal'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('No evaluation data yet'), findsNothing);
  });
}