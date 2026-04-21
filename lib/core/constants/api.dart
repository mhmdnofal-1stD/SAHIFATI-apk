class ApiConfig {
  static const String _compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sahifati.org',
  );

  static String get baseUrl => _compileTimeBaseUrl;

  static String endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$normalizedPath';
  }
}