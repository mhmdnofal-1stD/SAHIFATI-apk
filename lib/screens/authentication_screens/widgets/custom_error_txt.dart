import 'package:flutter/material.dart';
import '../../../core/constants/fonts.dart';
import '../../../core/typography/app_typography.dart';
import '../../../core/utils/size_config.dart';

class CustomErrorTxt extends StatelessWidget {
  const CustomErrorTxt({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:  Alignment.topRight,
      child: Padding(
        padding:  EdgeInsets.only(right: SizeConfig.getProportionalWidth(35)),
        child: Text(
          text,
          style: AppTypography.of(context)
              .inputError
              .copyWith(fontFamily: AppFonts.primaryFont),
        ),
      ),
    );
  }
}
