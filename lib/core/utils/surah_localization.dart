import 'package:quran/quran.dart' as quran;

String normalizeSurahLocaleCode(String? localeCode) {
  final normalized = (localeCode ?? 'ar').trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'ar';
  }

  return normalized.split(RegExp(r'[-_]')).first;
}

String? _localizedMapValue(
  Map<String, String>? localizedNames,
  String localeCode,
) {
  if (localizedNames == null || localizedNames.isEmpty) {
    return null;
  }

  final direct = localizedNames[localeCode]?.trim();
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }

  for (final entry in localizedNames.entries) {
    if (normalizeSurahLocaleCode(entry.key) != localeCode) {
      continue;
    }

    final value = entry.value.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

String? _packageSurahNameByLocale(int surahId, String localeCode) {
  if (surahId < 1 || surahId > quran.totalSurahCount) {
    return null;
  }

  switch (localeCode) {
    case 'ar':
      return quran.getSurahNameArabic(surahId);
    case 'en':
      return quran.getSurahNameEnglish(surahId);
    case 'tr':
      return quran.getSurahNameTurkish(surahId);
    case 'fr':
      return quran.getSurahNameFrench(surahId);
    case 'ru':
      return quran.getSurahNameRussian(surahId);
    default:
      return null;
  }
}

String localizedSurahName({
  required int surahId,
  required String fallbackArabicName,
  Map<String, String>? localizedNames,
  String? localeCode,
}) {
  final normalizedLocale = normalizeSurahLocaleCode(localeCode);

  final localized = _localizedMapValue(localizedNames, normalizedLocale);
  if (localized != null) {
    return localized;
  }

  final packageLocalized = _packageSurahNameByLocale(surahId, normalizedLocale);
  if (packageLocalized != null && packageLocalized.trim().isNotEmpty) {
    return packageLocalized.trim();
  }

  final english = _localizedMapValue(localizedNames, 'en');
  if (english != null) {
    return english;
  }

  final arabic = _localizedMapValue(localizedNames, 'ar');
  if (arabic != null) {
    return arabic;
  }

  final fallback = fallbackArabicName.trim();
  if (fallback.isNotEmpty) {
    return fallback;
  }

  return quran.getSurahNameArabic(surahId);
}

String localizedSurahNameById(int surahId, {String? localeCode}) {
  return localizedSurahName(
    surahId: surahId,
    fallbackArabicName: surahId >= 1 && surahId <= quran.totalSurahCount
        ? quran.getSurahNameArabic(surahId)
        : '',
    localeCode: localeCode,
  );
}

int canonicalAyahCountForSurah(int surahId, {int? fallbackAyahCount}) {
  if (surahId >= 1 && surahId <= quran.totalSurahCount) {
    return quran.getVerseCount(surahId);
  }
  return fallbackAyahCount ?? 0;
}

int resolveCanonicalMushafPage({
  required int surahId,
  required int ayahNo,
  int? fallbackPage,
}) {
  if (surahId >= 1 && surahId <= quran.totalSurahCount && ayahNo > 0) {
    try {
      return quran.getPageNumber(surahId, ayahNo);
    } catch (_) {
      // Fall back to persisted page when the external payload is malformed.
    }
  }

  return fallbackPage ?? 0;
}