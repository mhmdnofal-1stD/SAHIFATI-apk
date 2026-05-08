import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../core/constants/api.dart';

class LanguageSettingsResponse {
  const LanguageSettingsResponse({
    required this.defaultLanguage,
    required this.languages,
  });

  final String defaultLanguage;
  final List<Map<String, String>> languages;
}

class LanguageServices {
  Future<LanguageSettingsResponse?> fetchLanguageSettings() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.endpoint('language-settings')),
      );
      if (response.statusCode != 200) {
        return null;
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

      return LanguageSettingsResponse(
        defaultLanguage: data['defaultLanguage']?.toString() ?? 'ar',
        languages: languages,
      );
    } catch (e) {
      debugPrint('Error fetching language settings: $e');
      return null;
    }
  }

  Future<List<dynamic>?> fetchLanguages() async {
    final settings = await fetchLanguageSettings();
    return settings?.languages;
  }
}
