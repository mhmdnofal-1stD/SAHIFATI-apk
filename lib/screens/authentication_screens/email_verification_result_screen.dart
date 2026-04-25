import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/verification_flow.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';
import 'package:sahifaty/providers/users_provider.dart';

enum VerificationResultState {
  success,
  failed,
  expired,
}

class EmailVerificationResultScreen extends StatelessWidget {
  const EmailVerificationResultScreen({
    super.key,
    required this.state,
    this.email,
  });

  final VerificationResultState state;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final resolvedEmail = email ??
        Get.parameters['email'] ??
        usersProvider.pendingVerificationEmail;

    final config = _stateConfig(state);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: config.badgeColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          config.icon,
                          size: 40,
                          color: config.iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      config.titleKey.tr,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackFontColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      config.descriptionKey.tr,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: 14,
                        color: AppColors.hintTextColor,
                        height: 1.6,
                      ),
                    ),
                    if (resolvedEmail != null && resolvedEmail.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x1F0F284A)),
                        ),
                        child: Text(
                          maskEmailAddress(resolvedEmail),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: AppFonts.primaryFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (state == VerificationResultState.success) {
                            Get.offAllNamed(
                              usersProvider.hasActiveLicense
                                  ? '/welcome'
                                  : '/license-activation',
                            );
                            return;
                          }

                          if (state == VerificationResultState.expired &&
                              resolvedEmail != null &&
                              resolvedEmail.isNotEmpty) {
                            await usersProvider.setPendingVerificationState(
                              resolvedEmail,
                              sentAt: DateTime.now().subtract(
                                const Duration(seconds: 60),
                              ),
                            );
                            if (!context.mounted) return;
                            Get.offAllNamed(
                              '/verification-pending',
                              parameters: {'email': resolvedEmail},
                            );
                            return;
                          }

                          Get.offAllNamed('/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          config.primaryActionKey.tr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppFonts.primaryFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        if (state == VerificationResultState.success) {
                          await usersProvider.clearPendingVerificationState();
                          if (!context.mounted) return;
                          Get.offAllNamed('/login');
                          return;
                        }

                        await usersProvider.clearPendingVerificationState();
                        if (!context.mounted) return;
                        Get.offAllNamed('/signup');
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Color(0x220F284A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        state == VerificationResultState.success
                            ? 'email_verification_result_back_to_login'.tr
                            : 'email_verification_result_back_to_signup'.tr,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: AppFonts.primaryFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryPurple,
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
    );
  }
}

class EmailVerificationHandlerScreen extends StatefulWidget {
  const EmailVerificationHandlerScreen({
    super.key,
    this.token,
    this.email,
  });

  final String? token;
  final String? email;

  @override
  State<EmailVerificationHandlerScreen> createState() =>
      _EmailVerificationHandlerScreenState();
}

class _EmailVerificationHandlerScreenState
    extends State<EmailVerificationHandlerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyToken());
  }

  Future<void> _verifyToken() async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final routeEmail = widget.email ?? Get.parameters['email'];
    final token = widget.token ?? Get.parameters['token'];

    if (routeEmail != null && routeEmail.isNotEmpty) {
      await usersProvider.setPendingVerificationState(
        routeEmail,
        sentAt: usersProvider.pendingVerificationSentAt,
      );
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Get.offAllNamed(
        '/verification-failed',
        parameters: {
          if (routeEmail != null) 'email': routeEmail,
        },
      );
      return;
    }

    try {
      await usersProvider.verifyEmailToken(token);
      if (!mounted) return;
      Get.offAllNamed(
        '/verification-success',
        parameters: {
          if (routeEmail != null) 'email': routeEmail,
        },
      );
    } catch (error) {
      if (!mounted) return;
      final resultState = usersProvider.isExpiredVerificationError(error)
          ? VerificationResultState.expired
          : VerificationResultState.failed;
      Get.offAllNamed(
        resultState == VerificationResultState.expired
            ? '/verification-expired'
            : '/verification-failed',
        parameters: {
          if (routeEmail != null) 'email': routeEmail,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0x140F284A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const CircularProgressIndicator.adaptive(),
              ),
              const SizedBox(height: 20),
              Text(
                'email_verification_result_loading_title'.tr,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackFontColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'email_verification_result_loading_body'.tr,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  fontSize: 13,
                  color: AppColors.hintTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationStateConfig {
  const _VerificationStateConfig({
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
    required this.titleKey,
    required this.descriptionKey,
    required this.primaryActionKey,
    required this.primaryColor,
  });

  final IconData icon;
  final Color badgeColor;
  final Color iconColor;
  final String titleKey;
  final String descriptionKey;
  final String primaryActionKey;
  final Color primaryColor;
}

_VerificationStateConfig _stateConfig(VerificationResultState state) {
  switch (state) {
    case VerificationResultState.success:
      return const _VerificationStateConfig(
        icon: Icons.verified_rounded,
        badgeColor: Color(0x140B503D),
        iconColor: Color(0xFF0B503D),
        titleKey: 'email_verification_result_success_title',
        descriptionKey: 'email_verification_result_success_body',
        primaryActionKey: 'email_verification_result_success_action',
        primaryColor: AppColors.buttonColor,
      );
    case VerificationResultState.expired:
      return const _VerificationStateConfig(
        icon: Icons.schedule_rounded,
        badgeColor: Color(0x14D89B00),
        iconColor: Color(0xFFB07E00),
        titleKey: 'email_verification_result_expired_title',
        descriptionKey: 'email_verification_result_expired_body',
        primaryActionKey: 'email_verification_result_expired_action',
        primaryColor: Color(0xFFC48A00),
      );
    case VerificationResultState.failed:
      return const _VerificationStateConfig(
        icon: Icons.error_outline_rounded,
        badgeColor: Color(0x14EA0000),
        iconColor: AppColors.errorColor,
        titleKey: 'email_verification_result_failed_title',
        descriptionKey: 'email_verification_result_failed_body',
        primaryActionKey: 'email_verification_result_failed_action',
        primaryColor: AppColors.primaryPurple,
      );
  }
}
