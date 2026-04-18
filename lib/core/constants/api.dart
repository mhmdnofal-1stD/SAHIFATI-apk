class ApiConfig {
  static const String _compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl =>
      _compileTimeBaseUrl.isNotEmpty ? _compileTimeBaseUrl : 'http://127.0.0.1:3067';

  static String endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$normalizedPath';
  }
}