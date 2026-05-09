import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api.dart';
import 'ayah_translation_library_service.dart';
import 'translation_library_service.dart';

class LocalizationService extends Translations {
  static const locale = Locale('ar', 'AE');
  static const fallbackLocale = Locale('ar', 'AE');
  static const Duration _prefsTimeout = Duration(seconds: 2);
  static const String _languageCodePrefsKey = 'language_code';
  static const String _legacyLanguagePrefsKey = 'language';
  static const String _enabledUiLanguageCodesPrefsKey =
      'enabled_ui_language_codes';
  static const String _enabledUiDefaultLanguagePrefsKey =
      'enabled_ui_default_language';
  static const String _enabledUiLanguagesPrefsKey =
      'enabled_ui_languages';
  static const String _recentLanguageCodesPrefsKey =
      'recent_language_codes';
  static const int _maxRecentLanguageCodes = 2;

  static final Map<String, Map<String, String>> _rawBundles =
      <String, Map<String, String>>{};
  static final Set<String> _warmingAyahLanguageCodes = <String>{};
  @visibleForTesting
  static bool debugDisableAyahWarmup = false;

  Future<void> init() async {
    await refreshEnabledUiLanguagesFromRemote();
    final currentLocale = await getCurrentLocale();
    await _restoreBundleWindow(currentLocale.languageCode);
  }

