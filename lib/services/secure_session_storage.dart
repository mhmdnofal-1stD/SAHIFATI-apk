import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureSessionStorage {
  SecureSessionStorage._();

  static const Duration _defaultTokenExpirySkew = Duration(seconds: 90);

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

  static bool isAccessTokenUsable(
    String? token, {
    Duration expirySkew = _defaultTokenExpirySkew,
  }) {
    if (token == null || token.isEmpty) {
      return false;
    }

    final parts = token.split('.');
    if (parts.length != 3) {
      return false;
    }

    try {
      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final payload = json.decode(payloadJson);
      if (payload is! Map) {
        return false;
      }

      final expRaw = payload['exp'];
      final exp = expRaw is int
          ? expRaw
          : expRaw is num
              ? expRaw.toInt()
              : int.tryParse(expRaw?.toString() ?? '');
      if (exp == null) {
        return false;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiresAt.isAfter(DateTime.now().add(expirySkew));
    } catch (_) {
      return false;
    }
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

  /// Fully expires the active account's session: removes tokens from secure
  /// storage AND removes the session record from SharedPreferences so the
  /// SelectUserScreen reflects the expired state immediately without waiting
  /// for the user to tap "instant login" and silently fail.
  static Future<void> expireActiveSession() async {
    final accountKey = await readActiveAccountKey();
    if (accountKey == null || accountKey.isEmpty) return;

    // 1. Remove tokens from secure storage.
    await deleteAccountSessionTokens(accountKey);

    // 2. Remove the session record from SharedPreferences.
    const sessionsKey = 'stored_account_sessions';
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(sessionsKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = json.decode(rawJson);
        if (decoded is Map) {
          final sessions = Map<String, dynamic>.from(decoded);
          sessions.remove(accountKey);
          if (sessions.isEmpty) {
            await prefs.remove(sessionsKey);
          } else {
            await prefs.setString(sessionsKey, json.encode(sessions));
          }
        }
      } catch (_) {
        // Malformed JSON — remove entirely to avoid a permanently broken state.
        await prefs.remove(sessionsKey);
      }
    }
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