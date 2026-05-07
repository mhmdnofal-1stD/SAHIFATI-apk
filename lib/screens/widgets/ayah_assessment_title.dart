import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

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
  final typography = AppTypography.of(context);
  final arabicText = resolveAyahArabicText(ayah);
  final translation = lookupAyahTranslation(
    ayah: ayah,
    languageCode: languageCode,
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (translation != null) ...[
        Text(
          translation,
          textAlign: TextAlign.center,
          style: typography.dialogTitle,
        ),
        const SizedBox(height: 12),
      ],
      Text(
        arabicText,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: typography.quranVerse,
      ),
    ],
  );
}