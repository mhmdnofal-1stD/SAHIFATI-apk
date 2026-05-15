import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';

class CustomVerseText extends StatelessWidget {
  final String text;
  final int category;
  final Color backgroundColor;

  const CustomVerseText({
    super.key,
    required this.text,
    required this.category,
  }) : backgroundColor = (
      category == 1 ? AppColors.strongColor :
      category == 2 ? AppColors.revisionColor :
      category == 3 ? AppColors.desireColor :
      category == 4 ? AppColors.easyColor :
      category == 5 ? AppColors.hardColor :
      category == 6 ? AppColors.uncategorizedColor :
      AppColors.uncategorizedColor
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: false,
            onChanged: (val) {},
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: AppColors.whiteFontColor,
            checkColor: backgroundColor,
          ),
          Flexible(
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.start,
              softWrap: true,
              maxLines: null,
              overflow: TextOverflow.visible,
              textWidthBasis: TextWidthBasis.parent,
              style: AppTypography.of(context)
                  .quranVerse
                  .copyWith(
                    fontSize: 14,
                    color: AppColors.whiteFontColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}


class CustomVerseText2 extends StatelessWidget {
  final String text;
  final int verseNumber;
  final Color backgroundColor;

  const CustomVerseText2({
    super.key,
    required this.text,
    required this.verseNumber,
    required this.backgroundColor
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: text,
                  style: t.quranVerse.copyWith(color: backgroundColor),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE0E0E0),
                      ),
                      child: Text(
                        _toArabicNumber(verseNumber),
                        textDirection: TextDirection.rtl,
                        style: t.quranAyahMarker,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' '),
              ],
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            softWrap: true,
            maxLines: null,
            overflow: TextOverflow.visible,
            textWidthBasis: TextWidthBasis.parent,
          ),
        );
      },
    );
  }

  /// Converts an integer (e.g., 12) to Arabic numerals (e.g., ١٢)
  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join('');
  }
}
