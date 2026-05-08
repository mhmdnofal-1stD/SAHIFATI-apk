import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;

class AyahTranslationLibraryService {
  AyahTranslationLibraryService._();

  static const List<String> _packageBackedLanguageCodes = [
    'ar',
    'en',
    'tr',
    'ml',
    'fa',
    'fr',
    'it',
    'nl',
    'pt',
    'ru',
    'ur',
    'bn',
    'zh',
    'id',
    'es',
    'sv',
  ];

  static const List<String> _assetBackedLanguageCodes = [
    'de',
    'hi',
    'ms',
    'pa',
    'ha',
    'sw',
  ];

  static const List<String> supportedLanguageCodes = [
    ..._packageBackedLanguageCodes,
    ..._assetBackedLanguageCodes,
  ];

  static const String _assetManifestPath =
      'assets/json/ayah_translations/manifest.json';
  static const String _assetBundleDirectoryPath =
      'assets/json/ayah_translations';

  static final Map<String, Map<String, String>> _memoryCache =
      <String, Map<String, String>>{};
  static Future<Map<String, String>>? _assetManifestFuture;

  static bool supportsLanguage(String languageCode) {
    return supportedLanguageCodes
        .contains(_normalizeLanguageCode(languageCode));
  }

  static Future<void> preload({
    required Iterable<String> languageCodes,
  }) async {
    final normalizedCodes = languageCodes
        .map(_normalizeLanguageCode)
        .where((languageCode) => languageCode.isNotEmpty)
        .toList(growable: false);
    if (normalizedCodes.isEmpty) {
      return;
    }

    final preferredLanguageCode = normalizedCodes.reversed.firstWhere(
      (languageCode) => languageCode != 'ar',
      orElse: () => normalizedCodes.last,
    );

    await loadSeed(preferredLanguageCode);
  }

  static Future<Map<String, String>> loadSeed(String languageCode) async {
    final normalizedLanguageCode = _normalizeLanguageCode(languageCode);
    if (normalizedLanguageCode == 'ar' ||
        !supportsLanguage(normalizedLanguageCode)) {
      return const <String, String>{};
    }

    final cached = _memoryCache[normalizedLanguageCode];
    if (cached != null) {
      return cached;
    }

    final built = await _buildSeed(normalizedLanguageCode);
    _memoryCache[normalizedLanguageCode] = built;
    return built;
  }

  static String? lookup({
    required String languageCode,
    required int surahId,
    required int ayahNo,
  }) {
    final normalizedLanguageCode = _normalizeLanguageCode(languageCode);
    if (normalizedLanguageCode == 'ar') {
      return null;
    }

    final bundle = _memoryCache[normalizedLanguageCode];
    if (bundle == null || bundle.isEmpty) {
      return null;
    }

    final translation = bundle[translationKey(surahId, ayahNo)]?.trim() ?? '';
    return translation.isEmpty ? null : translation;
  }

  static String translationKey(int surahId, int ayahNo) {
    return 'ayah_translation_${surahId}_$ayahNo';
  }

  static String _normalizeLanguageCode(String languageCode) {
    final normalized = languageCode.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return 'ar';
    }

