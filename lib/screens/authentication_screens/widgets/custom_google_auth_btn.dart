import 'package:flutter/material.dart';
import '../../../core/constants/assets.dart';
import '../../../core/constants/colors.dart';
import '../../../core/typography/app_typography.dart';
import '../../../core/utils/size_config.dart';

class CustomGoogleAuthBtn extends StatelessWidget {
  const CustomGoogleAuthBtn({super.key, required this.onTap, required this.text});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: SizeConfig.getProportionalHeight(48),
        width: SizeConfig.getProportionalWidth(300),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textFieldBorderColor, width: 1),
          borderRadius: BorderRadius.circular(5),
          color: AppColors.backgroundColor,
        ),
        child: Padding(
          padding: EdgeInsets.only(left: SizeConfig.getProportionalWidth(10)),
          child: Row(
            children: [
              Image.asset(
                Assets.googleIcon,
                height: SizeConfig.getProportionalHeight(26),
                width: SizeConfig.getProportionalWidth(26),
              ),
              Padding(
                padding:
                    EdgeInsets.only(left: SizeConfig.getProportionalWidth(40)),
                child: Directionality(
                  textDirection:TextDirection.rtl,
                  child: Text.rich(
                      TextSpan(children: [
                    TextSpan(
                      text: text,
                      style: AppTypography.of(context).buttonSecondary.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.hintTextColor,
                          ),
                    ),
                    TextSpan(
                      text: ' Google',
                      style: AppTypography.of(context).buttonSecondary.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.hintTextColor,
                          ),
                    ),
                  ])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
