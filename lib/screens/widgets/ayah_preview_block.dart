import 'package:flutter/material.dart';

import '../../core/typography/app_typography.dart';
import '../../models/ayat.dart';
import 'ayah_assessment_title.dart';

class AyahPreviewBlock extends StatelessWidget {
  const AyahPreviewBlock({
    super.key,
    required this.ayah,
    required this.languageCode,
    this.translationStyle,
    this.arabicStyle,
    this.spacing = 10,
    this.textAlign = TextAlign.center,
  });

  final Ayat ayah;
  final String languageCode;
  final TextStyle? translationStyle;
  final TextStyle? arabicStyle;
  final double spacing;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    final translation = lookupAyahTranslation(
      ayah: ayah,
      languageCode: languageCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (translation != null) ...[
          Text(
            translation,
            textAlign: textAlign,
            style: translationStyle ?? typography.bodySecondary,
          ),
          SizedBox(height: spacing),
        ],
        Text(
          resolveAyahArabicText(ayah),
          textAlign: textAlign,
          textDirection: TextDirection.rtl,
          style: arabicStyle ?? typography.quranVerse,
        ),
      ],
    );
  }
}