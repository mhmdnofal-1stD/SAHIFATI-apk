import 'package:flutter/material.dart';
import '../services/languages_services.dart';
import '../services/localization_service.dart';

class LanguageProvider with ChangeNotifier {
  LanguageProvider({String initialLangCode = 'ar'}) : langCode = initialLangCode;

  String langCode;
  
  static const List<Map<String, String>> _defaultLanguages = [
    {"code": "ar", "name": "العربية"},
    {"code": "en", "name": "English"},
    {"code": "tr", "name": "Türkçe"},
    {"code": "id", "name": "Bahasa Indonesia"},
    {"code": "hi", "name": "हिन्दी"},
    {"code": "ur", "name": "اردو"},
    {"code": "fa", "name": "فارسی"},
    {"code": "bn", "name": "বাংলা"},
    {"code": "ms", "name": "Bahasa Melayu"},
    {"code": "de", "name": "Deutsch"},
    {"code": "pa", "name": "ਪੰਜਾਬੀ"},
    {"code": "sw", "name": "Kiswahili"}
  ];

  List<dynamic> languages = List<Map<String, String>>.from(_defaultLanguages);
  
  bool isLoadingLanguages = false;
  bool hasFetchedLanguages = false;
  final LanguageServices _services = LanguageServices();

  void setLangCode(String code) {
    if (langCode == code) {
      return;
    }
    langCode = code;
    notifyListeners();
  }

  Future<void> hydrateFromStoredLocale() async {
    final locale = await LocalizationService.getCurrentLocale();
    setLangCode(locale.languageCode);
  }

  Future<void> changeLanguage(String code) async {
    setLangCode(code);
    await LocalizationService().changeLocaleByCode(code);
  }

  Future<void> fetchLanguages() async {
    isLoadingLanguages = true;
    notifyListeners();

    final settings = await _services.fetchLanguageSettings();
    if (settings != null) {
      final filtered = settings.languages.where((language) {
        if (language is! Map) {
          return false;
        }

        final code = language['code']?.toString() ?? '';
        return LocalizationService.supportsUiLanguage(code);
      }).map((language) {
        return Map<String, String>.from(
          (language as Map).map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ),
        );
      }).toList(growable: false);

      if (filtered.isNotEmpty) {
        languages = filtered;
        await LocalizationService.updateEnabledUiLanguages(
          defaultLanguage: settings.defaultLanguage,
          languages: filtered,
        );
      } else {
        final cachedLanguages = await LocalizationService.getEnabledUiLanguages();
        languages = cachedLanguages.isNotEmpty
            ? cachedLanguages
            : List<Map<String, String>>.from(_defaultLanguages);
      }
    } else {
      final cachedLanguages = await LocalizationService.getEnabledUiLanguages();
      languages = cachedLanguages.isNotEmpty
          ? cachedLanguages
          : List<Map<String, String>>.from(_defaultLanguages);
    }
    hasFetchedLanguages = true;
    
    isLoadingLanguages = false;
    notifyListeners();
  }
}
