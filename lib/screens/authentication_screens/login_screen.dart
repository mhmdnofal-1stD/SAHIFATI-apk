import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import '../../controllers/users_controller.dart';
import '../../providers/users_provider.dart';
import '../widgets/no_pop_scope.dart';
import 'forget_password_screen.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/auth_social_section.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';
import 'widgets/google_web_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.firstScreen,
    this.initialEmail,
  });

  final bool firstScreen;
  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late UsersController _userController;
  String? _inlineError;
  String? _socialStatusMessage;
  bool _socialStatusIsError = true;

  Widget _buildUtilityIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Color foreground = const Color(0xFF132A4A),
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? const Color(0xFFF1ECE3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD9DEE5)),
            ),
            child: Icon(icon, color: foreground, size: 20),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _userController = UsersController();
    _hydrateLoginInfo();
  }

  Future<void> _hydrateLoginInfo() async {
    await _userController.getLoginInfo(preferredEmail: widget.initialEmail);
    if (!mounted) {
      return;
    }

    setState(() {});
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

  Future<void> _completeSocialLogin(
    Future<dynamic> Function() action,
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) async {
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
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
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
        isSignupContext: false,
        onIdToken: (idToken) async {
          await _completeSocialLogin(
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
          ? () => _completeSocialLogin(
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

  Future<void> _handleLogin(
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) async {
    try {
      setState(() {
        _inlineError = null;
        _socialStatusMessage = null;
      });

      _userController.checkEmptyFields(true);
      if (!_userController.noneIsEmpty) {
        setState(() {
          _userController.changeTextFieldsColors(true);
        });
        throw Exception('all_fields_required'.tr);
      }

      if (!_userController.isEmailValid(
        _userController.loginEmailController.text.trim(),
      )) {
        setState(() {
          _userController.loginEmailTextFieldBorderColor = AppColors.errorColor;
        });
        throw Exception('invalid_email'.tr);
      }

      setState(() {
        _userController.changeTextFieldsColors(true);
        usersProvider.setLoading();
      });

      final AuthData authData = await usersProvider.login(
        _userController.loginEmailController.text.trim(),
        _userController.loginPasswordController.text,
      );

      await usersProvider.finalizeAuthenticatedUser(authData);

      if (_userController.rememberMe) {
        _userController.saveLoginInfo(
          _userController.loginEmailController.text.trim(),
        );
      } else {
        await _userController.clearLoginInfo();
      }

      FocusManager.instance.primaryFocus?.unfocus();
      _userController.loginPasswordController.clear();

      await navigateAfterSuccessfulLogin(
        userId: usersProvider.selectedUser!.id,
        isFirstLogin: usersProvider.isFirstLogin,
        hasActiveLicense: usersProvider.hasActiveLicense,
        loadChartData: (userId) =>
            evaluationsProvider.getQuranChartData(userId),
      );
    } catch (e) {
      final messageText = usersProvider.extractErrorMessage(e);
      final errorCode = e is Map
          ? (e['errorCode'] ??
              (e['message'] is Map ? e['message']['errorCode'] : null))
          : null;

      if (errorCode == 'ACCOUNT_NOT_VERIFIED') {
        await usersProvider.setPendingVerificationState(
          _userController.loginEmailController.text.trim(),
          sentAt: usersProvider.pendingVerificationSentAt,
        );
        if (!context.mounted) return;
        Get.offAllNamed(
          '/verification-pending',
          parameters: {
            'email': _userController.loginEmailController.text.trim(),
          },
        );
        return;
      }

      String message;
      if (messageText.contains('invalid credentials')) {
        message = 'invalid_credentials'.tr;
      } else {
        message = messageText;
      }

      if (!context.mounted) return;
      setState(() {
        _inlineError = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          usersProvider.resetLoading();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final mediaSize = MediaQuery.of(context).size;
    final isCompactPhone = mediaSize.shortestSide < 600;
    final fieldGap = isCompactPhone ? 8.0 : 14.0;
    final utilitiesGap = isCompactPhone ? 8.0 : 10.0;
    final errorGap = isCompactPhone ? 10.0 : 12.0;
    final primaryActionGap = isCompactPhone ? 14.0 : 18.0;
    final sectionGap = isCompactPhone ? 16.0 : 22.0;

    return NoPopScope(
      child: AuthScreenShell(
        title: 'auth_login_title'.tr,
        subtitle: '',
        isSignup: false,
        fillViewport: true,
        preferCompactMobileLayout: true,
        onSelectSignup: usersProvider.isLoading
            ? null
            : () {
                Get.to(() => const SignUpScreen());
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomAuthenticationTextField(
              hintText: 'email_hint'.tr,
              obscureText: false,
              semanticLabel: 'email_label'.tr,
              leadingIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              textEditingController: _userController.loginEmailController,
              borderColor: _userController.loginEmailTextFieldBorderColor,
            ),
            SizedBox(height: fieldGap),
            CustomAuthenticationTextField(
              hintText: 'password_hint'.tr,
              obscureText: true,
              semanticLabel: 'password_label'.tr,
              leadingIcon: Icons.lock_outline_rounded,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              textEditingController: _userController.loginPasswordController,
              borderColor: _userController.loginPasswordTextFieldBorderColor,
              onSubmitted: (_) =>
                  _handleLogin(usersProvider, evaluationsProvider),
            ),
            SizedBox(height: utilitiesGap),
            Row(
              children: [
                _buildUtilityIconButton(
                  icon: _userController.rememberMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: 'remember_me'.tr,
                  onTap: () =>
                      setState(() => _userController.toggleRememberMe()),
                ),
                const Spacer(),
                _buildUtilityIconButton(
                  icon: Icons.lock_reset_rounded,
                  tooltip: 'forgot_password'.tr,
                  onTap: () => Get.to(
                    () => ForgotPasswordScreen(
                      initialEmail: _userController.loginEmailController.text
                              .trim()
                              .isEmpty
                          ? null
                          : _userController.loginEmailController.text.trim(),
                    ),
                  ),
                  foreground: const Color(0xFFB13030),
                ),
              ],
            ),
            if (_inlineError != null) ...[
              SizedBox(height: errorGap),
              _buildInlineErrorBanner(_inlineError!),
            ],
            SizedBox(height: primaryActionGap),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: usersProvider.isLoading
                    ? null
                    : () => _handleLogin(usersProvider, evaluationsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF132A4A),
                  disabledBackgroundColor:
                      const Color(0xFF132A4A).withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                icon: usersProvider.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(Icons.login_rounded, color: Colors.white),
                label: Text(
                  'login'.tr,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: sectionGap),
            AuthSocialSection(
              googleControl: _buildGoogleControl(
                usersProvider,
                evaluationsProvider,
              ),
              showFacebook: SocialAuthConfig.facebookAuthEnabled,
              onFacebookPressed: usersProvider.isLoading
                  ? null
                  : () => _completeSocialLogin(
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
            SizedBox(height: sectionGap),
            Center(
              child: CustomAuthFooter(
                actionText: 'create_account_action'.tr,
                icon: Icons.arrow_forward_rounded,
                onTap: usersProvider.isLoading
                    ? null
                    : () {
                        UsersProvider().resetSignUpErrorText();
                        Get.to(() => const SignUpScreen());
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
