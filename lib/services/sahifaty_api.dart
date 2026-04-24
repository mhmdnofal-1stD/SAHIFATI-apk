import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../core/constants/api.dart';
import 'app_exception.dart';
import 'secure_session_storage.dart';

class SahifatyApi {
  final String _baseURL = '${ApiConfig.baseUrl}/';
  final Duration _timeout = const Duration(seconds: 30);

  // Get headers with token
  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    if (!auth) return {'Content-Type': 'application/json'};

    final token = await SecureSessionStorage.readAccessToken() ?? '';
    final refreshToken = await SecureSessionStorage.readRefreshToken() ?? '';

    return {
      'Authorization': 'Bearer $token',
      'X-Refresh-Token': refreshToken,
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