    return normalized.split('-').first;
  }

  static quran.Translation _translationForLanguageCode(String languageCode) {
    switch (_normalizeLanguageCode(languageCode)) {
      case 'tr':
        return quran.Translation.trSaheeh;
      case 'ml':
        return quran.Translation.mlAbdulHameed;
      case 'fa':
        return quran.Translation.faHusseinDari;
      case 'fr':
        return quran.Translation.frHamidullah;
      case 'it':
        return quran.Translation.itPiccardo;
      case 'nl':
        return quran.Translation.nlSiregar;
      case 'pt':
        return quran.Translation.portuguese;
      case 'ru':
        return quran.Translation.ruKuliev;
      case 'ur':
        return quran.Translation.urdu;
      case 'bn':
        return quran.Translation.bengali;
      case 'zh':
        return quran.Translation.chinese;
      case 'id':
        return quran.Translation.indonesian;
      case 'es':
        return quran.Translation.spanish;
      case 'sv':
        return quran.Translation.swedish;
      case 'en':
      default:
        return quran.Translation.enSaheeh;
    }
  }

  static Future<Map<String, String>> _buildSeed(String languageCode) async {
    final normalizedLanguageCode = _normalizeLanguageCode(languageCode);
    if (!supportsLanguage(normalizedLanguageCode) ||
        normalizedLanguageCode == 'ar') {
      return const <String, String>{};
    }

    if (_assetBackedLanguageCodes.contains(normalizedLanguageCode)) {
      return _loadAssetSeed(normalizedLanguageCode);
    }

    return _buildPackageSeed(normalizedLanguageCode);
  }

  static Map<String, String> _buildPackageSeed(String languageCode) {
    final translation = _translationForLanguageCode(languageCode);
    final bundle = <String, String>{};

    for (var surahId = 1; surahId <= quran.totalSurahCount; surahId++) {
      final verseCount = quran.getVerseCount(surahId);
      for (var ayahNo = 1; ayahNo <= verseCount; ayahNo++) {
        final value = quran
            .getVerseTranslation(
              surahId,
              ayahNo,
              verseEndSymbol: false,
              translation: translation,
            )
            .trim();
        if (value.isEmpty) {
          continue;
        }

        bundle[translationKey(surahId, ayahNo)] = value;
      }
    }

    return bundle;
  }

  static Future<Map<String, String>> _loadAssetSeed(String languageCode) async {
    final assetPath = await _resolveAssetBundlePath(languageCode);
    if (assetPath == null || assetPath.isEmpty) {
      return const <String, String>{};
    }

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <String, String>{};
      }

      final rawSurahs =
          decoded['surahs'] as List<dynamic>? ?? const <dynamic>[];
      final bundle = <String, String>{};

      for (final rawSurah in rawSurahs) {
        if (rawSurah is! List || rawSurah.length < 2) {
          continue;
        }

        final surahId = _parseInt(rawSurah[0]);
        final rawAyat = rawSurah[1];
        if (surahId == null || rawAyat is! List) {
          continue;
        }

        for (var ayahIndex = 0; ayahIndex < rawAyat.length; ayahIndex += 1) {
          final translation = rawAyat[ayahIndex]?.toString().trim() ?? '';
          if (translation.isEmpty) {
            continue;
          }

          bundle[translationKey(surahId, ayahIndex + 1)] = translation;
        }
      }

      return bundle;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static Future<String?> _resolveAssetBundlePath(String languageCode) async {
    final manifest = await _loadAssetManifest();
    final manifestPath = manifest[languageCode];
    if (manifestPath != null && manifestPath.isNotEmpty) {
      return manifestPath;
    }

    if (_assetBackedLanguageCodes.contains(languageCode)) {
      return '$_assetBundleDirectoryPath/$languageCode.json';
    }

    return null;
  }

  static Future<Map<String, String>> _loadAssetManifest() {
    final existing = _assetManifestFuture;
    if (existing != null) {
      return existing;
    }

    final future = _readAssetManifest();
    _assetManifestFuture = future;
    return future;
  }

  static Future<Map<String, String>> _readAssetManifest() async {
    try {
      final raw = await rootBundle.loadString(_assetManifestPath);
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <String, String>{};
      }

      final rawLanguages =
          decoded['languages'] as List<dynamic>? ?? const <dynamic>[];
      final manifest = <String, String>{};

      for (final rawEntry in rawLanguages) {
        if (rawEntry is! Map<String, dynamic>) {
          continue;
        }

        final languageCode =
            _normalizeLanguageCode(rawEntry['languageCode']?.toString() ?? '');
        final path = rawEntry['path']?.toString().trim() ?? '';
        if (languageCode.isEmpty || path.isEmpty) {
          continue;
        }

        manifest[languageCode] = path;
      }

      return manifest;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse('$value');
  }
}
