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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFD8DEE7))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'continue_with_social'.tr,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.hintTextColor,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFD8DEE7))),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'social_auth_subtitle'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            fontSize: 13,
            color: AppColors.hintTextColor,
          ),
        ),
        const SizedBox(height: 16),
        _SocialProviderCard(
          title: 'social_google_card_title'.tr,
          subtitle: 'social_google_card_subtitle'.tr,
          icon: Image.asset(
            Assets.googleIcon,
            width: 20,
            height: 20,
          ),
          control: googleControl,
          hint: googleHint,
        ),
        if (showFacebook) ...[
          const SizedBox(height: 12),
          _SocialProviderCard(
            title: 'social_facebook_card_title'.tr,
            subtitle: 'social_facebook_card_subtitle'.tr,
            icon: const Icon(
              Icons.facebook_rounded,
              color: Color(0xFF1877F2),
              size: 22,
            ),
            control: _SocialActionButton(
              label: 'facebook_continue'.tr,
              onPressed: onFacebookPressed,
              isBusy: isBusy,
              accentColor: const Color(0xFF1877F2),
            ),
            hint: facebookHint,
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

class _SocialProviderCard extends StatelessWidget {
  const _SocialProviderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.control,
    this.hint,
  });

  final String title;
  final String subtitle;
  final Widget icon;
  final Widget control;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackFontColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        fontSize: 12,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          control,
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(
              hint!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 12,
                color: AppColors.hintTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SocialActionButton extends StatelessWidget {
  const _SocialActionButton({
    required this.label,
    required this.onPressed,
    required this.isBusy,
    required this.accentColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: enabled ? accentColor : AppColors.hintTextColor,
          side: BorderSide(
            color: enabled ? accentColor.withValues(alpha: 0.35) : const Color(0xFFE0E5EC),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            fontSize: 14,
            fontWeight: FontWeight.w700,
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