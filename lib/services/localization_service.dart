import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayah_translation_library_service.dart';
import 'translation_library_service.dart';

class LocalizationService extends Translations {
  static const locale = Locale('ar', 'AE');
  static const fallbackLocale = Locale('ar', 'AE');
  static const Duration _prefsTimeout = Duration(seconds: 2);

  static final Map<String, Map<String, String>> _rawBundles =
      <String, Map<String, String>>{};
  static final Set<String> _warmingAyahLanguageCodes = <String>{};

  Future<void> init() async {
    final currentLocale = await getCurrentLocale();
    await _ensureLanguageLoaded('ar');
    await _ensureLanguageLoaded(currentLocale.languageCode);
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
    final normalizedCode = _normalizeLanguageCode(code);
    await _ensureLanguageLoaded(normalizedCode);

    final newLocale = Locale(normalizedCode);
    await Get.updateLocale(newLocale);
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      await prefs.setString('language_code', normalizedCode);
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

  static void _warmAyahTranslations(String languageCode) {
    final normalizedCode = _normalizeLanguageCode(languageCode);
    if (normalizedCode == 'ar' ||
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
        await prefs.setString('language', lang);
      } on TimeoutException {
        debugPrint('LocalizationService: timed out persisting legacy language=$lang');
      }
  }

  static Future<Locale> getCurrentLocale() async {
      try {
        final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);

        final langCode = prefs.getString('language_code');
        if (langCode != null && langCode.isNotEmpty) {
          return Locale(_normalizeLanguageCode(langCode));
        }

        final lang = prefs.getString('language') ?? 'Arabic';
        return switch (lang.trim().toLowerCase()) {
          'english' => const Locale('en', 'US'),
          'arabic' => const Locale('ar', 'AE'),
          _ => locale,
        };
      } on TimeoutException {
        debugPrint('LocalizationService: timed out reading saved locale');
        return locale;
      }
  }
}
