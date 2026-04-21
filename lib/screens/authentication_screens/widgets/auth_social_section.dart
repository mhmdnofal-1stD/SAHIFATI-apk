import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';

enum AuthSocialStatusTone { error, info }

/// Premium compact social auth row.
///
/// Renders a subtle "or" divider followed by a centered row of small circular
/// provider buttons. The caller supplies the concrete Google control (the
/// official GIS icon button on web, or a native fallback) and the section
/// applies consistent sizing and spacing around it.
class AuthSocialSection extends StatelessWidget {
  const AuthSocialSection({
    super.key,
    required this.googleControl,
    required this.onFacebookPressed,
    required this.isBusy,
    this.showFacebook = true,
    this.statusMessage,
    this.statusTone = AuthSocialStatusTone.error,
  });

  final Widget googleControl;
  final VoidCallback? onFacebookPressed;
  final bool isBusy;
  final bool showFacebook;
  final String? statusMessage;
  final AuthSocialStatusTone statusTone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PremiumDivider(label: 'continue_with_social'.tr),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIconSlot(child: googleControl),
            if (showFacebook) ...[
              const SizedBox(width: 14),
              _SocialIconSlot(
                child: _FacebookIconButton(
                  onPressed: isBusy ? null : onFacebookPressed,
                ),
              ),
            ],
          ],
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

class _PremiumDivider extends StatelessWidget {
  const _PremiumDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0x00D8DEE7), Color(0xFFD8DEE7), Color(0x00D8DEE7)],
    );
    return Row(
      children: [
        const Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: SizedBox(height: 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.hintTextColor,
            ),
          ),
        ),
        const Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: SizedBox(height: 1),
          ),
        ),
      ],
    );
  }
}

/// Fixed-size circular slot so every provider renders identically regardless
/// of whether it comes from GIS or a native button.
class _SocialIconSlot extends StatelessWidget {
  const _SocialIconSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: child),
    );
  }
}

class _FacebookIconButton extends StatelessWidget {
  const _FacebookIconButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const Center(
          child: Icon(
            Icons.facebook_rounded,
            color: Color(0xFF1877F2),
            size: 26,
          ),
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
