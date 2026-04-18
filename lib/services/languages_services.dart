import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../core/constants/api.dart';

class LanguageServices {
  Future<List<dynamic>?> fetchLanguages() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.endpoint('language-settings')),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['languages'] != null) {
          return data['languages'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching languages: $e');
      return null;
    }
  }
}
