import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/assets.dart';
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
    this.googleHint,
    this.facebookHint,
    this.statusMessage,
    this.statusTone = AuthSocialStatusTone.error,
  });

  final Widget googleControl;
  final VoidCallback? onFacebookPressed;
  final bool isBusy;
  final bool showFacebook;
  final String? googleHint;
  final String? facebookHint;
  final String? statusMessage;
  final AuthSocialStatusTone statusTone;

  @override
  Widget build(BuildContext context) {
    final hasHints = googleHint != null || (showFacebook && facebookHint != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'auth_methods_label'.tr,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF132A4A),
              ),
            ),
            const Spacer(),
            Text(
              'continue_with_social'.tr,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 12,
                color: AppColors.hintTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F1EA),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8DECF)),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 14,
            children: [
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
        ),
        if (hasHints) ...[
          const SizedBox(height: 12),
          Column(
            children: [
              if (googleHint != null)
                _HintChip(
                  message: googleHint!,
                  icon: Image.asset(
                    Assets.googleIcon,
                    width: 14,
                    height: 14,
                  ),
                ),
              if (showFacebook && facebookHint != null) ...[
                if (googleHint != null) const SizedBox(height: 8),
                _HintChip(
                  message: facebookHint!,
                  icon: const Icon(
                    Icons.facebook_rounded,
                    color: Color(0xFF1877F2),
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ],
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
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Center(child: child),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF536070),
            ),
          ),
        ],
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
    return SizedBox(
      width: 74,
      child: Column(
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF132A4A),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({
    this.message,
    required this.icon,
  });

  final String? message;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final text = message ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DED6)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 11,
                color: const Color(0xFF6D7684),
              ),
            ),
          ),
        ],
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
              textDirection: TextDirection.rtl,
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