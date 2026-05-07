
import 'package:flutter/material.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/core/utils/size_config.dart';

class SocialLoginButton extends StatelessWidget {
  final String text;
  final String? iconPath;
  final IconData? iconData;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const SocialLoginButton({
    super.key,
    required this.text,
    this.iconPath,
    this.iconData,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.85,
      height: SizeConfig.getProportionalHeight(50),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: textColor ?? Colors.black,
          elevation: 1,
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconPath != null)
              Image.asset(
                iconPath!,
                height: 24,
                width: 24,
              ),
            if (iconData != null)
              Icon(
                iconData,
                color: textColor ?? Colors.white,
                size: 24,
              ),
            if (iconPath != null || iconData != null)
              SizedBox(width: SizeConfig.getProportionalWidth(10)),
            Text(
              text,
              style: AppTypography.of(context).buttonSecondary.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? Colors.black,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
