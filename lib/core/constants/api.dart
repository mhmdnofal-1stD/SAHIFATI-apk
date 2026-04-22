class ApiConfig {
  static const String _compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sahifati.org/api',
  );

  static String get baseUrl {
    final normalized = _compileTimeBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
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