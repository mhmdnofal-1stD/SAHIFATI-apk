import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/authentication_screens/login_screen.dart';
import 'package:sahifaty/screens/authentication_screens/select_user_screen.dart';
import 'package:sahifaty/screens/authentication_screens/widgets/custom_auth_textfield.dart';

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'auth_account_selector_title': 'Choose your way back in',
      'auth_account_selector_subtitle':
        'Saved accounts on this device are now part of the sign-in experience.',
      'auth_saved_accounts_label': 'Saved accounts on this device',
      'auth_saved_accounts_caption':
        'If a session is still valid you can continue immediately.',
      'auth_saved_accounts_count': 'Saved accounts: @count',
      'auth_saved_accounts_loading': 'Preparing your saved accounts...',
      'auth_saved_accounts_empty_title': 'No saved accounts yet',
      'auth_saved_accounts_empty_body':
        'Start with manual sign-in or create a new account.',
      'auth_saved_accounts_manual_login': 'Manual sign-in',
      'auth_saved_accounts_create_account': 'Create a new account',
      'auth_saved_accounts_current': 'Current account',
      'auth_saved_accounts_instant': 'Ready for instant access',
      'auth_saved_accounts_requires_login': 'Requires password entry',
      'auth_saved_accounts_continue': 'Continue',
      'auth_saved_accounts_remove': 'Remove account from this device',
      'auth_login_title': 'Sign in to Sahifati',
      'auth_login_subtitle_compact':
        'A calmer, faster surface that gets you into your account without visual noise.',
      'auth_mode_login': 'Sign in',
      'auth_mode_signup': 'New account',
      'auth_shell_badge': 'Compact product-ready flow',
      'remember_me': 'Remember Me',
      'forgot_password': 'Forgot Password',
      'continue_with_social': 'Or continue with',
      'social_auth_subtitle':
        'Use a trusted account to sign in or create your account faster.',
      'social_google_card_title': 'Google',
      'social_google_card_subtitle': 'Use a trusted Google account.',
      'social_facebook_card_title': 'Facebook',
      'social_facebook_card_subtitle':
        'Continue with the Facebook account you already use.',
      'social_provider_google': 'Google',
      'social_provider_facebook': 'Facebook',
      'auth_methods_label': 'Quick methods',
      'auth_methods_caption': 'Small icons. Direct access.',
      'auth_method_email': 'Email',
      'login_another_account': 'Login with another account',
      'create_account_action': 'Sign Up',
      'already_have_account': 'Already have an account?',
      'create_account': 'Sign Up',
      'email_label': 'Email',
      'email_hint': 'example@example.com',
      'password_label': 'Password',
      'password_hint': 'Enter Password',
      'login': 'Login',
      'invalid_credentials': 'Invalid email or password',
      'all_fields_required': 'All fields are required',
      'invalid_email': 'Enter a valid email',
      'generic_error': 'Something went wrong. Please try again.',
    },
    };
}

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
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UsersProvider>.value(
            value: UsersProvider(),
          ),
          ChangeNotifierProvider<EvaluationsProvider>.value(
            value: EvaluationsProvider(),
          ),
        ],
        child: GetMaterialApp(
          initialRoute: '/login',
          getPages: [
            GetPage(
              name: '/login',
              page: () => const LoginScreen(firstScreen: false),
            ),
            GetPage(
              name: '/sahifa',
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
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await navigateAfterSuccessfulLogin(
      userId: 99,
      isFirstLogin: false,
      loadChartData: (_) async {},
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
        ],
        child: GetMaterialApp(
          translations: _TestTranslations(),
          locale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          home: const SelectUserScreen(firstScreen: false),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.person_search_rounded), findsOneWidget);
  });
}