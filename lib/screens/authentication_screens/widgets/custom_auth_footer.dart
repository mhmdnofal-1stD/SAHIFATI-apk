import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/fonts.dart';

class CustomAuthFooter extends StatelessWidget {
  const CustomAuthFooter({
    super.key,
    required this.headingText,
    required this.tailText,
    required this.onTap,
  });

  final String headingText;
  final String tailText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: headingText,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 16,
                color: AppColors.blackFontColor,
              ),
            ),
            const WidgetSpan(
              child: SizedBox(width: 8),
            ),
            TextSpan(
              text: tailText,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: 16,
                color: Colors.grey,
                decoration: TextDecoration.underline,
                decorationColor: Colors.grey,
              ),
              recognizer: TapGestureRecognizer()..onTap = onTap,
            ),
          ],
        ),
        textAlign: TextAlign.start,
      ),
    );
  }
}
