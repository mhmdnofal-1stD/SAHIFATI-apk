import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/authentication_screens/login_screen.dart';
import 'package:sahifaty/screens/authentication_screens/widgets/custom_auth_textfield.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('successful login navigation replaces the login route',
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
        ],
        child: const GetMaterialApp(
          home: LoginScreen(firstScreen: false),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await navigateAfterSuccessfulLogin(
      userId: 99,
      isFirstLogin: false,
      loadChartData: (_) async {},
      replaceRoute: (page) => Get.offAll(() => page),
      buildSahifaScreen: () => const Scaffold(
        body: Text('sahifa-destination'),
      ),
      buildWelcomeScreen: () => const Scaffold(
        body: Text('welcome-destination'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('sahifa-destination'), findsOneWidget);
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
}