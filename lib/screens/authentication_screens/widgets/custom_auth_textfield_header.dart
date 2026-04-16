import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/fonts.dart';

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
          style: TextStyle(
            fontSize: 14,
            fontFamily: AppFonts.primaryFont,
            color: AppColors.hintTextColor,
          ),
        ),
      ),
    );
  }
}
