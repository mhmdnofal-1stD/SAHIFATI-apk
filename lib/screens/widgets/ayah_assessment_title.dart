import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import '../../core/constants/fonts.dart';
import '../../core/typography/app_typography.dart';
import '../../models/ayat.dart';
import '../../services/ayah_translation_library_service.dart';

String _normalizeAyahTranslationLanguageCode(String languageCode) {
  final normalized = languageCode.trim().toLowerCase().replaceAll('_', '-');
  if (normalized.isEmpty) {
    return 'ar';
  }

  return normalized.split('-').first;
}

bool isRtlAyahTranslationLanguage(String languageCode) {
  const rtlLanguages = {'ar', 'fa', 'he', 'ku', 'ps', 'ur'};
  return rtlLanguages.contains(_normalizeAyahTranslationLanguageCode(languageCode));
}

String resolveAyahArabicText(Ayat ayah) {
  return ayah.text.trim().isNotEmpty
      ? ayah.text.trim()
      : quran.getVerse(ayah.surah.id, ayah.ayahNo, verseEndSymbol: false)
          .trim();
}

String? lookupAyahTranslation({
  required Ayat ayah,
  required String languageCode,
}) {
  final normalizedLanguageCode =
      _normalizeAyahTranslationLanguageCode(languageCode);
  if (normalizedLanguageCode == 'ar') {
    return null;
  }

  return AyahTranslationLibraryService.lookup(
    languageCode: normalizedLanguageCode,
    surahId: ayah.surah.id,
    ayahNo: ayah.ayahNo,
  );
}

Widget buildAyahAssessmentDialogTitle({
  required BuildContext context,
  required Ayat ayah,
  required String languageCode,
}) {
  final typography = AppTypography.of(context, listen: false);
  final arabicText = resolveAyahArabicText(ayah);
  final translation = lookupAyahTranslation(
    ayah: ayah,
    languageCode: languageCode,
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        arabicText,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        softWrap: true,
        maxLines: null,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: true,
          applyHeightToLastDescent: true,
        ),
        strutStyle: const StrutStyle(
          fontFamily: AppFonts.versesFont,
          fontSize: 19,
          height: 1.55,
          forceStrutHeight: true,
        ),
        style: typography.quranVerse.copyWith(
          fontFamily: AppFonts.versesFont,
          fontSize: 19,
          height: 1.55,
          letterSpacing: 0,
        ),
      ),
      if (translation != null) ...[
        const SizedBox(height: 10),
        Directionality(
          textDirection: isRtlAyahTranslationLanguage(languageCode)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Text(
            translation,
            textAlign: TextAlign.start,
            softWrap: true,
            style: typography.bodySecondary.copyWith(height: 1.7),
          ),
        ),
      ],
    ],
  );
}