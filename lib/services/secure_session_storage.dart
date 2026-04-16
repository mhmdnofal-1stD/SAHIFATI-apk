import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage {
  SecureSessionStorage._();

  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> writeSessionTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }
  }

  static Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<void> clearSessionTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}