import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../providers/users_provider.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/custom_auth_textfield.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.resetToken,
    this.previewState,
  });

  final String? initialEmail;
  final String? resetToken;
  final String? previewState;

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

enum _RecoveryStage {
  requestForm,
  requestAccepted,
  resetForm,
  resetSuccess,
  resetExpired,
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  Color _emailBorderColor = AppColors.textFieldBorderColor;
  Color _passwordBorderColor = AppColors.textFieldBorderColor;
  Color _confirmPasswordBorderColor = AppColors.textFieldBorderColor;
  String? _inlineMessage;
  bool _inlineIsError = true;
  late _RecoveryStage _stage;

  bool get _isArabic => Get.locale?.languageCode.toLowerCase() == 'ar';
  String get _resetToken => widget.resetToken?.trim() ?? '';
  String get _previewState => widget.previewState?.trim().toLowerCase() ?? '';

  _RecoveryStage _resolveInitialStage() {
    switch (_previewState) {
      case 'requestaccepted':
      case 'accepted':
        return _RecoveryStage.requestAccepted;
      case 'resetsuccess':
      case 'success':
        return _RecoveryStage.resetSuccess;
      case 'resetexpired':
      case 'expired':
        return _RecoveryStage.resetExpired;
      case 'reseterror':
      case 'reset':
        return _RecoveryStage.resetForm;
      default:
        return _resetToken.isNotEmpty
            ? _RecoveryStage.resetForm
            : _RecoveryStage.requestForm;
    }
  }

  void _applyPreviewState() {
    switch (_previewState) {
      case 'requesterror':
      case 'backenderror':
        _stage = _RecoveryStage.requestForm;
        _emailBorderColor = AppColors.errorColor;
        _inlineMessage = 'forgot_password_preview_request_error'.tr;
        _inlineIsError = true;
        return;
      case 'reseterror':
        _stage = _RecoveryStage.resetForm;
        _passwordBorderColor = AppColors.errorColor;
        _inlineMessage = 'forgot_password_preview_reset_error'.tr;
        _inlineIsError = true;
        return;
      default:
        return;
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.initialEmail?.trim() ?? '',
    );
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _stage = _resolveInitialStage();
    _applyPreviewState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _resetInlineFeedback() {
    _inlineMessage = null;
    _inlineIsError = true;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'forgot_password_validation_password_required'.tr;
    }
    if (password.length < 8) {
      return 'forgot_password_validation_password_length'.tr;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'forgot_password_validation_password_uppercase'.tr;
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'forgot_password_validation_password_lowercase'.tr;
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'forgot_password_validation_password_number'.tr;
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'forgot_password_validation_password_symbol'.tr;
    }

    return null;
  }

  void _openLogin() {
    final email = _emailController.text.trim();
    Get.offAll(
      () => LoginScreen(
        firstScreen: false,
        initialEmail: email.isEmpty ? null : email,
      ),
    );
  }

