import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';
import '../../controllers/users_controller.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/no_pop_scope.dart';
import 'login_screen.dart';
import 'widgets/auth_social_section.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';
import 'widgets/custom_auth_textfield_header.dart';
import 'widgets/google_web_auth_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late UsersController _userController;

  /// Local flag to block double-submit during validation (before the
  /// provider's isLoading kicks in from the async call).
  bool _isProcessing = false;

  /// Inline error shown below the form — replaces full-screen snackbars.
  String? _inlineError;
  String? _socialStatusMessage;
  bool _socialStatusIsError = true;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _userController = UsersController();
    _userController.resetSignUpState();
  }

  @override
  void dispose() {
    // The singleton's controllers must NOT be disposed from the screen.
    // Reset signup-only state so revisiting the screen starts clean.
    _userController.resetSignUpState();
    _emailFocus.dispose();
    _usernameFocus.dispose();
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
      // ── Empty-fields check ────────────────────────────────────────────
      _userController.checkEmptyFields(false);
      if (!_userController.noneIsEmpty) {
        setState(() => _userController.changeTextFieldsColors(false));
        throw Exception('all_fields_required'.tr);
      }

      // ── Email format ──────────────────────────────────────────────────
      if (!_userController.isEmailValid(
        _userController.signUpEmailController.text.trim(),
      )) {
        setState(
          () => _userController.signUpEmailTextFieldBorderColor =
              AppColors.errorColor,
        );
        throw Exception('invalid_email'.tr);
      }

      // ── Password strength ─────────────────────────────────────────────
      _userController.checkValidPassword();

      // ── Password match ────────────────────────────────────────────────
      _userController.checkMatchedPassword();
      if (!_userController.isMatched) {
        setState(() => _userController.changeTextFieldsColors(false));
        throw Exception('passwords_no_match'.tr);
      }

      // ── Register ──────────────────────────────────────────────────────
      final submittedEmail =
          _userController.signUpEmailController.text.trim();
      await usersProvider.register(
        _userController.signUpUsernameController.text.trim(),
        submittedEmail,
        _userController.signUpPasswordController.text,
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
      }
      if (code == 'SOCIAL_PROVIDER_UNSUPPORTED') {
        return 'social_provider_temporarily_unavailable'.trParams({
          'provider': _providerLabel((error['provider'] ?? 'provider').toString()),
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
        loadChartData: (userId) => evaluationsProvider.getQuranChartData(userId),
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

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final bool isBusy = _isProcessing || usersProvider.isLoading;

    return NoPopScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  // Keeps the form compact and centred on wide web screens
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Hero ────────────────────────────────────────
                      Center(
                        child: Image.asset(
                          Assets.logo,
                          width: 80,
                          height: 80,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'create_account'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blackFontColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'signup_subtitle'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 14,
                          color: AppColors.hintTextColor,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Email ────────────────────────────────────────
                      CustomAuthTextFieldHeader(text: 'email_label'.tr),
                      const SizedBox(height: 6),
                      CustomAuthenticationTextField(
                        hintText: 'enter_email_hint'.tr,
                        semanticLabel: 'email_label'.tr,
                        obscureText: false,
                        focusNode: _emailFocus,
                        textEditingController:
                            _userController.signUpEmailController,
                        borderColor:
                            _userController.signUpEmailTextFieldBorderColor,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _usernameFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),

                      // ── Username ─────────────────────────────────────
                      CustomAuthTextFieldHeader(text: 'username_label'.tr),
                      const SizedBox(height: 6),
                      CustomAuthenticationTextField(
                        hintText: 'username_hint'.tr,
                        semanticLabel: 'username_label'.tr,
                        obscureText: false,
                        focusNode: _usernameFocus,
                        textEditingController:
                            _userController.signUpUsernameController,
                        borderColor:
                            _userController.signUpUsernameTextFieldBorderColor,
                        keyboardType: TextInputType.text,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),

                      // ── Password ─────────────────────────────────────
                      CustomAuthTextFieldHeader(text: 'password_label'.tr),
                      const SizedBox(height: 6),
                      CustomAuthenticationTextField(
                        hintText: 'password_hint'.tr,
                        semanticLabel: 'password_label'.tr,
                        obscureText: true,
                        focusNode: _passwordFocus,
                        textEditingController:
                            _userController.signUpPasswordController,
                        borderColor:
                            _userController.signUpPasswordTextFieldBorderColor,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _confirmFocus.requestFocus(),
                      ),
                      const SizedBox(height: 5),
                      // Password helper copy (requirements guide)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          'password_helper'.tr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppFonts.primaryFont,
                            fontSize: 12,
                            color: AppColors.hintTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Confirm Password ─────────────────────────────
                      CustomAuthTextFieldHeader(
                          text: 'confirm_password_label'.tr),
                      const SizedBox(height: 6),
                      CustomAuthenticationTextField(
                        hintText: 'confirm_password_hint'.tr,
                        semanticLabel: 'confirm_password_label'.tr,
                        obscureText: true,
                        focusNode: _confirmFocus,
                        textEditingController: _userController
                            .signUpConfirmedPasswordController,
                        borderColor:
                            _userController.confirmPasswordTextFieldBorderColor,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleSubmit(usersProvider),
                      ),

                      // ── Inline error banner ──────────────────────────
                      if (_inlineError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.errorColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.errorColor,
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _inlineError!,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontFamily: AppFonts.primaryFont,
                                    fontSize: 13,
                                    color: AppColors.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Submit CTA ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              isBusy ? null : () => _handleSubmit(usersProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            disabledBackgroundColor:
                                AppColors.primaryPurple.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'create_account'.tr,
                                  style: TextStyle(
                                    fontFamily: AppFonts.primaryFont,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      AuthSocialSection(
                        googleControl: kIsWeb &&
                                SocialAuthConfig
                                    .isGoogleConfiguredForCurrentPlatform
                            ? GoogleWebAuthButton(
                                initialize: usersProvider.ensureGoogleInitialized,
                                isBusy: usersProvider.isLoading,
                                isSignupContext: true,
                                onIdToken: (idToken) async {
                                  await _completeSocialSignup(
                                    () => usersProvider.signInWithGoogleIdToken(
                                      idToken,
                                    ),
                                    usersProvider,
                                    evaluationsProvider,
                                  );
                                },
                                onError: (error) {
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {
                                    _socialStatusMessage =
                                        _resolveSocialErrorMessage(
                                      error,
                                      usersProvider,
                                    );
                                    _socialStatusIsError = true;
                                  });
                                },
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: (!kIsWeb && !usersProvider.isLoading)
                                      ? () => _completeSocialSignup(
                                            usersProvider.signInWithGoogle,
                                            usersProvider,
                                            evaluationsProvider,
                                          )
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    'google_continue'.tr,
                                    style: TextStyle(
                                      fontFamily: AppFonts.primaryFont,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              showFacebook: SocialAuthConfig.facebookAuthEnabled,
                        onFacebookPressed: usersProvider.isLoading
                            ? null
                            : () => _completeSocialSignup(
                                  usersProvider.signInWithFacebook,
                                  usersProvider,
                                  evaluationsProvider,
                                ),
                        isBusy: usersProvider.isLoading,
                        googleHint: kIsWeb &&
                                !SocialAuthConfig
                                    .isGoogleConfiguredForCurrentPlatform
                            ? 'social_google_requires_client_id'.tr
                            : (!kIsWeb &&
                                    !SocialAuthConfig
                                        .isGoogleConfiguredForCurrentPlatform)
                                ? 'social_google_requires_mobile_config'.tr
                                : null,
                        facebookHint: kIsWeb &&
                                !SocialAuthConfig
                                    .isFacebookConfiguredForCurrentPlatform
                            ? 'social_facebook_requires_app_id'.tr
                            : null,
                        statusMessage: _socialStatusMessage,
                        statusTone: _socialStatusIsError
                            ? AuthSocialStatusTone.error
                            : AuthSocialStatusTone.info,
                      ),

                      const SizedBox(height: 24),

                      // ── Footer ───────────────────────────────────────
                      Center(
                        child: CustomAuthFooter(
                          headingText: 'already_have_account'.tr,
                          tailText: 'login_action'.tr,
                          onTap: isBusy
                              ? null
                              : () {
                                  usersProvider.resetSignUpErrorText();
                                  Get.to(() => const LoginScreen(
                                        firstScreen: false,
                                      ));
                                },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
