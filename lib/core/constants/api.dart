import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sahifati.org/api',
  );

  static String _resolveDefaultBaseUrl() {
    if (!kIsWeb) {
      return _compileTimeBaseUrl;
    }

    final host = Uri.base.host.trim().toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') {
      return 'http://127.0.0.1:3077/api';
    }

    return _compileTimeBaseUrl;
  }

  static String get baseUrl {
    final normalized = _resolveDefaultBaseUrl()
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/api')) {
      return normalized;
    }

    return '$normalized/api';
  }

  static String endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$normalizedPath';
  }
}