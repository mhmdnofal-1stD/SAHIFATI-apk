import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import '../../controllers/users_controller.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/no_pop_scope.dart';
import 'login_screen.dart';
import 'social_auth_action.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/auth_privacy_notice.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SocialAuthAction {
  late UsersController _userController;
  bool _isProcessing = false;
  String? _inlineError;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  String _deriveUsernameFromEmail(String email) {
    final localPart = email.split('@').first.trim().toLowerCase();
    final normalized = localPart
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^[_\-.]+|[_\-.]+$'), '')
        .replaceAll(RegExp(r'_{2,}'), '_');

    return normalized.isEmpty ? 'user' : normalized;
  }

  @override
  void initState() {
    super.initState();
    _userController = UsersController();
    _userController.resetSignUpState();
  }

  @override
  void dispose() {
    _userController.resetSignUpState();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(UsersProvider usersProvider) async {
    if (_isProcessing || usersProvider.isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _inlineError = null;
      _isProcessing = true;
    });

    try {
      final submittedEmail = _userController.signUpEmailController.text.trim();
      _userController.signUpUsernameController.text =
          _deriveUsernameFromEmail(submittedEmail);

      _userController.checkEmptyFields(false);
      if (!_userController.noneIsEmpty) {
        setState(() => _userController.changeTextFieldsColors(false));
        throw Exception('all_fields_required'.tr);
      }

      if (!_userController.isEmailValid(
        submittedEmail,
      )) {
        setState(
          () => _userController.signUpEmailTextFieldBorderColor =
              AppColors.errorColor,
        );
        throw Exception('invalid_email'.tr);
      }

      _userController.checkValidPassword();
      _userController.checkMatchedPassword();
      if (!_userController.isMatched) {
        setState(() => _userController.changeTextFieldsColors(false));
        throw Exception('passwords_no_match'.tr);
      }

      await usersProvider.register(
        submittedEmail,
        _userController.signUpPasswordController.text,
        username: _userController.signUpUsernameController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _userController.changeTextFieldsColors(false));
      UsersController().clearTextFields();

      if (!mounted) return;
      Get.offAllNamed(
        '/verification-pending',
        parameters: {
          'email': submittedEmail,
        },
      );
    } catch (e) {
      if (!mounted) return;
      String message;
      final raw = usersProvider.extractErrorMessage(e);
      if (raw.contains('email already in use')) {
        message = 'email_taken'.tr;
      } else {
        message = raw;
      }
      setState(() {
        _inlineError = message;
        _isProcessing = false;
      });
    }
  }

  Widget _buildInlineErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context).inputError.copyWith(
                    fontSize: 13,
                    color: AppColors.errorColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final bool isBusy = _isProcessing || usersProvider.isLoading;

    return NoPopScope(
      child: AuthScreenShell(
        title: 'auth_signup_title'.tr,
        subtitle: 'signup_subtitle'.tr,
        isSignup: true,
        onSelectLogin: isBusy
            ? null
            : () {
                usersProvider.resetSignUpErrorText();
                Get.to(() => const LoginScreen(firstScreen: false));
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomAuthenticationTextField(
              hintText: 'enter_email_hint'.tr,
              semanticLabel: 'email_label'.tr,
              obscureText: false,
              leadingIcon: Icons.alternate_email_rounded,
              focusNode: _emailFocus,
              textEditingController: _userController.signUpEmailController,
              borderColor: _userController.signUpEmailTextFieldBorderColor,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            CustomAuthenticationTextField(
              hintText: 'password_hint'.tr,
              semanticLabel: 'password_label'.tr,
              obscureText: true,
              leadingIcon: Icons.lock_outline_rounded,
              focusNode: _passwordFocus,
              textEditingController: _userController.signUpPasswordController,
              borderColor: _userController.signUpPasswordTextFieldBorderColor,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            CustomAuthenticationTextField(
              hintText: 'confirm_password_hint'.tr,
              semanticLabel: 'confirm_password_label'.tr,
              obscureText: true,
              leadingIcon: Icons.verified_user_outlined,
              focusNode: _confirmFocus,
              textEditingController:
                  _userController.signUpConfirmedPasswordController,
              borderColor: _userController.confirmPasswordTextFieldBorderColor,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(usersProvider),
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              _buildInlineErrorBanner(_inlineError!),
            ],
            const SizedBox(height: 12),
            const AuthPrivacyNotice(),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : () => _handleSubmit(usersProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  disabledBackgroundColor:
                      AppColors.primaryPurple.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white),
                label: Text(
                  'create_account'.tr,
                  style: AppTypography.of(context).buttonPrimary.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            buildSocialSection(
              usersProvider,
              evaluationsProvider,
              isSignupContext: true,
            ),
            const SizedBox(height: 22),
            Center(
              child: CustomAuthFooter(
                actionText: 'login_action'.tr,
                icon: Icons.login_rounded,
                onTap: isBusy
                    ? null
                    : () {
                        usersProvider.resetSignUpErrorText();
                        Get.to(() => const LoginScreen(firstScreen: false));
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
