import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';

enum AuthSocialStatusTone { error, info }

class AuthSocialSection extends StatelessWidget {
  const AuthSocialSection({
    super.key,
    required this.controls,
    this.showEmailMethod = false,
    this.statusMessage,
    this.statusTone = AuthSocialStatusTone.error,
  });

  /// Pre-built social-button widgets in display order.
  /// Assembled by [SocialAuthAction.buildSocialSection].
  final List<Widget> controls;
  final bool showEmailMethod;
  final String? statusMessage;
  final AuthSocialStatusTone statusTone;

  String _sectionLabel() {
    return 'continue_with_social'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final iconChildren = <Widget>[
      if (showEmailMethod)
        const _StaticMethodIcon(
          icon: Icons.alternate_email_rounded,
          labelKey: 'auth_method_email',
        ),
      ...controls,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            _sectionLabel(),
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            style: AppTypography.of(context).inputLabel.copyWith(
                  color: const Color(0xFF58657A),
                ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: iconChildren,
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
                color: AppColors.primaryPurple,
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
              style: AppTypography.of(context).bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
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
              style: AppTypography.of(context).bannerBody.copyWith(
                    color: borderColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
