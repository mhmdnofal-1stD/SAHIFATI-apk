import 'package:flutter/material.dart';
import '../services/languages_services.dart';
import '../services/localization_service.dart';

class LanguageProvider with ChangeNotifier {
  LanguageProvider({String initialLangCode = 'ar'}) : langCode = initialLangCode;

  String langCode;

  List<Map<String, String>> languages = const <Map<String, String>>[];
  
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
        final code = language['code']?.toString() ?? '';
        return LocalizationService.supportsUiLanguage(code);
      }).toList(growable: false);

      if (filtered.isNotEmpty) {
        languages = filtered;
        await LocalizationService.updateEnabledUiLanguages(
          defaultLanguage: settings.defaultLanguage,
          languages: filtered,
        );
      } else {
        final cachedLanguages = await LocalizationService.getEnabledUiLanguages();
        languages = cachedLanguages;
      }
    } else {
      final cachedLanguages = await LocalizationService.getEnabledUiLanguages();
      languages = cachedLanguages;
    }
    hasFetchedLanguages = true;
    
    isLoadingLanguages = false;
    notifyListeners();
  }
}
