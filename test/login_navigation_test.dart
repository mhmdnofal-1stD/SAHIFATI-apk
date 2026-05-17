import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/authentication_screens/select_user_screen.dart';
import 'package:sahifaty/screens/authentication_screens/widgets/custom_auth_textfield.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('successful login navigation replaces the login route',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/login',
        getPages: [
          GetPage(
            name: '/login',
            page: () => const Scaffold(
              body: Text('login-route'),
            ),
          ),
          GetPage(
            name: '/browse',
            page: () => const Scaffold(
              body: Text('sahifa-destination'),
            ),
          ),
          GetPage(
            name: '/welcome',
            page: () => const Scaffold(
              body: Text('welcome-destination'),
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('login-route'), findsOneWidget);

    await navigateAfterSuccessfulLogin(
      userId: 99,
      isFirstLogin: false,
      hasActiveLicense: true,
      loadChartData: (_) async {},
    );

    await tester.pumpAndSettle();

    expect(find.text('login-route'), findsNothing);
    expect(find.text('sahifa-destination'), findsOneWidget);
  });

  test('successful login can resume a pending reading session first',
      () async {
    final readingSessionStore = ReadingSessionStore();
    await readingSessionStore.save(
      const ReadingSession(
        userId: 99,
        surah: Surah(id: 2, nameAr: 'البقرة', ayahCount: 286),
        filterTypeId: 2,
        juz: 1,
        currentHizbQuarter: 3,
        shouldAutoResume: true,
      ),
    );

    int? loadedChartUserId;
    String? replacedRoute;
    ReadingSession? resumedSession;

    await navigateAfterSuccessfulLogin(
      userId: 99,
      isFirstLogin: false,
      hasActiveLicense: true,
      loadChartData: (userId) async {
        loadedChartUserId = userId;
      },
      replaceRoute: (routeName, {parameters}) {
        replacedRoute = routeName;
      },
      resumeReadingSession: (session) {
        resumedSession = session;
      },
      readingSessionStore: readingSessionStore,
    );

    expect(loadedChartUserId, isNull);
    expect(replacedRoute, isNull);
    expect(resumedSession, isNotNull);
    expect(resumedSession!.surah.id, 2);
    expect(resumedSession!.currentHizbQuarter, 3);

    final storedSession = await readingSessionStore.loadForUser(99);
    expect(storedSession, isNotNull);
    expect(storedSession!.shouldAutoResume, isFalse);
  });

  testWidgets('pending license navigation replaces the login route with the activation gate',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/login',
        getPages: [
          GetPage(
            name: '/login',
            page: () => const Scaffold(
              body: Text('login-route'),
            ),
          ),
          GetPage(
            name: '/license-activation',
            page: () => const Scaffold(
              body: Text('license-activation-destination'),
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('login-route'), findsOneWidget);

    await navigateAfterSuccessfulLogin(
      userId: 99,
      isFirstLogin: false,
      hasActiveLicense: false,
      loadChartData: (_) async {},
    );

    await tester.pumpAndSettle();

    expect(find.text('login-route'), findsNothing);
    expect(find.text('license-activation-destination'), findsOneWidget);
  });

  testWidgets('authentication text field exposes an explicit semantics label',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CustomAuthenticationTextField(
            hintText: 'Email',
            semanticLabel: 'Email address',
            obscureText: false,
            textEditingController: controller,
            borderColor: Colors.grey,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.bySemanticsLabel('Email address'), findsOneWidget);

    semanticsHandle.dispose();
    controller.dispose();
  });

  testWidgets('account selector keeps an explicit empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UsersProvider>.value(
            value: UsersProvider(),
          ),
          ChangeNotifierProvider<EvaluationsProvider>.value(
            value: EvaluationsProvider(),
          ),
          ChangeNotifierProvider<LanguageProvider>.value(
            value: LanguageProvider(initialLangCode: 'en'),
          ),
        ],
        child: const GetMaterialApp(
          locale: Locale('en'),
          fallbackLocale: Locale('en'),
          home: SelectUserScreen(firstScreen: false),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.person_search_rounded), findsOneWidget);
  });
}