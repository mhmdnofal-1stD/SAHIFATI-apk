import 'package:flutter/material.dart';
import '../../../core/constants/fonts.dart';
import '../../../core/typography/app_typography.dart';

class CustomAuthTextFieldHeader extends StatelessWidget {
  const CustomAuthTextFieldHeader({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          text,
          style: AppTypography.of(context)
              .inputLabel
              .copyWith(fontFamily: AppFonts.primaryFont),
        ),
      ),
    );
  }
}
