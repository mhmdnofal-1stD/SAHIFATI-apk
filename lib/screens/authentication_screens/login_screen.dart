import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import '../../controllers/users_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../core/utils/size_config.dart';
import '../../models/auth_data.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text.dart';
import '../widgets/no_pop_scope.dart';
import 'forget_password_screen.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_social_section.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';
import 'widgets/custom_auth_textfield_header.dart';
import 'widgets/google_web_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.firstScreen});

  final bool firstScreen;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late UsersController _userController;
  String? _socialStatusMessage;
  bool _socialStatusIsError = true;

  @override
  void initState() {
    super.initState();
    _userController = UsersController();
    _userController.getLoginInfo();
  }

  @override
  void dispose() {
    super.dispose();
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

  Future<void> _completeSocialLogin(
    Future<dynamic> Function() action,
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) async {
    FocusScope.of(context).unfocus();
    setState(() {
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
    SizeConfig().init(context);
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context);
    return NoPopScope(
        child: Scaffold(
            backgroundColor: Colors.white,
            body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(builder: (context, constraints) {
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                  return Stack(
                    children: [
                      SafeArea(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            24,
                            32,
                            24,
                            bottomInset > 24 ? bottomInset + 24 : 32,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Image.asset(
                                    Assets.logo,
                                    width: 100,
                                    height: 100,
                                  ),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 13,
                                    ),
                                    child: CustomText(
                                      text: "welcome_back".tr,
                                      textAlign: TextAlign.center,
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                      color: AppColors.blackFontColor,
                                      withBackground: false,
                                    ),
                                  ),
                                  CustomAuthTextFieldHeader(
                                    text: 'email_label'.tr,
                                  ),
                                  CustomAuthenticationTextField(
                                    hintText: 'email_hint'.tr,
                                    obscureText: false,
                                    semanticLabel: 'email_label'.tr,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                    textEditingController:
                                        _userController.loginEmailController,
                                    borderColor: _userController
                                        .loginPasswordTextFieldBorderColor,
                                  ),
                                  CustomAuthTextFieldHeader(
                                    text: 'password_label'.tr,
                                  ),
                                  CustomAuthenticationTextField(
                                    hintText: 'password_hint'.tr,
                                    obscureText: true,
                                    semanticLabel: 'password_label'.tr,
                                    keyboardType: TextInputType.visiblePassword,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    textEditingController:
                                        _userController.loginPasswordController,
                                    borderColor: _userController
                                        .loginPasswordTextFieldBorderColor,
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    runSpacing: 8,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(
                                                color: AppColors
                                                    .textFieldBorderColor,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            width: 20,
                                            height: 20,
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                checkboxTheme:
                                                    const CheckboxThemeData(),
                                              ),
                                              child: Checkbox(
                                                value: _userController.rememberMe,
                                                activeColor: Colors.grey,
                                                checkColor: AppColors
                                                    .backgroundColor,
                                                onChanged: (v) => setState(
                                                  () => _userController
                                                      .toggleRememberMe(),
                                                ),
                                                side: const BorderSide(
                                                  color: AppColors
                                                      .textFieldBorderColor,
                                                  width: 2,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            "remember_me".tr,
                                            style: TextStyle(
                                              fontFamily: AppFonts.primaryFont,
                                              fontSize: 15,
                                              color: AppColors.blackFontColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () => {
                                          Get.to(() =>
                                              const ForgotPasswordScreen())
                                        },
                                        child: Text(
                                          "forgot_password".tr,
                                          style: TextStyle(
                                            fontFamily: AppFonts.primaryFont,
                                            fontSize: 16,
                                            color: AppColors.errorColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  CustomButton(
                                    text: 'login'.tr,
                                    width: 150,
                                    height: 50,
                                    onPressed: () async {
                                      try {
                                        // ✅ Check empty fields
                                        _userController.checkEmptyFields(true);
                                        if (!_userController.noneIsEmpty) {
                                          setState(() {
                                            _userController
                                                .changeTextFieldsColors(true);
                                          });
                                          throw Exception(
                                              "all_fields_required".tr);
                                        }

                                        // ✅ Validate email format
                                        if (!_userController.isEmailValid(
                                          _userController
                                              .loginEmailController.text
                                              .trim(),
                                        )) {
                                          setState(() {
                                            _userController
                                                    .loginEmailTextFieldBorderColor =
                                                AppColors.errorColor;
                                          });
                                          throw Exception("invalid_email".tr);
                                        }

                                        // ✅ Indicate loading
                                        setState(() {
                                          _userController
                                              .changeTextFieldsColors(true);
                                          usersProvider.setLoading();
                                        });

                                        // ✅ Try to log in
                                        AuthData authData =
                                            await usersProvider.login(
                                          _userController
                                              .loginEmailController.text
                                              .trim(),
                                          _userController
                                              .loginPasswordController.text,
                                        );

                                        User user = User(
                                            id: authData.user!.id,
                                            fullName: authData.user!.fullName,
                                            email: authData.user!.email);

                                        usersProvider.setSelectedUser(user);
                                        await usersProvider.checkFirstLogin();

                                        // Always save session on successful login, or based on "Remember Me" if that's the requirement
                                        // The user request "keep the user logged in after killing the app" implies we should probably auto-save it.
                                        // However, the original code had "Remember Me".
                                        // If I follow "keep logged in", it usually means persistent session.
                                        // I will save it if rememberMe is true, or maybe always if that's modern standard.
                                        // But let's stick to the existing "Remember Me" checkbox logic if we want to respect that UI choice,
                                        // OR enforce it. The user said "keep the user logged in", so usually that implies default behavior or checking "Remember Me".
                                        // I'll put it inside the existing rememberMe block but also make sure it saves the FULL session not just email/pass for autofill.

                                        if (_userController.rememberMe) {
                                          _userController.saveLoginInfo(
                                            _userController
                                                .loginEmailController.text
                                                .trim(),
                                          );
                                          await usersProvider.saveUserSession(
                                            user,
                                            authData.accessToken!,
                                            refreshToken:
                                                authData.refreshToken,
                                          );
                                        }

                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        _userController
                                            .loginPasswordController.clear();

                                        await navigateAfterSuccessfulLogin(
                                          userId:
                                              usersProvider.selectedUser!.id,
                                          isFirstLogin:
                                              usersProvider.isFirstLogin,
                                          loadChartData: (userId) =>
                                              evaluationsProvider
                                                  .getQuranChartData(userId),
                                        );
                                      } catch (e) {
                                        final messageText =
                                            usersProvider.extractErrorMessage(e);
                                        final errorCode = e is Map
                                          ? (e['errorCode'] ??
                                            (e['message'] is Map
                                              ? e['message']['errorCode']
                                              : null))
                                          : null;

                                        if (errorCode ==
                                          'ACCOUNT_NOT_VERIFIED') {
                                          await usersProvider
                                              .setPendingVerificationState(
                                            _userController
                                                .loginEmailController.text
                                                .trim(),
                                            sentAt: usersProvider
                                                .pendingVerificationSentAt,
                                          );
                                          if (!context.mounted) return;
                                          Get.offAllNamed(
                                            '/verification-pending',
                                            parameters: {
                                              'email': _userController
                                                  .loginEmailController.text
                                                  .trim(),
                                            },
                                          );
                                          return;
                                        }

                                        String message;
                                        if (messageText
                                            .contains("invalid credentials")) {
                                          message = "invalid_credentials".tr;
                                        } else {
                                          message = messageText;
                                        }

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              message,
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ),
                                        );
                                      } finally {
                                        setState(() {
                                          usersProvider.resetLoading();
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 30),
                                  AuthSocialSection(
                                    googleControl:
                                        kIsWeb &&
                                                SocialAuthConfig
                                                    .isGoogleConfiguredForCurrentPlatform
                                            ? GoogleWebAuthButton(
                                                initialize: usersProvider
                                                    .ensureGoogleInitialized,
                                                isBusy: usersProvider.isLoading,
                                                isSignupContext: false,
                                                onIdToken: (idToken) async {
                                                  await _completeSocialLogin(
                                                    () => usersProvider
                                                        .signInWithGoogleIdToken(
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
                                            : _GoogleNativeIconButton(
                                                isBusy: usersProvider.isLoading,
                                                onPressed: () =>
                                                    _completeSocialLogin(
                                                      usersProvider
                                                          .signInWithGoogle,
                                                      usersProvider,
                                                      evaluationsProvider,
                                                    ),
                                              ),

                                          showFacebook:
                                            SocialAuthConfig.facebookAuthEnabled,
                                    onFacebookPressed:
                                        usersProvider.isLoading
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
                                  const SizedBox(height: 30),
                                  CustomAuthFooter(
                                    headingText: "dont_have_account".tr,
                                    tailText: "create_account_action".tr,
                                    onTap: () => {
                                      UsersProvider().resetSignUpErrorText(),
                                      Get.to(() => const SignUpScreen())
                                    },
                                  ),
                                  const SizedBox(height: 50),
                                  SizedBox(
                                    height: 40,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Left logo
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Image.asset(
                                            Assets.organization1STDLogo,
                                            height: 50,
                                          ),
                                        ),

                                        // Center text (true center of screen)
                                        const CustomText(
                                          text: 'Beta 0.0.3',
                                          withBackground: false,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (usersProvider.isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  );
                }))));
  }
}

/// Compact Google icon button for non-web platforms.
class _GoogleNativeIconButton extends StatelessWidget {
  const _GoogleNativeIconButton({
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onPressed,
        customBorder: const CircleBorder(),
        child: Center(
          child: Image.asset(Assets.googleIcon, width: 22, height: 22),
        ),
      ),
    );
  }
}
