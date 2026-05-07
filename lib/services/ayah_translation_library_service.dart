import 'package:quran/quran.dart' as quran;

class AyahTranslationLibraryService {
  AyahTranslationLibraryService._();

  static const List<String> supportedLanguageCodes = [
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

  static final Map<String, Map<String, String>> _memoryCache =
      <String, Map<String, String>>{};

  static bool supportsLanguage(String languageCode) {
    return supportedLanguageCodes.contains(_normalizeLanguageCode(languageCode));
  }

  static Future<void> preload({
    required Iterable<String> languageCodes,
  }) async {
    for (final languageCode in languageCodes) {
      await loadSeed(languageCode);
    }
  }

  static Future<Map<String, String>> loadSeed(String languageCode) async {
    final normalizedLanguageCode = _normalizeLanguageCode(languageCode);
    if (!supportsLanguage(normalizedLanguageCode)) {
      return const <String, String>{};
    }

    final cached = _memoryCache[normalizedLanguageCode];
    if (cached != null) {
      return cached;
    }

    final built = _buildSeed(normalizedLanguageCode);
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

  static Map<String, String> _buildSeed(String languageCode) {
    final normalizedLanguageCode = _normalizeLanguageCode(languageCode);
    if (!supportsLanguage(normalizedLanguageCode) ||
        normalizedLanguageCode == 'ar') {
      return const <String, String>{};
    }

    final translation = _translationForLanguageCode(normalizedLanguageCode);
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
}