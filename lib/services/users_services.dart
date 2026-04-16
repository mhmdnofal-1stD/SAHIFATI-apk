import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersServices with ChangeNotifier {
  final String _baseURL = 'https://sahifati.org';
  final Duration _timeout = const Duration(seconds: 30);
  final Map<String, String> _authHeaders = {
    'Content-Type': 'application/json',
    'accept': 'application/json',
  };

  String _extractErrorMessage(dynamic responseData, String fallback) {
    final message = responseData['message'];

    if (message is String && message.isNotEmpty) {
      return message;
    }

    if (message is List && message.isNotEmpty) {
      return message.join(', ');
    }

    return fallback;
  }

  Future<dynamic> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/register'),
            headers: _authHeaders,
            body: json.encode({
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 201) {
        return AuthData.fromJson(responseData);
      } else {
        return responseData['message'] ?? 'Unknown error';
      }
    } catch (ex) {
      rethrow;
    }
  }


  Future<dynamic> login(
      {required String email, required String password}) async {
    try {
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      var response = await http
          .post(
            Uri.parse('$_baseURL/auth/login'),
            headers: headers,
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(_timeout);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthData.fromJson(responseData);
      } else {
        return responseData['message'] ?? 'Unknown error';
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<dynamic> loginWithGoogle(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/social/google'),
            headers: _authHeaders,
            body: json.encode({'token': token}),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return AuthData.fromJson(responseData);
      } else {
        return _extractErrorMessage(
          responseData,
          'Google login failed',
        );
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<dynamic> loginWithFacebook(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/social/facebook'),
            headers: _authHeaders,
            body: json.encode({'token': token}),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return AuthData.fromJson(responseData);
      } else {
        return _extractErrorMessage(
          responseData,
          'Facebook login failed',
        );
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<void> logout() async {}

  Future<void> sendPasswordResetEmail(email) async {
    try {} catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteAccount(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      if (token == null) {
        throw 'No authentication token found';
      }

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var response = await http
          .delete(
            Uri.parse('$_baseURL/users/$userId'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final responseData = json.decode(response.body);
        return responseData['message'] ?? 'Failed to delete account';
      }
    } catch (ex) {
      rethrow;
    }
  }
}