  static Future<void> refreshEnabledUiLanguagesFromRemote() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.endpoint('language-settings')))
          .timeout(_prefsTimeout);
      if (response.statusCode != 200) {
        return;
      }

      final data = json.decode(response.body);
      final rawLanguages = data['languages'];
      final languages = rawLanguages is List
          ? rawLanguages
              .whereType<Map>()
              .map(
                (language) => Map<String, String>.from(
                  language.map(
                    (key, value) =>
                        MapEntry(key.toString(), value?.toString() ?? ''),
                  ),
                ),
              )
              .toList(growable: false)
          : const <Map<String, String>>[];

      await updateEnabledUiLanguages(
        defaultLanguage: data['defaultLanguage']?.toString() ?? locale.languageCode,
        languages: languages,
      );
    } on TimeoutException {
      debugPrint('LocalizationService: timed out refreshing enabled languages');
    } catch (error) {
      debugPrint('LocalizationService: failed to refresh enabled languages: $error');
    }
  }

  static Future<void> updateEnabledUiLanguages({
    required String defaultLanguage,
    required List<Map<String, String>> languages,
  }) async {
    final normalizedLanguages = <Map<String, String>>[];
    final normalizedCodes = <String>[];

    for (final language in languages) {
      final normalizedCode = _normalizeLanguageCode(language['code'] ?? '');
      final normalizedName = (language['name'] ?? '').toString().trim();
      if (
        !supportsUiLanguage(normalizedCode) ||
        normalizedCodes.contains(normalizedCode) ||
        normalizedName.isEmpty
      ) {
        continue;
      }

      normalizedLanguages.add(<String, String>{
        'code': normalizedCode,
        'name': normalizedName,
      });
      normalizedCodes.add(normalizedCode);
    }

    if (normalizedCodes.isEmpty) {
      normalizedCodes.add(locale.languageCode);
      normalizedLanguages.add(const <String, String>{
        'code': 'ar',
        'name': 'العربية',
      });
    }

    final normalizedDefaultLanguage =
        _normalizeLanguageCode(defaultLanguage);
    final persistedDefaultLanguage = normalizedCodes.contains(normalizedDefaultLanguage)
        ? normalizedDefaultLanguage
        : normalizedCodes.first;

    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      await prefs.setStringList(_enabledUiLanguageCodesPrefsKey, normalizedCodes);
      await prefs.setString(
        _enabledUiDefaultLanguagePrefsKey,
        persistedDefaultLanguage,
      );
      await prefs.setString(
        _enabledUiLanguagesPrefsKey,
        json.encode(normalizedLanguages),
      );
    } on TimeoutException {
      debugPrint('LocalizationService: timed out persisting enabled languages');
    }
  }

  /// Pulls the latest translation bundles from the API in the background and
  /// updates the in-memory maps + UI when newer content arrives.
  ///
  /// Safe to call without `await` after `runApp`. Network failures are
  /// swallowed so the app keeps functioning offline with the cached/seed copy.
  static Future<void> refreshFromRemote() async {
    final languageCodes = _loadedLanguageCodes();
    await TranslationLibraryService.refreshInBackground(
      languageCodes: languageCodes,
      onUpdated: (languageCode, translations) {
        _rawBundles[_normalizeLanguageCode(languageCode)] = translations;

        // Force GetX to re-resolve translation keys so any visible screen picks
        // up the refreshed strings without requiring a manual app restart.
        Get.forceAppUpdate();
      },
    );
  }

  @override
  Map<String, Map<String, String>> get keys {
    final resolved = <String, Map<String, String>>{};

    for (final entry in _rawBundles.entries) {
      final languageCode = entry.key;
      final bundle = _effectiveBundleFor(languageCode);
      resolved[languageCode] = bundle;

      for (final alias in _localeAliasesForLanguageCode(languageCode)) {
        resolved[alias] = bundle;
      }
    }

    final arabicBundle = _effectiveBundleFor('ar');
    resolved.putIfAbsent('ar', () => arabicBundle);
    resolved.putIfAbsent('ar_AE', () => arabicBundle);

    return resolved;
  }

  Future<void> changeLocale(String lang) async {
    await changeLocaleByCode(_legacyLanguageNameToCode(lang));
    await _saveLocale(lang);
  }

  Future<void> changeLocaleByCode(String code) async {
    final normalizedCode = await _resolveEnabledUiLanguageCode(code);
    final previousCode = _normalizeLanguageCode(Get.locale?.languageCode ?? '');

    await _ensureLanguageLoaded(normalizedCode);
    await _retainBundleWindow(
      currentLanguageCode: normalizedCode,
      previousLanguageCode: previousCode,
    );

    final newLocale = Locale(normalizedCode);
    await Get.updateLocale(newLocale);
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      await prefs.setString(_languageCodePrefsKey, normalizedCode);
    } on TimeoutException {
      debugPrint(
        'LocalizationService: timed out persisting language_code=$normalizedCode',
      );
    }
  }

  static String _normalizeLanguageCode(String code) {
    final normalized = code.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return 'ar';
    }

    return normalized.split('-').first;
  }

  static bool supportsUiLanguage(String code) {
    return code.trim().isNotEmpty;
  }

  static Future<List<Map<String, String>>> getEnabledUiLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final raw = prefs.getString(_enabledUiLanguagesPrefsKey);
      if (raw == null || raw.isEmpty) {
        return const <Map<String, String>>[];
      }

      final decoded = json.decode(raw);
      if (decoded is! List) {
        return const <Map<String, String>>[];
      }

      final languages = <Map<String, String>>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final code = _normalizeLanguageCode(item['code']?.toString() ?? '');
        final name = item['name']?.toString().trim() ?? '';
        if (code.isEmpty || name.isEmpty) {
          continue;
        }

        languages.add(<String, String>{'code': code, 'name': name});
      }

      return languages;
    } on TimeoutException {
      debugPrint('LocalizationService: timed out reading enabled languages');
      return const <Map<String, String>>[];
    } catch (error) {
      debugPrint('LocalizationService: failed to decode enabled languages: $error');
      return const <Map<String, String>>[];
    }
  }

  static Future<List<String>> _readEnabledUiLanguageCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final storedCodes =
          prefs.getStringList(_enabledUiLanguageCodesPrefsKey) ?? const <String>[];
      final normalizedCodes = <String>[];

      for (final languageCode in storedCodes) {
        final normalizedCode = _normalizeLanguageCode(languageCode);
        if (
          normalizedCode.isEmpty ||
          !supportsUiLanguage(normalizedCode) ||
          normalizedCodes.contains(normalizedCode)
        ) {
          continue;
        }
        normalizedCodes.add(normalizedCode);
      }

      return normalizedCodes.isNotEmpty
          ? normalizedCodes
          : <String>[locale.languageCode];
    } on TimeoutException {
      debugPrint('LocalizationService: timed out reading enabled languages');
      return <String>[locale.languageCode];
    }
  }

  static Future<String> _readEnabledUiDefaultLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final storedDefault = _normalizeLanguageCode(
        prefs.getString(_enabledUiDefaultLanguagePrefsKey) ?? '',
      );
      final enabledCodes = await _readEnabledUiLanguageCodes();
      return enabledCodes.contains(storedDefault)
          ? storedDefault
          : enabledCodes.first;
    } on TimeoutException {
      debugPrint('LocalizationService: timed out reading enabled default language');
      return locale.languageCode;
    }
  }

  static Future<String> _resolveEnabledUiLanguageCode(String code) async {
    final normalizedCode = _normalizeLanguageCode(code);
    final enabledCodes = await _readEnabledUiLanguageCodes();
    if (enabledCodes.contains(normalizedCode)) {
      return normalizedCode;
    }

    return _readEnabledUiDefaultLanguage();
  }

  static String _resolveSupportedUiLanguageCode(String code) {
    final normalizedCode = _normalizeLanguageCode(code);
    if (supportsUiLanguage(normalizedCode)) {
      return normalizedCode;
    }

    return locale.languageCode;
  }

  static Future<void> _ensureLanguageLoaded(String languageCode) async {
    final normalizedCode = _normalizeLanguageCode(languageCode);

    if (!_rawBundles.containsKey('ar')) {
      _rawBundles['ar'] = await TranslationLibraryService.loadCachedOrSeed(
        'ar',
        includeAyahSeed: false,
      );
    }

    if (normalizedCode == 'ar' || _rawBundles.containsKey(normalizedCode)) {
      _warmAyahTranslations(normalizedCode);
      return;
    }

    _rawBundles[normalizedCode] = await TranslationLibraryService.loadCachedOrSeed(
      normalizedCode,
      includeAyahSeed: false,
    );
    _warmAyahTranslations(normalizedCode);
  }

  static Future<void> _restoreBundleWindow(String currentLanguageCode) async {
    final normalizedCurrentCode =
        _resolveSupportedUiLanguageCode(currentLanguageCode);
    await _ensureLanguageLoaded('ar');
    await _ensureLanguageLoaded(normalizedCurrentCode);

    for (final languageCode in await _readRecentLanguageCodes()) {
      await _ensureLanguageLoaded(languageCode);
    }

    _pruneLoadedBundles(
      _retainedLanguageCodes(
        currentLanguageCode: normalizedCurrentCode,
        recentLanguageCodes: await _readRecentLanguageCodes(),
      ),
    );
  }

  static Future<void> _retainBundleWindow({
    required String currentLanguageCode,
    required String previousLanguageCode,
  }) async {
    final recentLanguageCodes = await _buildRecentLanguageCodes(
      currentLanguageCode: currentLanguageCode,
      previousLanguageCode: previousLanguageCode,
    );

    for (final languageCode in recentLanguageCodes) {
      await _ensureLanguageLoaded(languageCode);
    }

    _pruneLoadedBundles(
      _retainedLanguageCodes(
        currentLanguageCode: currentLanguageCode,
        recentLanguageCodes: recentLanguageCodes,
      ),
    );
    await _writeRecentLanguageCodes(recentLanguageCodes);
  }

  static Set<String> _retainedLanguageCodes({
    required String currentLanguageCode,
    required Iterable<String> recentLanguageCodes,
  }) {
    return <String>{
      'ar',
      _normalizeLanguageCode(currentLanguageCode),
      ...recentLanguageCodes.map(_normalizeLanguageCode),
    };
  }

  static void _pruneLoadedBundles(Set<String> retainedLanguageCodes) {
    _rawBundles.removeWhere(
      (languageCode, _) => !retainedLanguageCodes.contains(languageCode),
    );
  }

  static Future<List<String>> _buildRecentLanguageCodes({
    required String currentLanguageCode,
    required String previousLanguageCode,
  }) async {
    final normalizedCurrentCode = _normalizeLanguageCode(currentLanguageCode);
    final normalizedPreviousCode = _normalizeLanguageCode(previousLanguageCode);
    final existingRecentLanguageCodes = await _readRecentLanguageCodes();
    final nextRecentLanguageCodes = <String>[];

    void push(String languageCode) {
      final normalizedCode = _resolveSupportedUiLanguageCode(languageCode);
      if (normalizedCode.isEmpty ||
          normalizedCode == 'ar' ||
          normalizedCode == normalizedCurrentCode ||
          nextRecentLanguageCodes.contains(normalizedCode)) {
        return;
      }
      nextRecentLanguageCodes.add(normalizedCode);
    }

    push(normalizedPreviousCode);
    for (final languageCode in existingRecentLanguageCodes) {
      push(languageCode);
      if (nextRecentLanguageCodes.length >= _maxRecentLanguageCodes) {
        break;
      }
    }

    if (nextRecentLanguageCodes.length > _maxRecentLanguageCodes) {
      return nextRecentLanguageCodes.sublist(0, _maxRecentLanguageCodes);
    }

    return nextRecentLanguageCodes;
  }

  static Future<List<String>> _readRecentLanguageCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final storedCodes =
          prefs.getStringList(_recentLanguageCodesPrefsKey) ?? const <String>[];
      final normalizedCodes = <String>[];

      for (final languageCode in storedCodes) {
        final normalizedCode = _normalizeLanguageCode(languageCode);
        if (normalizedCode.isEmpty ||
            normalizedCode == 'ar' ||
            !supportsUiLanguage(normalizedCode) ||
            normalizedCodes.contains(normalizedCode)) {
          continue;
        }
        normalizedCodes.add(normalizedCode);
        if (normalizedCodes.length >= _maxRecentLanguageCodes) {
          break;
        }
      }

      return normalizedCodes;
    } on TimeoutException {
      debugPrint('LocalizationService: timed out reading recent language codes');
      return const <String>[];
    }
  }

  static Future<void> _writeRecentLanguageCodes(List<String> languageCodes) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      await prefs.setStringList(_recentLanguageCodesPrefsKey, languageCodes);
    } on TimeoutException {
      debugPrint('LocalizationService: timed out persisting recent language codes');
    }
  }

  static void _warmAyahTranslations(String languageCode) {
    final normalizedCode = _normalizeLanguageCode(languageCode);
    if (debugDisableAyahWarmup ||
        normalizedCode == 'ar' ||
        !AyahTranslationLibraryService.supportsLanguage(normalizedCode) ||
        _warmingAyahLanguageCodes.contains(normalizedCode)) {
      return;
    }

    _warmingAyahLanguageCodes.add(normalizedCode);
    unawaited(
      AyahTranslationLibraryService.preload(
        languageCodes: [normalizedCode],
      ).whenComplete(() {
        _warmingAyahLanguageCodes.remove(normalizedCode);
      }),
    );
  }

  static List<String> _loadedLanguageCodes() {
    final loaded = _rawBundles.keys.toSet();
    loaded.add('ar');

    final sorted = loaded.toList()..sort();
    sorted.remove('ar');
    return ['ar', ...sorted];
  }

  static Map<String, String> _effectiveBundleFor(String languageCode) {
    final normalizedCode = _normalizeLanguageCode(languageCode);
    final bundle = _rawBundles[normalizedCode] ?? const <String, String>{};
    if (normalizedCode == 'ar') {
      return bundle;
    }

    final arabicBundle = _rawBundles['ar'] ?? const <String, String>{};
    if (arabicBundle.isEmpty) {
      return bundle;
    }

    return <String, String>{...arabicBundle, ...bundle};
  }

  static List<String> _localeAliasesForLanguageCode(String languageCode) {
    switch (_normalizeLanguageCode(languageCode)) {
      case 'ar':
        return const ['ar_AE'];
      case 'en':
        return const ['en_US'];
      default:
        return const [];
    }
  }

  String _legacyLanguageNameToCode(String lang) {
    switch (lang.trim().toLowerCase()) {
      case 'english':
        return 'en';
      case 'arabic':
      default:
        return 'ar';
    }
  }

  static Future<void> _saveLocale(String lang) async {
      try {
        final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
        await prefs.setString(_legacyLanguagePrefsKey, lang);
      } on TimeoutException {
        debugPrint('LocalizationService: timed out persisting legacy language=$lang');
      }
  }

  static Future<Locale> getCurrentLocale() async {
      try {
        final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
        final enabledCodes = await _readEnabledUiLanguageCodes();
        final enabledDefaultLanguage = await _readEnabledUiDefaultLanguage();

        final langCode = prefs.getString(_languageCodePrefsKey);
        if (langCode != null && langCode.isNotEmpty) {
          final normalizedCode = _normalizeLanguageCode(langCode);
          return Locale(
            enabledCodes.contains(normalizedCode)
                ? normalizedCode
                : enabledDefaultLanguage,
          );
        }

        final lang = prefs.getString(_legacyLanguagePrefsKey) ?? 'Arabic';
        final legacyLocale = switch (lang.trim().toLowerCase()) {
          'english' => 'en',
          'arabic' => 'ar',
          _ => locale.languageCode,
        };
        return Locale(
          enabledCodes.contains(legacyLocale)
              ? legacyLocale
              : enabledDefaultLanguage,
        );
      } on TimeoutException {
        debugPrint('LocalizationService: timed out reading saved locale');
        return locale;
      }
  }

  @visibleForTesting
  static List<String> debugLoadedLanguageCodes() => _loadedLanguageCodes();

  @visibleForTesting
  static Future<List<String>> debugRecentLanguageCodes() =>
      _readRecentLanguageCodes();

  @visibleForTesting
  static Future<void> debugApplyBundleWindow({
    required String currentLanguageCode,
    required String previousLanguageCode,
  }) async {
    await _ensureLanguageLoaded(currentLanguageCode);
    await _retainBundleWindow(
      currentLanguageCode: currentLanguageCode,
      previousLanguageCode: previousLanguageCode,
    );
  }

  @visibleForTesting
  static void debugResetState() {
    _rawBundles.clear();
    _warmingAyahLanguageCodes.clear();
    debugDisableAyahWarmup = false;
  }
}
