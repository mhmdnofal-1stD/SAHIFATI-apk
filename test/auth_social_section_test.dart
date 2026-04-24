import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahifaty/screens/authentication_screens/widgets/auth_social_section.dart';

class _AuthSocialTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'auth_method_email': 'Email',
          'social_provider_google': 'Google',
          'social_provider_facebook': 'Facebook',
        },
        'ar': {
          'auth_method_email': 'البريد الإلكتروني',
          'social_provider_google': 'Google',
          'social_provider_facebook': 'Facebook',
        },
      };
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required Locale locale,
  required String statusMessage,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: _AuthSocialTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en'),
      home: Material(
        child: Center(
          child: AuthSocialSection(
            googleControl: const SizedBox(width: 20, height: 20),
            onFacebookPressed: () {},
            isBusy: false,
            statusMessage: statusMessage,
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

  testWidgets('auth social section keeps English status text left-to-right', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      locale: const Locale('en'),
      statusMessage: 'Google sign-in was interrupted.',
    );

    final textWidget = tester.widget<Text>(
      find.text('Google sign-in was interrupted.'),
    );

    expect(textWidget.textDirection, TextDirection.ltr);
  });

  testWidgets('auth social section keeps Arabic status text right-to-left', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      locale: const Locale('ar'),
      statusMessage: 'تمت مقاطعة تسجيل الدخول عبر Google.',
    );

    final textWidget = tester.widget<Text>(
      find.text('تمت مقاطعة تسجيل الدخول عبر Google.'),
    );

    expect(textWidget.textDirection, TextDirection.rtl);
  });
}