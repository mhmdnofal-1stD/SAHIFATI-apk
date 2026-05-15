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
    final isRtlTranslation = isRtlAyahTranslationLanguage(languageCode);
    final translation = lookupAyahTranslation(
      ayah: ayah,
      languageCode: languageCode,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                resolveAyahArabicText(ayah),
                textAlign: textAlign,
                textDirection: TextDirection.rtl,
                softWrap: true,
                maxLines: null,
                overflow: TextOverflow.visible,
                textWidthBasis: TextWidthBasis.parent,
                style: arabicStyle ?? typography.quranVerse,
              ),
              if (translation != null) ...[
                SizedBox(height: spacing),
                Directionality(
                  textDirection:
                      isRtlTranslation ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    translation,
                    textAlign: TextAlign.start,
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    textWidthBasis: TextWidthBasis.parent,
                    style: (translationStyle ?? typography.bodySecondary)
                        .copyWith(height: 1.7),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}