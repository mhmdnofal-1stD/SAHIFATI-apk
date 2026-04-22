import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage {
  SecureSessionStorage._();

  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _activeAccountKey = 'active_session_account_key';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _accountAccessTokenKey(String accountKey) =>
      'accessToken:$accountKey';

  static String _accountRefreshTokenKey(String accountKey) =>
      'refreshToken:$accountKey';

  static Future<void> setActiveAccountKey(String? accountKey) async {
    if (accountKey == null || accountKey.isEmpty) {
      await _storage.delete(key: _activeAccountKey);
      return;
    }

    await _storage.write(key: _activeAccountKey, value: accountKey);
  }

  static Future<String?> readActiveAccountKey() {
    return _storage.read(key: _activeAccountKey);
  }

  static Future<void> writeAccountSessionTokens({
    required String accountKey,
    required String accessToken,
    String? refreshToken,
    bool setActive = true,
  }) async {
    await _storage.write(
      key: _accountAccessTokenKey(accountKey),
      value: accessToken,
    );

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(
        key: _accountRefreshTokenKey(accountKey),
        value: refreshToken,
      );
    } else {
      await _storage.delete(key: _accountRefreshTokenKey(accountKey));
    }

    if (setActive) {
      await setActiveAccountKey(accountKey);
    }
  }

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

  static Future<String?> readAccessToken({String? accountKey}) async {
    if (accountKey != null && accountKey.isNotEmpty) {
      final scopedToken =
          await _storage.read(key: _accountAccessTokenKey(accountKey));
      if (scopedToken != null && scopedToken.isNotEmpty) {
        return scopedToken;
      }
    }

    final activeAccountKey = await readActiveAccountKey();
    if (activeAccountKey != null && activeAccountKey.isNotEmpty) {
      final scopedToken =
          await _storage.read(key: _accountAccessTokenKey(activeAccountKey));
      if (scopedToken != null && scopedToken.isNotEmpty) {
        return scopedToken;
      }
    }

    return _storage.read(key: _accessTokenKey);
  }

  static Future<String?> readRefreshToken({String? accountKey}) async {
    if (accountKey != null && accountKey.isNotEmpty) {
      final scopedToken =
          await _storage.read(key: _accountRefreshTokenKey(accountKey));
      if (scopedToken != null && scopedToken.isNotEmpty) {
        return scopedToken;
      }
    }

    final activeAccountKey = await readActiveAccountKey();
    if (activeAccountKey != null && activeAccountKey.isNotEmpty) {
      final scopedToken =
          await _storage.read(key: _accountRefreshTokenKey(activeAccountKey));
      if (scopedToken != null && scopedToken.isNotEmpty) {
        return scopedToken;
      }
    }

    return _storage.read(key: _refreshTokenKey);
  }

  static Future<void> deleteAccountSessionTokens(String accountKey) async {
    await _storage.delete(key: _accountAccessTokenKey(accountKey));
    await _storage.delete(key: _accountRefreshTokenKey(accountKey));

    final activeAccountKey = await readActiveAccountKey();
    if (activeAccountKey == accountKey) {
      await setActiveAccountKey(null);
    }
  }

  static Future<void> clearSessionTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _activeAccountKey);
  }

  static Future<void> migrateLegacySessionToAccount(String accountKey) async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    await writeAccountSessionTokens(
      accountKey: accountKey,
      accessToken: accessToken,
      refreshToken: refreshToken,
      setActive: true,
    );

    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}