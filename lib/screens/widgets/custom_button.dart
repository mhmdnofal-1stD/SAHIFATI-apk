import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import 'custom_text.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.onPressed,
    this.text,
    required this.width,
    required this.height,
    this.icon,
    this.isDisabled = false,
  });

  final VoidCallback? onPressed;
  final String? text;
  final double width;
  final double height;
  final IconData? icon;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final labelFontSize = height >= 48 ? 16.0 : 14.0;
    final Color backgroundColor =
    isDisabled ? Colors.grey : AppColors.primaryPurple;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed, // disable if needed
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 18 : 12,
            vertical: height >= 48 ? 10 : 8,
          ),
          minimumSize: Size(width, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height >= 48 ? 10 : 6),
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(
            icon,
            size: 20,
            color: isDisabled ? Colors.black38 : Colors.white,
          )
              : text != null
              ? CustomText(
            text: text!,
            withBackground: false,
            fontSize: labelFontSize,
            fontWeight:  FontWeight.bold ,
            color: isDisabled ? Colors.black38 : Colors.white,
          )
              : null,
        ),
      ),
    );
  }
}
