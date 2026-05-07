import 'package:flutter/material.dart';
import '../services/languages_services.dart';
import '../services/localization_service.dart';

class LanguageProvider with ChangeNotifier {
  LanguageProvider({String initialLangCode = 'ar'}) : langCode = initialLangCode;

  String langCode;
  
  List<dynamic> languages = [
    {"code": "ar", "name": "العربية"},
    {"code": "en", "name": "English"},
    {"code": "tr", "name": "Türkçe"}
  ];
  
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

    final fetched = await _services.fetchLanguages();
    if (fetched != null) {
      languages = fetched;
    }
    hasFetchedLanguages = true;
    
    isLoadingLanguages = false;
    notifyListeners();
  }
}
