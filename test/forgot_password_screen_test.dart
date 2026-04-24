import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/authentication_screens/forget_password_screen.dart';

class _ForgotPasswordTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'auth_mode_login': 'Sign in',
          'auth_mode_signup': 'New account',
          'forgot_password_preview_request_error':
              'The reset link could not be sent right now. Please try again shortly.',
          'forgot_password_preview_reset_error':
              'The password reset could not be completed right now even though the link is still valid. Please try again shortly.',
          'forgot_password_validation_password_required':
              'Enter a new password',
          'forgot_password_validation_password_length':
              'Password must be at least 8 characters',
          'forgot_password_validation_password_uppercase':
              'Password must include at least one uppercase letter',
          'forgot_password_validation_password_lowercase':
              'Password must include at least one lowercase letter',
          'forgot_password_validation_password_number':
              'Password must include at least one number',
          'forgot_password_validation_password_symbol':
              'Password must include at least one symbol',
          'forgot_password_validation_email_required':
              'Enter the email linked to your account',
          'forgot_password_validation_email_invalid':
              'Enter a valid email address',
          'forgot_password_validation_password_mismatch':
              'Passwords do not match',
          'forgot_password_request_card_title':
              'Recover access without guesswork',
          'forgot_password_request_card_body':
              'Enter your account email and we will send a reset link if the account is eligible. The screen only shows accepted feedback when the real backend contract returns it.',
          'forgot_password_email_hint': 'example@example.com',
          'forgot_password_email_semantic': 'Email address',
          'forgot_password_request_caption':
              'The confirmation stays generic so this surface does not disclose whether the email exists.',
          'forgot_password_request_submit': 'Send reset link',
          'forgot_password_back_to_sign_in': 'Back to sign in',
          'forgot_password_request_accepted_title': 'The request was accepted',
          'forgot_password_request_accepted_body':
              'If this email is tied to an eligible account, you will receive a short-lived reset email. Open that message and continue from the link itself.',
          'forgot_password_edit_email': 'Edit email and try again',
          'forgot_password_reset_card_title': 'Create a new password',
          'forgot_password_reset_card_body':
              'Choose a strong password, then return to sign in. If the link is expired or already used, the flow will take you back to requesting a fresh one.',
          'forgot_password_new_password_hint': 'New password',
          'forgot_password_confirm_password_hint': 'Confirm new password',
          'forgot_password_password_rules':
              'At least 8 characters with uppercase, lowercase, a number, and a symbol.',
          'forgot_password_reset_submit': 'Update password',
          'forgot_password_reset_success_title':
              'Password updated successfully',
          'forgot_password_reset_success_body':
              'You can now return to sign in with the new password. Older refresh sessions were invalidated by the backend.',
          'forgot_password_reset_expired_title':
              'This reset link is no longer valid',
          'forgot_password_reset_expired_body':
              'The link may be expired or already used. Request a new one instead of retrying a form that cannot succeed anymore.',
          'forgot_password_request_new_link': 'Request a new link',
          'forgot_password_stage_title_request':
              'Recover access to your account',
          'forgot_password_stage_title_reset': 'Reset your password',
          'forgot_password_stage_title_link': 'Password reset link',
          'forgot_password_stage_subtitle_request':
              'A clear part of the sign-in journey: request the link, open the email, and come back without misleading success states.',
          'forgot_password_stage_subtitle_request_accepted':
              'The next step is now in the email. When the link opens, this flow will take you straight into the new-password step.',
          'forgot_password_stage_subtitle_reset':
              'You are at the decisive step now: set the new password, then return to sign in with it.',
          'forgot_password_stage_subtitle_reset_success':
              'The recovery journey is complete. The only next step is signing in with the updated password.',
          'forgot_password_stage_subtitle_reset_expired':
              'This flow does not hide the problem: the link is no longer valid and must be replaced with a fresh request.',
        },
      };
}

Future<void> _pumpForgotPasswordScreen(
  WidgetTester tester, {
  String? resetToken,
  String? previewState,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UsersProvider>.value(value: UsersProvider()),
      ],
      child: GetMaterialApp(
        translations: _ForgotPasswordTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        home: ForgotPasswordScreen(
          resetToken: resetToken,
          previewState: previewState,
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

  testWidgets('forgot password request form shows localized copy and local validation', (
    tester,
  ) async {
    await _pumpForgotPasswordScreen(tester);

    expect(find.text('Recover access to your account'), findsOneWidget);
    expect(find.text('Recover access without guesswork'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);

    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the email linked to your account'), findsOneWidget);
  });

  testWidgets('forgot password reset form shows localized password validation', (
    tester,
  ) async {
    await _pumpForgotPasswordScreen(
      tester,
      resetToken: 'valid-token',
    );

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Create a new password'), findsOneWidget);
    expect(find.text('Update password'), findsOneWidget);

    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a new password'), findsOneWidget);
  });

  testWidgets('forgot password expired state stays explicit', (tester) async {
    await _pumpForgotPasswordScreen(
      tester,
      previewState: 'expired',
    );

    expect(find.text('Password reset link'), findsOneWidget);
    expect(find.text('This reset link is no longer valid'), findsOneWidget);
    expect(find.text('Request a new link'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });
}