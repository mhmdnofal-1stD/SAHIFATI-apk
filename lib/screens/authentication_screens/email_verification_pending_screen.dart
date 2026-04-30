import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/verification_flow.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/providers/users_provider.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  const EmailVerificationPendingScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  Timer? _timer;
  String? _feedbackMessage;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final usersProvider = Provider.of<UsersProvider>(context, listen: false);
      await usersProvider.loadPendingVerificationState();
      final routeEmail = widget.initialEmail ?? Get.parameters['email'];
      if (routeEmail != null && routeEmail.isNotEmpty) {
        await usersProvider.setPendingVerificationState(
          routeEmail,
          sentAt: usersProvider.pendingVerificationSentAt,
        );
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  int _remainingSeconds(UsersProvider usersProvider) {
    final sentAt = usersProvider.pendingVerificationSentAt;
    if (sentAt == null) {
      return 0;
    }

    final elapsed = DateTime.now().difference(sentAt).inSeconds;
    final remaining = 60 - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _handleResend(UsersProvider usersProvider) async {
    final email = usersProvider.pendingVerificationEmail;
    if (email == null || email.isEmpty || _isResending) {
      return;
    }

    setState(() {
      _isResending = true;
      _feedbackMessage = null;
    });

    try {
      await usersProvider.resendVerificationEmail(email: email);
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'email_verification_pending_resend_success'.tr;
      });
    } catch (error) {
      if (!mounted) return;
      final message = usersProvider.extractErrorMessage(error);
      setState(() {
        _feedbackMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _goToLogin(UsersProvider usersProvider) async {
    await usersProvider.clearPendingVerificationState();
    if (!mounted) return;
    Get.offAllNamed('/login');
  }

  Future<void> _changeEmail(UsersProvider usersProvider) async {
    await usersProvider.clearPendingVerificationState();
    if (!mounted) return;
    Get.offAllNamed('/signup');
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final email = usersProvider.pendingVerificationEmail ??
        widget.initialEmail ??
        Get.parameters['email'] ??
        '';
    final remainingSeconds = _remainingSeconds(usersProvider);
    final resendEnabled = remainingSeconds == 0 && !_isResending;
    final maskedEmail = email.isEmpty
      ? 'email_verification_pending_email_fallback'.tr
      : maskEmailAddress(email);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x1A0F284A), Color(0x000F284A)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x140B503D), Color(0x000B503D)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F284A),
                          blurRadius: 34,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0x140F284A),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.mark_email_unread_rounded,
                                color: AppColors.primaryPurple,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'email_verification_pending_title'.tr,
                                    textDirection: TextDirection.rtl,
                                    style: AppTypography.of(context)
                                        .pageHeading
                                        .copyWith(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.blackFontColor,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'email_verification_pending_subtitle'.tr,
                                    textDirection: TextDirection.rtl,
                                    style: AppTypography.of(context)
                                        .bodySecondary
                                        .copyWith(
                                          fontSize: 13,
                                          color: AppColors.hintTextColor,
                                          height: 1.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF5F8FF), Color(0xFFFFFFFF)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x1F0F284A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: SvgPicture.asset(
                                  Assets.logoSvg,
                                  width: 64,
                                  height: 64,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'email_verification_pending_sent_to'.tr,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: AppTypography.of(context)
                                    .bodySecondary
                                    .copyWith(
                                      color: AppColors.hintTextColor,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0x220B503D),
                                  ),
                                ),
                                child: Text(
                                  maskedEmail,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.ltr,
                                  style: AppTypography.of(context)
                                      .userDisplayName
                                      .copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryPurple,
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const _StepLine(
                                icon: Icons.mark_email_read_outlined,
                                titleKey: 'email_verification_pending_step_1_title',
                                subtitleKey:
                                    'email_verification_pending_step_1_subtitle',
                              ),
                              const SizedBox(height: 12),
                              const _StepLine(
                                icon: Icons.verified_outlined,
                                titleKey: 'email_verification_pending_step_2_title',
                                subtitleKey:
                                    'email_verification_pending_step_2_subtitle',
                              ),
                              const SizedBox(height: 12),
                              const _StepLine(
                                icon: Icons.rocket_launch_outlined,
                                titleKey: 'email_verification_pending_step_3_title',
                                subtitleKey:
                                    'email_verification_pending_step_3_subtitle',
                              ),
                            ],
                          ),
                        ),
                        if (_feedbackMessage != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FBF9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x220B503D)),
                            ),
                            child: Text(
                              _feedbackMessage!,
                              textDirection: TextDirection.rtl,
                              style: AppTypography.of(context)
                                  .bannerBody
                                  .copyWith(
                                    color: const Color(0xFF184C3A),
                                    height: 1.5,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: resendEnabled
                                ? () => _handleResend(usersProvider)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              disabledBackgroundColor:
                                  AppColors.primaryPurple.withValues(alpha: 0.42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isResending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    resendEnabled
                                    ? 'email_verification_pending_resend_action'
                                      .tr
                                    : 'email_verification_pending_resend_wait'
                                      .trParams({
                                      'seconds':
                                        remainingSeconds.toString(),
                                      }),
                                    textDirection: TextDirection.rtl,
                                    style: AppTypography.of(context)
                                        .buttonPrimary
                                        .copyWith(color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _changeEmail(usersProvider),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: Color(0x260F284A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'email_verification_pending_change_email'.tr,
                            textDirection: TextDirection.rtl,
                            style: AppTypography.of(context)
                                .buttonSecondary
                                .copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryPurple,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _goToLogin(usersProvider),
                          child: Text(
                            'email_verification_pending_back_to_login'.tr,
                            textDirection: TextDirection.rtl,
                            style: AppTypography.of(context)
                                .bodySecondary
                                .copyWith(
                                  color: AppColors.hintTextColor,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });

  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0x120B503D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0B503D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleKey.tr,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context).listTileTitle.copyWith(
                      color: AppColors.blackFontColor,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleKey.tr,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context).listTileSubtitle.copyWith(
                      fontSize: 12,
                      color: AppColors.hintTextColor,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
