import 'package:flutter/material.dart';
import 'package:sahifaty/core/constants/fonts.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';

class CustomText extends StatelessWidget {
  const CustomText(
      {super.key,
      required this.text,
      this.structHeight,
      this.structLeading,
      this.fontSize,
      this.textHeight,
      required this.withBackground,
      this.color,
      this.fontWeight,
      this.textAlign,
      this.maxLines,
      this.overflow});

  final String text;
  final double? structHeight;
  final double? structLeading;
  final double? fontSize;
  final double? textHeight;
  final bool withBackground;
  final Color? color;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = AppTypography.of(context).bodyDefault;
    return Container(
      color: withBackground ?  AppColors.primaryPurple : Colors.transparent,
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: true,
        overflow: overflow,
        textAlign: textAlign ?? TextAlign.center,
        strutStyle: StrutStyle(
          forceStrutHeight: true,
          height: structHeight,
          leading: structLeading,
        ),
        style: base.copyWith(
          fontSize: fontSize ?? base.fontSize,
          height: textHeight ?? base.height ?? 1,
          color: color ?? base.color ?? Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: fontWeight ?? base.fontWeight ?? AppFonts.normal,
        ),
      ),
    );
  }
}
