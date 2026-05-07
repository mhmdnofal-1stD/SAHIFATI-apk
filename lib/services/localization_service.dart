import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayah_translation_library_service.dart';
import 'translation_library_service.dart';

class LocalizationService extends Translations {
  static const locale = Locale('ar', 'AE');
  static const fallbackLocale = Locale('ar', 'AE');

  static final languages = ['Arabic', 'English'];
  static final locales = [
    const Locale('ar', 'AE'),
    const Locale('en', 'US'),
  ];

  /// Locale codes that the app currently knows how to display. Each one is
  /// fetched and cached independently so a phone only needs network on first
  /// launch (or when the admin publishes a new version).
  static const List<String> supportedLanguageCodes = ['ar', 'en'];

  // Static maps to hold loaded translations
  static Map<String, String> arKeys = {};
  static Map<String, String> enKeys = {};

  Future<void> init() async {
    await AyahTranslationLibraryService.preload(
      languageCodes: AyahTranslationLibraryService.supportedLanguageCodes,
    );
    arKeys = await TranslationLibraryService.loadCachedOrSeed('ar');
    enKeys = await TranslationLibraryService.loadCachedOrSeed('en');
  }

  /// Pulls the latest translation bundles from the API in the background and
  /// updates the in-memory maps + UI when newer content arrives.
  ///
  /// Safe to call without `await` after `runApp`. Network failures are
  /// swallowed so the app keeps functioning offline with the cached/seed copy.
  static Future<void> refreshFromRemote() async {
    await TranslationLibraryService.refreshInBackground(
      languageCodes: supportedLanguageCodes,
      onUpdated: (languageCode, translations) {
        switch (languageCode) {
          case 'ar':
            arKeys = translations;
            break;
          case 'en':
            enKeys = translations;
            break;
          default:
            return;
        }

        // Force GetX to re-resolve translation keys so any visible screen picks
        // up the refreshed strings without requiring a manual app restart.
        Get.forceAppUpdate();
      },
    );
  }

  @override
  Map<String, Map<String, String>> get keys {
    return {
      'ar': arKeys,
      'ar_AE': arKeys,
      'en': enKeys,
      'en_US': enKeys,
    };
  }

  Future<void> changeLocale(String lang) async {
    final locale = _getLocaleFromLanguage(lang);
    await Get.updateLocale(locale);
    await _saveLocale(lang);
  }

  Future<void> changeLocaleByCode(String code) async {
    final newLocale = Locale(code);
    await Get.updateLocale(newLocale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
  }

  Locale _getLocaleFromLanguage(String lang) {
    for (int i = 0; i < languages.length; i++) {
      if (lang == languages[i]) return locales[i];
    }
    return Get.locale!;
  }

  static Future<void> _saveLocale(String lang) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', lang);
  }

  static Future<Locale> getCurrentLocale() async {
      final prefs = await SharedPreferences.getInstance();
      
      final langCode = prefs.getString('language_code');
      if (langCode != null && langCode.isNotEmpty) {
        return Locale(langCode);
      }

      final lang = prefs.getString('language') ?? 'Arabic';
      int index = languages.indexOf(lang);
      if(index == -1) return locale;
      return locales[index];
  }
}
