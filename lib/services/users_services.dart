import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api.dart';
import 'sahifaty_api.dart';

class UsersServices with ChangeNotifier {
  final String _baseURL = ApiConfig.baseUrl;
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

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final response = await SahifatyApi().get('users/me');
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _extractErrorMessage(responseData, 'Failed to load user profile');
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCurrentUserProfile({
    String? fullName,
    String? gender,
    int? birthYear,
    int? countryCode,
    String? country,
    String? city,
    String? mobile,
    String? educationLevel,
    String? workType,
    String? specializationType,
    bool? showMemorizationColors,
    bool? showComprehensionUnderline,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) {
        body['fullName'] = fullName;
      }
      if (gender != null) {
        body['gender'] = gender;
      }
      if (birthYear != null) {
        body['birthYear'] = birthYear;
      }
      if (countryCode != null) {
        body['countryCode'] = countryCode;
      }
      if (country != null) {
        body['country'] = country;
      }
      if (city != null) {
        body['city'] = city;
      }
      if (mobile != null) {
        body['mobile'] = mobile;
      }
      if (educationLevel != null) {
        body['educationLevel'] = educationLevel;
      }
      if (workType != null) {
        body['workType'] = workType;
      }
      if (specializationType != null) {
        body['specializationType'] = specializationType;
      }
      if (showMemorizationColors != null) {
        body['showMemorizationColors'] = showMemorizationColors;
      }
      if (showComprehensionUnderline != null) {
        body['showComprehensionUnderline'] = showComprehensionUnderline;
      }

      final response = await SahifatyApi().put(url: 'users/me', body: body);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _extractErrorMessage(responseData, 'Failed to update profile');
    } catch (ex) {
      rethrow;
    }
  }

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
