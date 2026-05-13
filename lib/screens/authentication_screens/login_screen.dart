import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import '../../controllers/users_controller.dart';
import '../../providers/users_provider.dart';
import '../widgets/info_icon_button.dart';
import '../widgets/no_pop_scope.dart';
import 'forget_password_screen.dart';
import 'sign_up_screen.dart';
import 'social_auth_action.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';

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

class _LoginScreenState extends State<LoginScreen> with SocialAuthAction {
  late UsersController _userController;
  String? _inlineError;

  @override
  void beforeSocialAction() {
    _inlineError = null;
  }

  Widget _buildUtilityIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    String? label,
    Color foreground = AppColors.blackFontColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? AppColors.dropDownButtonColor : AppColors.panelColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lineColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x141D6652),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 18),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.of(context)
                        .buttonSecondary
                        .copyWith(color: AppColors.mutedText),
                  ),
                ],
              ],
            ),
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
              style: AppTypography.of(context).inputError,
            ),
          ),
        ],
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
        socialStatusMessage = null;
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
      TextInput.finishAutofillContext(shouldSave: true);

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
        brandSubtitle: '',
        isSignup: false,
        fillViewport: true,
        preferCompactMobileLayout: true,
        showHeading: false,
        onSelectSignup: usersProvider.isLoading
            ? null
            : () {
                Get.to(() => const SignUpScreen());
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AutofillGroup(
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
                    textEditingController:
                        _userController.loginPasswordController,
                    borderColor:
                        _userController.loginPasswordTextFieldBorderColor,
                    onSubmitted: (_) =>
                        _handleLogin(usersProvider, evaluationsProvider),
                  ),
                ],
              ),
            ),
            SizedBox(height: utilitiesGap),
            Row(
              children: [
                _buildUtilityIconButton(
                  icon: _userController.rememberMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: 'remember_me'.tr,
                  label: 'remember_me'.tr,
                  onTap: () =>
                      setState(() => _userController.toggleRememberMe()),
                ),
                const Spacer(),
                _buildUtilityIconButton(
                  icon: Icons.lock_reset_rounded,
                  tooltip: 'forgot_password'.tr,
                  label: 'forgot_password'.tr,
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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: usersProvider.isLoading
                          ? null
                          : () => _handleLogin(usersProvider, evaluationsProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        disabledBackgroundColor:
                            AppColors.primaryPurple.withValues(alpha: 0.45),
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
                        style: AppTypography.of(context)
                            .buttonPrimary
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                InfoIconButton(
                  message: 'surface_quick_login_hint'.tr,
                  color: AppColors.mutedText,
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            buildSocialSection(
              usersProvider,
              evaluationsProvider,
              isSignupContext: false,
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
            const SizedBox(height: 8),
            const _OwnerBrandingCard(),
          ],
        ),
      ),
    );
  }
}

class _OwnerBrandingCard extends StatelessWidget {
  const _OwnerBrandingCard();

  static const String _flutterBetaVersionLabel = 'Beta 00.00.07';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Text(
              _flutterBetaVersionLabel,
              textDirection: TextDirection.ltr,
              style: AppTypography.of(context).bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: 176,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: SvgPicture.asset(
                      Assets.organization1STDLogo,
                      height: 34,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 42,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'auth_owner_brand_caption'.tr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTypography.of(context).bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedText,
                              fontSize: 10,
                              height: 1.15,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
