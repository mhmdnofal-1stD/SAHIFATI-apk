import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import '../../controllers/users_controller.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/no_pop_scope.dart';
import 'login_screen.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/auth_social_section.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';
import 'widgets/google_web_auth_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late UsersController _userController;
  bool _isProcessing = false;
  String? _inlineError;
  String? _socialStatusMessage;
  bool _socialStatusIsError = true;

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

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'social_provider_google'.tr;
      case 'facebook':
        return 'social_provider_facebook'.tr;
      case 'apple':
        return 'Apple';
      default:
        return provider;
    }
  }

  String _resolveSocialErrorMessage(
    Object error,
    UsersProvider usersProvider,
  ) {
    if (error is Map) {
      final code = error['errorCode'];
      final provider = error['existingProvider'];
      if (code == 'SOCIAL_LOGIN_CANCELLED') {
        final socialProvider = (error['provider'] ?? '').toString();
        if (!kIsWeb && socialProvider == 'google') {
          return 'social_google_mobile_interrupted'.tr;
        }
        return 'social_cancelled'.tr;
      }
      if (code == 'SOCIAL_CONFIG_MISSING') {
        final socialProvider = error['provider'];
        if (socialProvider == 'google') {
          return kIsWeb
              ? 'social_google_requires_client_id'.tr
              : 'social_google_requires_mobile_config'.tr;
        }
        if (socialProvider == 'facebook') {
          return 'social_facebook_requires_app_id'.tr;
        }
        if (socialProvider == 'apple') {
          return 'social_apple_requires_web_config'.tr;
        }
      }
      if (code == 'SOCIAL_PROVIDER_UNSUPPORTED') {
        return 'social_provider_temporarily_unavailable'.trParams({
          'provider':
              _providerLabel((error['provider'] ?? 'provider').toString()),
        });
      }
      if (code == 'SOCIAL_ID_TOKEN_MISSING' ||
          code == 'SOCIAL_ACCESS_TOKEN_MISSING') {
        return 'social_missing_id_token'.tr;
      }
      if (code == 'ACCOUNT_EXISTS_WITH_PASSWORD') {
        return 'social_account_exists_with_password'.tr;
      }
      if (code == 'ACCOUNT_EXISTS_WITH_DIFFERENT_PROVIDER') {
        return 'social_account_exists_with_different_provider'.trParams({
          'provider': _providerLabel((provider ?? 'provider').toString()),
        });
      }
    }

    final message = usersProvider.extractErrorMessage(error);
    if (message.toLowerCase().contains('cancel')) {
      return 'social_cancelled'.tr;
    }
    return message;
  }

  Future<void> _completeSocialSignup(
    Future<dynamic> Function() action,
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) async {
    if (_isProcessing || usersProvider.isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _inlineError = null;
      _socialStatusMessage = null;
      _socialStatusIsError = true;
    });

    try {
      await action();
      if (!mounted || usersProvider.selectedUser == null) {
        return;
      }

      await navigateAfterSuccessfulLogin(
        userId: usersProvider.selectedUser!.id,
        isFirstLogin: usersProvider.isFirstLogin,
        hasActiveLicense: usersProvider.hasActiveLicense,
        loadChartData: (userId) =>
            evaluationsProvider.getQuranChartData(userId),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _socialStatusMessage = _resolveSocialErrorMessage(error, usersProvider);
        _socialStatusIsError = true;
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

  Widget _buildGoogleControl(
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) {
    if (kIsWeb && SocialAuthConfig.isGoogleConfiguredForCurrentPlatform) {
      return GoogleWebAuthButton(
        initialize: usersProvider.ensureGoogleInitialized,
        isBusy: usersProvider.isLoading,
        isSignupContext: true,
        onIdToken: (idToken) async {
          await _completeSocialSignup(
            () => usersProvider.signInWithGoogleIdToken(idToken),
            usersProvider,
            evaluationsProvider,
          );
        },
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _socialStatusMessage = _resolveSocialErrorMessage(
              error,
              usersProvider,
            );
            _socialStatusIsError = true;
          });
        },
      );
    }

    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_google'.tr,
      onPressed: (!kIsWeb && !usersProvider.isLoading)
          ? () => _completeSocialSignup(
                usersProvider.signInWithGoogle,
                usersProvider,
                evaluationsProvider,
              )
          : null,
      isBusy: usersProvider.isLoading,
      icon: Image.asset(
        Assets.googleIcon,
        width: 24,
        height: 24,
      ),
    );
  }

  Widget? _buildAppleControl(
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) {
    if (!SocialAuthConfig.isAppleConfiguredForCurrentPlatform) {
      return null;
    }

    return AuthCompactSocialButton(
      semanticLabel: 'Apple',
      onPressed: usersProvider.isLoading
          ? null
          : () => _completeSocialSignup(
                usersProvider.signInWithApple,
                usersProvider,
                evaluationsProvider,
              ),
      isBusy: usersProvider.isLoading,
      icon: const Icon(
        Icons.apple_rounded,
        size: 26,
        color: Color(0xFF111111),
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
            AuthSocialSection(
              googleControl: _buildGoogleControl(
                usersProvider,
                evaluationsProvider,
              ),
              appleControl: _buildAppleControl(
                usersProvider,
                evaluationsProvider,
              ),
              showEmailMethod: false,
              showFacebook: SocialAuthConfig.facebookAuthEnabled,
              onFacebookPressed: usersProvider.isLoading
                  ? null
                  : () => _completeSocialSignup(
                        usersProvider.signInWithFacebook,
                        usersProvider,
                        evaluationsProvider,
                      ),
              isBusy: usersProvider.isLoading,
              statusMessage: _socialStatusMessage,
              statusTone: _socialStatusIsError
                  ? AuthSocialStatusTone.error
                  : AuthSocialStatusTone.info,
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
