import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../core/constants/api.dart';
import 'app_exception.dart';
import 'secure_session_storage.dart';

class SahifatyApi {
  final String _baseURL = '${ApiConfig.baseUrl}/';
  final Duration _timeout = const Duration(seconds: 30);

  static void _logWeb401(String message) {
    debugPrint('[web401] $message');
  }

  // Coalesces concurrent 401 refresh attempts: all callers share the same
  // in-flight future so the refresh token is only used once.
  static Future<bool>? _pendingRefresh;

  static Future<bool> _tryRefreshTokens() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  /// Attempts to exchange the stored refresh token for a new token pair.
  ///
  /// Returns **true** when tokens are refreshed successfully.
  /// Returns **false** when the server explicitly rejects the refresh token
  /// (HTTP 401 / 403) — callers should treat this as a definitive auth
  /// failure and expire the session.
  /// **Throws** [FetchDataException] on network / connectivity / server
  /// errors — callers must NOT expire the session in this case because the
  /// failure is transient and the stored tokens may still be valid.
  static Future<bool> _doRefresh() async {
    _logWeb401('refresh-start');
    final refreshToken = await SecureSessionStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      _logWeb401('refresh-missing-token');
      return false;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/refresh');
    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'accept': '*/*'},
        body: json.encode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 30));
    } on http.ClientException {
      throw FetchDataException('service_api_no_internet'.tr);
    } on TimeoutException {
      throw FetchDataException('service_api_no_internet'.tr);
    }

    _logWeb401('refresh-response status=${response.statusCode}');

    if (response.statusCode == 401 || response.statusCode == 403) {
      // Server definitively rejected the refresh token.
      return false;
    }
    if (response.statusCode != 200) {
      // Server-side error (5xx etc.) — treat as transient, keep session.
      if (kDebugMode) {
        debugPrint('Token refresh returned ${response.statusCode} — treating as transient');
      }
      throw FetchDataException('service_api_no_internet'.tr);
    }

    final data = json.decode(response.body);
    final newAccessToken =
        data is Map ? data['accessToken'] as String? : null;
    final newRefreshToken =
        data is Map ? data['refreshToken'] as String? : null;
    if (newAccessToken == null || newAccessToken.isEmpty) return false;

    final accountKey = await SecureSessionStorage.readActiveAccountKey();
    if (accountKey == null || accountKey.isEmpty) return false;

    await SecureSessionStorage.writeAccountSessionTokens(
      accountKey: accountKey,
      accessToken: newAccessToken,
      refreshToken: newRefreshToken ?? refreshToken,
    );
    _logWeb401('refresh-success');
    return true;
  }

  static Future<String> _resolveBearerToken() async {
    final accessToken = await SecureSessionStorage.readAccessToken();
    if (SecureSessionStorage.isAccessTokenUsable(accessToken)) {
      return accessToken ?? '';
    }

    final refreshed = await _tryRefreshTokens();
    if (!refreshed) {
      return '';
    }

    return await SecureSessionStorage.readAccessToken() ?? '';
  }

  // Get headers with token
  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    if (!auth) return {'Content-Type': 'application/json'};

    final token = await _resolveBearerToken();

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'accept': '*/*'
    };
  }

  // Generic request handler
  Future<dynamic> _request(
    String url, {
    String method = 'GET',
    dynamic body,
    bool auth = true,
    bool isRetry = false,
  }) async {
    try {
      _logWeb401(
        'request method=$method url=$url auth=$auth isRetry=$isRetry route=${Get.currentRoute}',
      );
      final headers = await _getHeaders(auth: auth);
      http.Response response;

      final uri = Uri.parse(_baseURL + url);

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw Exception(
            'service_api_unsupported_http_method'.trParams({
              'method': method,
            }),
          );
      }

      // Intercept 401: attempt a silent token refresh, then retry once.
      // Not triggered for unauthenticated requests or the retry itself.
      if (response.statusCode == 401 && auth && !isRetry) {
        _logWeb401(
          '401-before-refresh method=$method url=$url auth=$auth isRetry=$isRetry route=${Get.currentRoute}',
        );
        bool refreshed;
        try {
          refreshed = await _tryRefreshTokens();
        } catch (_) {
          // Network / transient error during refresh — the stored session is
          // still intact.  Propagate as a network error so the UI can show a
          // retry prompt instead of forcing the user back to the login screen.
          throw FetchDataException('service_api_no_internet'.tr);
        }
        _logWeb401(
          '401-refresh-result url=$url refreshed=$refreshed route=${Get.currentRoute}',
        );
        if (refreshed) {
          return _request(
            url,
            method: method,
            body: body,
            auth: auth,
            isRetry: true,
          );
        }
        // Refresh token definitively rejected by the server: expire the
        // active session fully and redirect to re-authentication.
        _logWeb401(
          'redirect-select-user url=$url route=${Get.currentRoute}',
        );
        await SecureSessionStorage.expireActiveSession();
        Get.offAllNamed('/select-user');
        throw Exception('service_api_unauthorized'.tr);
      }

      return response;
    } on http.ClientException {
      throw FetchDataException('service_api_no_internet'.tr);
    } catch (e) {
      rethrow;
    }
  }

  // Public methods
  Future<dynamic> get(String url) => _request(url, method: 'GET');

  Future<dynamic> fetch(Uri uri) async {
    try {
      final response = await http
          .get(uri, headers: await _getHeaders(auth: false))
          .timeout(_timeout);
      return processedResponse(response);
    } on http.ClientException {
      throw FetchDataException('service_api_no_internet'.tr);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post({required String url, required dynamic body}) =>
      _request(url, method: 'POST', body: body);

  Future<dynamic> put({required String url, required dynamic body}) =>
      _request(url, method: 'PUT', body: body);

  Future<dynamic> patch({required String url, required dynamic body}) =>
      _request(url, method: 'PATCH', body: body);

  Future<dynamic> delete(String url) => _request(url, method: 'DELETE');

  // Response handler
  dynamic processedResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return json.decode(response.body);
      case 400:
        throw Exception('service_api_bad_request'.tr);
      case 401:
        throw Exception('service_api_unauthorized'.tr);
      case 403:
        throw Exception('service_api_forbidden'.tr);
      case 404:
        throw Exception('service_api_not_found'.tr);
      case 422:
        throw Exception('service_api_validation_error'.tr);
      case 500:
        throw Exception('service_api_server_error'.tr);
      case 503:
        throw Exception('service_api_unavailable'.tr);
      default:
        throw Exception(
          'service_api_unexpected_status'.trParams({
            'statusCode': response.statusCode.toString(),
          }),
        );
    }
  }
}
