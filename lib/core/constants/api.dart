class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:3067';

  static String endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$normalizedPath';
  }
}