  Future<void> _handleRequest(UsersProvider usersProvider) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resetInlineFeedback();
      _emailBorderColor = AppColors.textFieldBorderColor;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailBorderColor = AppColors.errorColor;
        _inlineMessage = 'forgot_password_validation_email_required'.tr;
        _inlineIsError = true;
      });
      return;
    }

    if (!GetUtils.isEmail(email)) {
      setState(() {
        _emailBorderColor = AppColors.errorColor;
        _inlineMessage = 'forgot_password_validation_email_invalid'.tr;
        _inlineIsError = true;
      });
      return;
    }

    try {
      await usersProvider.requestPasswordReset(email);
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _RecoveryStage.requestAccepted;
        _inlineMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineMessage = usersProvider.extractErrorMessage(error);
        _inlineIsError = true;
      });
    }
  }

  Future<void> _handleReset(UsersProvider usersProvider) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resetInlineFeedback();
      _passwordBorderColor = AppColors.textFieldBorderColor;
      _confirmPasswordBorderColor = AppColors.textFieldBorderColor;
    });

    if (_resetToken.isEmpty) {
      setState(() {
        _stage = _RecoveryStage.resetExpired;
      });
      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final passwordValidation = _validatePassword(password);

    if (passwordValidation != null) {
      setState(() {
        _passwordBorderColor = AppColors.errorColor;
        _inlineMessage = passwordValidation;
        _inlineIsError = true;
      });
      return;
    }

    if (confirmPassword != password) {
      setState(() {
        _confirmPasswordBorderColor = AppColors.errorColor;
        _inlineMessage = 'forgot_password_validation_password_mismatch'.tr;
        _inlineIsError = true;
      });
      return;
    }

    try {
      await usersProvider.completePasswordReset(
        token: _resetToken,
        newPassword: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _RecoveryStage.resetSuccess;
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final tokenInvalid = usersProvider.isExpiredPasswordResetError(error);

      setState(() {
        if (tokenInvalid) {
          _stage = _RecoveryStage.resetExpired;
          _inlineMessage = null;
        } else {
          _inlineMessage = usersProvider.extractErrorMessage(error);
          _inlineIsError = true;
        }
      });
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isArabic) ...[
            _buildInfoCardIcon(icon, accent),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: _isArabic
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: _isArabic ? TextAlign.right : TextAlign.left,
                  textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF132A4A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: _isArabic ? TextAlign.right : TextAlign.left,
                  textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 12.5,
                    height: 1.55,
                    color: const Color(0xFF566173),
                  ),
                ),
              ],
            ),
          ),
          if (_isArabic) ...[
            const SizedBox(width: 12),
            _buildInfoCardIcon(icon, accent),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCardIcon(IconData icon, Color accent) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }

  Widget _buildCaptionNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2D8C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF66758A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: _isArabic ? TextAlign.right : TextAlign.left,
              textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 12.5,
                height: 1.5,
                color: const Color(0xFF5D697D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineBanner(String message, {required bool isError}) {
    final accent = isError ? AppColors.errorColor : const Color(0xFF0B6B57);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 13,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isLoading,
    IconData icon = Icons.arrow_forward_rounded,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF132A4A),
          disabledBackgroundColor:
              const Color(0xFF132A4A).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction({
    required String label,
    required VoidCallback? onPressed,
    IconData icon = Icons.arrow_back_rounded,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF132A4A),
        side: const BorderSide(color: Color(0xFFD8DDE5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.primaryFont,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF132A4A),
        ),
      ),
    );
  }

  Widget _buildRequestForm(UsersProvider usersProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.mark_email_read_outlined,
          accent: const Color(0xFF0B6B57),
          title: 'forgot_password_request_card_title'.tr,
          body: 'forgot_password_request_card_body'.tr,
        ),
        const SizedBox(height: 18),
        CustomAuthenticationTextField(
          hintText: 'forgot_password_email_hint'.tr,
          semanticLabel: 'forgot_password_email_semantic'.tr,
          obscureText: false,
          leadingIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          textEditingController: _emailController,
          borderColor: _emailBorderColor,
          onSubmitted: (_) {
            if (!usersProvider.isLoading) {
              _handleRequest(usersProvider);
            }
          },
        ),
        const SizedBox(height: 10),
        _buildCaptionNote('forgot_password_request_caption'.tr),
        if (_inlineMessage != null) ...[
          const SizedBox(height: 14),
          _buildInlineBanner(_inlineMessage!, isError: _inlineIsError),
        ],
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'forgot_password_request_submit'.tr,
          icon: Icons.send_rounded,
          isLoading: usersProvider.isLoading,
          onPressed:
              usersProvider.isLoading ? null : () => _handleRequest(usersProvider),
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: 'forgot_password_back_to_sign_in'.tr,
            onPressed: usersProvider.isLoading ? null : _openLogin,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestAccepted(UsersProvider usersProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.mail_outline_rounded,
          accent: const Color(0xFF0B6B57),
          title: 'forgot_password_request_accepted_title'.tr,
          body: 'forgot_password_request_accepted_body'.tr,
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: 'forgot_password_back_to_sign_in'.tr,
          icon: Icons.login_rounded,
          isLoading: false,
          onPressed: _openLogin,
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: 'forgot_password_edit_email'.tr,
            onPressed: () {
              setState(() {
                _stage = _RecoveryStage.requestForm;
                _resetInlineFeedback();
              });
            },
            icon: Icons.edit_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm(UsersProvider usersProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.lock_reset_rounded,
          accent: const Color(0xFFAF7E22),
          title: 'forgot_password_reset_card_title'.tr,
          body: 'forgot_password_reset_card_body'.tr,
        ),
        const SizedBox(height: 18),
        CustomAuthenticationTextField(
          hintText: 'forgot_password_new_password_hint'.tr,
          semanticLabel: 'forgot_password_new_password_hint'.tr,
          obscureText: true,
          leadingIcon: Icons.lock_outline_rounded,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          textEditingController: _passwordController,
          borderColor: _passwordBorderColor,
        ),
        const SizedBox(height: 12),
        CustomAuthenticationTextField(
          hintText: 'forgot_password_confirm_password_hint'.tr,
          semanticLabel: 'forgot_password_confirm_password_hint'.tr,
          obscureText: true,
          leadingIcon: Icons.verified_user_outlined,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          textEditingController: _confirmPasswordController,
          borderColor: _confirmPasswordBorderColor,
          onSubmitted: (_) {
            if (!usersProvider.isLoading) {
              _handleReset(usersProvider);
            }
          },
        ),
        const SizedBox(height: 10),
        _buildCaptionNote('forgot_password_password_rules'.tr),
        if (_inlineMessage != null) ...[
          const SizedBox(height: 14),
          _buildInlineBanner(_inlineMessage!, isError: _inlineIsError),
        ],
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'forgot_password_reset_submit'.tr,
          icon: Icons.check_circle_outline_rounded,
          isLoading: usersProvider.isLoading,
          onPressed:
              usersProvider.isLoading ? null : () => _handleReset(usersProvider),
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: 'forgot_password_back_to_sign_in'.tr,
            onPressed: usersProvider.isLoading ? null : _openLogin,
          ),
        ),
      ],
    );
  }

  Widget _buildResetSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.task_alt_rounded,
          accent: const Color(0xFF0B6B57),
          title: 'forgot_password_reset_success_title'.tr,
          body: 'forgot_password_reset_success_body'.tr,
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: 'forgot_password_back_to_sign_in'.tr,
          icon: Icons.login_rounded,
          isLoading: false,
          onPressed: _openLogin,
        ),
      ],
    );
  }

  Widget _buildResetExpired() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.link_off_rounded,
          accent: const Color(0xFFB13030),
          title: 'forgot_password_reset_expired_title'.tr,
          body: 'forgot_password_reset_expired_body'.tr,
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: 'forgot_password_request_new_link'.tr,
          icon: Icons.mark_email_unread_outlined,
          isLoading: false,
          onPressed: () {
            setState(() {
              _stage = _RecoveryStage.requestForm;
              _resetInlineFeedback();
              _passwordController.clear();
              _confirmPasswordController.clear();
            });
          },
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: 'forgot_password_back_to_sign_in'.tr,
            onPressed: _openLogin,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);

    final title = switch (_stage) {
      _RecoveryStage.requestForm || _RecoveryStage.requestAccepted =>
        'forgot_password_stage_title_request'.tr,
      _RecoveryStage.resetForm || _RecoveryStage.resetSuccess =>
        'forgot_password_stage_title_reset'.tr,
      _RecoveryStage.resetExpired =>
        'forgot_password_stage_title_link'.tr,
    };

    final subtitle = switch (_stage) {
      _RecoveryStage.requestForm =>
        'forgot_password_stage_subtitle_request'.tr,
      _RecoveryStage.requestAccepted =>
        'forgot_password_stage_subtitle_request_accepted'.tr,
      _RecoveryStage.resetForm =>
        'forgot_password_stage_subtitle_reset'.tr,
      _RecoveryStage.resetSuccess =>
        'forgot_password_stage_subtitle_reset_success'.tr,
      _RecoveryStage.resetExpired =>
        'forgot_password_stage_subtitle_reset_expired'.tr,
    };

    final body = switch (_stage) {
      _RecoveryStage.requestForm => _buildRequestForm(usersProvider),
      _RecoveryStage.requestAccepted => _buildRequestAccepted(usersProvider),
      _RecoveryStage.resetForm => _buildResetForm(usersProvider),
      _RecoveryStage.resetSuccess => _buildResetSuccess(),
      _RecoveryStage.resetExpired => _buildResetExpired(),
    };

    return AuthScreenShell(
      title: title,
      subtitle: subtitle,
      isSignup: false,
      onSelectSignup: usersProvider.isLoading
          ? null
          : () => Get.to(() => const SignUpScreen()),
      child: body,
    );
  }
}
