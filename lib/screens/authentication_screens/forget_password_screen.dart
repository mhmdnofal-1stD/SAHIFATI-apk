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

  String _copy(String ar, String en) => _isArabic ? ar : en;

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
        _inlineMessage = _copy(
          'تعذر إرسال رابط إعادة التعيين الآن. حاول مرة أخرى بعد قليل.',
          'The reset link could not be sent right now. Please try again shortly.',
        );
        _inlineIsError = true;
        return;
      case 'reseterror':
        _stage = _RecoveryStage.resetForm;
        _passwordBorderColor = AppColors.errorColor;
        _inlineMessage = _copy(
          'تعذر إكمال إعادة التعيين الآن رغم أن الرابط ما زال صالحًا. حاول مرة أخرى بعد قليل.',
          'The password reset could not be completed right now even though the link is still valid. Please try again shortly.',
        );
        _inlineIsError = true;
        return;
      default:
        return;
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail?.trim() ?? '');
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
      return _copy('أدخل كلمة المرور الجديدة', 'Enter a new password');
    }
    if (password.length < 8) {
      return _copy(
        'يجب أن تتكون كلمة المرور من ثمانية أحرف على الأقل',
        'Password must be at least 8 characters',
      );
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return _copy(
        'يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل',
        'Password must include at least one uppercase letter',
      );
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return _copy(
        'يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل',
        'Password must include at least one lowercase letter',
      );
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return _copy(
        'يجب أن تحتوي كلمة المرور على رقم واحد على الأقل',
        'Password must include at least one number',
      );
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return _copy(
        'يجب أن تحتوي كلمة المرور على رمز واحد على الأقل',
        'Password must include at least one symbol',
      );
    }

    return null;
  }

  Map<String, dynamic>? _asErrorMap(Object error) {
    if (error is Map<String, dynamic>) {
      return error;
    }
    if (error is Map) {
      return error.map(
        (key, value) => MapEntry(key.toString(), value),
      );
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
        _inlineMessage = _copy(
          'أدخل البريد الإلكتروني المرتبط بحسابك',
          'Enter the email linked to your account',
        );
        _inlineIsError = true;
      });
      return;
    }

    if (!GetUtils.isEmail(email)) {
      setState(() {
        _emailBorderColor = AppColors.errorColor;
        _inlineMessage = _copy(
          'أدخل بريدًا إلكترونيًا صحيحًا',
          'Enter a valid email address',
        );
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
        _inlineMessage = _copy(
          'كلمتا المرور غير متطابقتين',
          'Passwords do not match',
        );
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

      final errorMap = _asErrorMap(error);
      final statusCode = errorMap?['statusCode'];
      final message = usersProvider.extractErrorMessage(error).toLowerCase();
      final tokenInvalid = statusCode == 400 ||
          message.contains('invalid or has expired') ||
          message.contains('already used');

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF132A4A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF566173),
                  ),
                ),
              ],
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
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: const Color(0xFF132A4A)),
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
          title: _copy(
            'استعد الوصول إلى حسابك بهدوء',
            'Recover access without guesswork',
          ),
          body: _copy(
            'أدخل بريد الحساب وسنرسل رابط إعادة التعيين إذا كان الحساب مؤهلاً لذلك. لن نعرض رسالة نجاح وهمية خارج العقد الحقيقي مع الخادم.',
            'Enter your account email and we will send a reset link if the account is eligible. The screen only shows accepted feedback when the real backend contract returns it.',
          ),
        ),
        const SizedBox(height: 18),
        CustomAuthenticationTextField(
          hintText: _copy('example@example.com', 'example@example.com'),
          semanticLabel: _copy('البريد الإلكتروني', 'Email address'),
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
        Text(
          _copy(
            'سنحافظ على الرسالة عامة حتى لا تكشف الصفحة ما إذا كان البريد مسجلاً أم لا.',
            'The confirmation stays generic so this surface does not disclose whether the email exists.',
          ),
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            fontSize: 12,
            height: 1.5,
            color: const Color(0xFF6C7280),
          ),
        ),
        if (_inlineMessage != null) ...[
          const SizedBox(height: 14),
          _buildInlineBanner(_inlineMessage!, isError: _inlineIsError),
        ],
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: _copy('إرسال رابط إعادة التعيين', 'Send reset link'),
          icon: Icons.send_rounded,
          isLoading: usersProvider.isLoading,
          onPressed:
              usersProvider.isLoading ? null : () => _handleRequest(usersProvider),
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: _copy('العودة إلى تسجيل الدخول', 'Back to sign in'),
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
          title: _copy(
            'تم تسجيل الطلب',
            'The request was accepted',
          ),
          body: _copy(
            'إذا كان هذا البريد مرتبطًا بحساب قابل لإعادة التعيين فستجد رسالة تحتوي على رابط صالح لمدة قصيرة. افتح الرسالة ثم أكمل التعيين من الرابط نفسه.',
            'If this email is tied to an eligible account, you will receive a short-lived reset email. Open that message and continue from the link itself.',
          ),
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: _copy('العودة إلى تسجيل الدخول', 'Back to sign in'),
          icon: Icons.login_rounded,
          isLoading: false,
          onPressed: _openLogin,
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: _copy('تعديل البريد وإعادة المحاولة', 'Edit email and try again'),
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
          title: _copy(
            'أنشئ كلمة مرور جديدة',
            'Create a new password',
          ),
          body: _copy(
            'استخدم كلمة مرور قوية ثم عد إلى صفحة الدخول. إذا كان الرابط منتهيًا أو سبق استخدامه سنحوّلك مباشرةً إلى طلب رابط جديد.',
            'Choose a strong password, then return to sign in. If the link is expired or already used, the flow will take you back to requesting a fresh one.',
          ),
        ),
        const SizedBox(height: 18),
        CustomAuthenticationTextField(
          hintText: _copy('كلمة المرور الجديدة', 'New password'),
          semanticLabel: _copy('كلمة المرور الجديدة', 'New password'),
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
          hintText: _copy('تأكيد كلمة المرور الجديدة', 'Confirm new password'),
          semanticLabel: _copy(
            'تأكيد كلمة المرور الجديدة',
            'Confirm new password',
          ),
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
        Text(
          _copy(
            'ثمانية أحرف على الأقل مع حرف كبير وصغير ورقم ورمز.',
            'At least 8 characters with uppercase, lowercase, a number, and a symbol.',
          ),
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            fontSize: 12,
            height: 1.5,
            color: const Color(0xFF6C7280),
          ),
        ),
        if (_inlineMessage != null) ...[
          const SizedBox(height: 14),
          _buildInlineBanner(_inlineMessage!, isError: _inlineIsError),
        ],
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: _copy('تحديث كلمة المرور', 'Update password'),
          icon: Icons.check_circle_outline_rounded,
          isLoading: usersProvider.isLoading,
          onPressed:
              usersProvider.isLoading ? null : () => _handleReset(usersProvider),
        ),
        const SizedBox(height: 10),
        Center(
          child: _buildSecondaryAction(
            label: _copy('العودة إلى تسجيل الدخول', 'Back to sign in'),
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
          title: _copy(
            'تم تحديث كلمة المرور',
            'Password updated successfully',
          ),
          body: _copy(
            'يمكنك الآن العودة إلى تسجيل الدخول واستخدام كلمة المرور الجديدة مباشرة. أي جلسات refresh قديمة أُبطلت من جهة الخادم.',
            'You can now return to sign in with the new password. Older refresh sessions were invalidated by the backend.',
          ),
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: _copy('العودة إلى تسجيل الدخول', 'Back to sign in'),
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
          title: _copy(
            'الرابط لم يعد صالحًا',
            'This reset link is no longer valid',
          ),
          body: _copy(
            'قد يكون الرابط منتهي الصلاحية أو استُخدم من قبل. اطلب رابطًا جديدًا للمتابعة بدل إعادة محاولة نموذج لن ينجح.',
            'The link may be expired or already used. Request a new one instead of retrying a form that cannot succeed anymore.',
          ),
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: _copy('طلب رابط جديد', 'Request a new link'),
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
            label: _copy('العودة إلى تسجيل الدخول', 'Back to sign in'),
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
      _RecoveryStage.requestForm || _RecoveryStage.requestAccepted => _copy(
          'استعادة الوصول إلى الحساب',
          'Recover access to your account',
        ),
      _RecoveryStage.resetForm || _RecoveryStage.resetSuccess => _copy(
          'إعادة تعيين كلمة المرور',
          'Reset your password',
        ),
      _RecoveryStage.resetExpired => _copy(
          'رابط إعادة التعيين',
          'Password reset link',
        ),
    };

    final subtitle = switch (_stage) {
      _RecoveryStage.requestForm => _copy(
          'جزء واضح من رحلة الدخول نفسها: اطلب الرابط، افتح البريد، ثم عد إلى الحساب من دون رسائل مضللة.',
          'A clear part of the sign-in journey: request the link, open the email, and come back without misleading success states.',
        ),
      _RecoveryStage.requestAccepted => _copy(
          'الخطوة التالية أصبحت في البريد. عندما يفتح الرابط سننقلك مباشرة إلى تحديث كلمة المرور.',
          'The next step is now in the email. When the link opens, this flow will take you straight into the new-password step.',
        ),
      _RecoveryStage.resetForm => _copy(
          'أنت الآن في الخطوة الحاسمة: غيّر كلمة المرور ثم ارجع إلى شاشة الدخول بكلمة المرور الجديدة.',
          'You are at the decisive step now: set the new password, then return to sign in with it.',
        ),
      _RecoveryStage.resetSuccess => _copy(
          'الرحلة اكتملت. لم يبقَ إلا تسجيل الدخول مجددًا بكلمة المرور الجديدة.',
          'The recovery journey is complete. The only next step is signing in with the updated password.',
        ),
      _RecoveryStage.resetExpired => _copy(
          'لا نحاول إخفاء المشكلة هنا: هذا الرابط لم يعد صالحًا ويجب استبداله بطلب جديد.',
          'This flow does not hide the problem: the link is no longer valid and must be replaced with a fresh request.',
        ),
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
