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

  // Coalesces concurrent 401 refresh attempts: all callers share the same
  // in-flight future so the refresh token is only used once.
  static Future<bool>? _pendingRefresh;

  static Future<bool> _tryRefreshTokens() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  static Future<bool> _doRefresh() async {
    try {
      final refreshToken = await SecureSessionStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'accept': '*/*'},
        body: json.encode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return false;

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
      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Token refresh failed: $e\n$stack');
      }
      return false;
    }
  }

  // Get headers with token
  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    if (!auth) return {'Content-Type': 'application/json'};

    final token = await SecureSessionStorage.readAccessToken() ?? '';

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
        final refreshed = await _tryRefreshTokens();
        if (refreshed) {
          return _request(
            url,
            method: method,
            body: body,
            auth: auth,
            isRetry: true,
          );
        }
        // Refresh failed: expire the active session fully (tokens + session
        // record) so SelectUserScreen shows "requires login" immediately,
        // then redirect for WhatsApp-style re-authentication.
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
