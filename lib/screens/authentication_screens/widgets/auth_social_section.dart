import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';

enum AuthSocialStatusTone { error, info }

class AuthSocialSection extends StatelessWidget {
  const AuthSocialSection({
    super.key,
    required this.googleControl,
    required this.onFacebookPressed,
    required this.isBusy,
    this.showFacebook = true,
    this.showEmailMethod = false,
    this.googleHint,
    this.facebookHint,
    this.statusMessage,
    this.statusTone = AuthSocialStatusTone.error,
  });

  final Widget googleControl;
  final VoidCallback? onFacebookPressed;
  final bool isBusy;
  final bool showFacebook;
  final bool showEmailMethod;
  final String? googleHint;
  final String? facebookHint;
  final String? statusMessage;
  final AuthSocialStatusTone statusTone;

  String _sectionLabel() {
    return (Get.locale?.languageCode ?? 'ar') == 'ar'
        ? 'خيارات دخول أخرى'
        : 'Other sign-in options';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE1D3C0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _sectionLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF58657A),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 16,
                children: [
                  if (showEmailMethod)
                    const _StaticMethodIcon(
                      icon: Icons.alternate_email_rounded,
                      labelKey: 'auth_method_email',
                    ),
                  _MethodSlot(
                    label: 'social_provider_google'.tr,
                    child: googleControl,
                  ),
                  if (showFacebook)
                    _MethodSlot(
                      label: 'social_provider_facebook'.tr,
                      child: AuthCompactSocialButton(
                        semanticLabel: 'social_provider_facebook'.tr,
                        onPressed: onFacebookPressed,
                        isBusy: isBusy,
                        icon: const Icon(
                          Icons.facebook_rounded,
                          color: Color(0xFF1877F2),
                          size: 25,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (statusMessage != null) ...[
          const SizedBox(height: 14),
          _SocialStatusBanner(
            message: statusMessage!,
            tone: statusTone,
          ),
        ],
      ],
    );
  }
}

class AuthCompactSocialButton extends StatelessWidget {
  const AuthCompactSocialButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.isBusy,
    this.onPressed,
  });

  final String semanticLabel;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: enabled ? Colors.white : const Color(0xFFF0ECE7),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: enabled
                    ? const Color(0xFFD7D9DE)
                    : const Color(0xFFE3DFD9),
              ),
              boxShadow: enabled
                  ? const [
                      BoxShadow(
                        color: Color(0x0F132A4A),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isBusy && onPressed != null
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodSlot extends StatelessWidget {
  const _MethodSlot({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Center(child: child),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D697D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticMethodIcon extends StatelessWidget {
  const _StaticMethodIcon({
    required this.icon,
    required this.labelKey,
  });

  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: labelKey.tr,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF132A4A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labelKey.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D697D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialStatusBanner extends StatelessWidget {
  const _SocialStatusBanner({
    required this.message,
    required this.tone,
  });

  final String message;
  final AuthSocialStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isError = tone == AuthSocialStatusTone.error;
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    final borderColor =
        isError ? AppColors.errorColor : const Color(0xFF0F766E);
    final backgroundColor = isError
        ? AppColors.errorColor.withValues(alpha: 0.07)
        : const Color(0xFF0F766E).withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: borderColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 13,
                color: borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}