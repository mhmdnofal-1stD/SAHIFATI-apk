import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api.dart';
import '../models/user_notification_item.dart';
import 'sahifaty_api.dart';

class UsersServices with ChangeNotifier {
  final String _baseURL = ApiConfig.baseUrl;
  final Duration _timeout = const Duration(seconds: 30);
  final Map<String, String> _authHeaders = {
    'Content-Type': 'application/json',
    'accept': 'application/json',
  };

  Map<String, dynamic>? _extractStructuredMessage(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      return null;
    }

    final message = responseData['message'];
    if (message is Map<String, dynamic>) {
      return Map<String, dynamic>.from(message);
    }

    if (message is Map) {
      return message.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return null;
  }

  String _extractErrorMessage(dynamic responseData, String fallback) {
    final structuredMessage = _extractStructuredMessage(responseData);
    final nestedMessage = structuredMessage?['message'];
    if (nestedMessage is String && nestedMessage.isNotEmpty) {
      return nestedMessage;
    }

    if (nestedMessage is List && nestedMessage.isNotEmpty) {
      return nestedMessage.join(', ');
    }

    final message = responseData['message'];

    if (message is String && message.isNotEmpty) {
      return message;
    }

    if (message is List && message.isNotEmpty) {
      return message.join(', ');
    }

    return fallback;
  }

  Map<String, dynamic> _normalizeErrorResponse(
    int statusCode,
    dynamic responseData,
    String fallback,
  ) {
    final normalized = responseData is Map<String, dynamic>
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};

    final structuredMessage = _extractStructuredMessage(normalized);
    if (structuredMessage != null) {
      for (final entry in structuredMessage.entries) {
        normalized.putIfAbsent(entry.key, () => entry.value);
      }
    }

    normalized['statusCode'] ??= statusCode;
    normalized['message'] = _extractErrorMessage(normalized, fallback);
    return normalized;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/register'),
            headers: _authHeaders,
            body: json.encode({
              if (username != null && username.trim().isNotEmpty)
                'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_register_failed'.tr,
      );
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
      }

      return _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_login_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<dynamic> verifyEmail({required String token}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/verify-email'),
            headers: _authHeaders,
            body: json.encode({'token': token}),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return AuthData.fromJson(responseData);
      }

      return _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_verify_email_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resendVerification(
      {required String email}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/resend-verification'),
            headers: _authHeaders,
            body: json.encode({'email': email}),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_resend_verification_failed'.tr,
      );
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
      }

      return _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'social_google_sign_in_failed'.tr,
      );
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
      }

      return _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'social_facebook_sign_in_failed'.tr,
      );
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

      throw _extractErrorMessage(
        responseData,
        'service_users_load_profile_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMySupervisionCode() async {
    try {
      final response = await SahifatyApi().get('users/me/supervision-code');
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _extractErrorMessage(
        responseData,
        'service_users_load_supervision_code_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLicenseState() async {
    try {
      final response = await SahifatyApi().get('licensing/me');
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_load_license_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLicenseBalance() async {
    try {
      final response = await SahifatyApi().get('licensing/balance');
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_load_balance_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listMyPromoCodes() async {
    try {
      final response = await SahifatyApi().get('licensing/codes');
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData is List) {
        return responseData
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_load_promo_codes_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> activateGiftLicense() async {
    try {
      final response = await SahifatyApi().post(
        url: 'licensing/activate/gift',
        body: <String, dynamic>{},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_activate_license_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPromoCode({
    required int maxUses,
  }) async {
    try {
      final response = await SahifatyApi().post(
        url: 'licensing/codes',
        body: <String, dynamic>{'maxUses': maxUses},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_create_promo_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> revokePromoCode({
    required String codeId,
  }) async {
    try {
      final response = await SahifatyApi().post(
        url: 'licensing/codes/$codeId/revoke',
        body: <String, dynamic>{},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_revoke_promo_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> activatePromoLicense({
    required String code,
  }) async {
    try {
      final response = await SahifatyApi().post(
        url: 'licensing/activate/promo',
        body: <String, dynamic>{'code': code},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_activate_promo_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPurchaseIntent({
    int quantity = 20,
  }) async {
    try {
      final response = await SahifatyApi().post(
        url: 'licensing/purchase/intent',
        body: <String, dynamic>{'quantity': quantity},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_purchase_intent_failed'.tr,
      );
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

      throw _extractErrorMessage(
        responseData,
        'service_users_update_profile_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(email) async {
    await requestPasswordReset(email: email.toString());
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/request-password-reset'),
            headers: _authHeaders,
            body: json.encode({'email': email}),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_request_password_reset_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseURL/auth/complete-password-reset'),
            headers: _authHeaders,
            body: json.encode({
              'token': token,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_complete_password_reset_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<dynamic> deleteAccount(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        throw 'service_users_missing_auth_token'.tr;
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
        return responseData['message'] ?? 'delete_account_error'.tr;
      }
    } catch (ex) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> listMyNotifications({int limit = 20}) async {
    try {
      final response = await SahifatyApi().get('notifications/me?limit=$limit');
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(responseData as Map);
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_load_notifications_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }

  Future<UserNotificationItem> markNotificationRead({
    required String notificationId,
  }) async {
    try {
      final response = await SahifatyApi().post(
        url: 'notifications/$notificationId/read',
        body: <String, dynamic>{},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return UserNotificationItem.fromJson(
          Map<String, dynamic>.from(responseData as Map),
        );
      }

      throw _normalizeErrorResponse(
        response.statusCode,
        responseData,
        'service_users_mark_notification_read_failed'.tr,
      );
    } catch (ex) {
      rethrow;
    }
  }
}
