import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SocialAuthConfig {
  // تحويل المتغيرات إلى متغيرات ديناميكية قابلة للتعديل بعد التحميل
  static String googleWebClientId = '';
  static String googleServerClientId = const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static String appleWebClientId = '';
  static String appleRedirectUri = '';
  
  static const bool facebookAuthEnabled = bool.fromEnvironment(
    'FACEBOOK_AUTH_ENABLED',
    defaultValue: true,
  );
  static String facebookAppId = '';
  static const String facebookApiVersion = String.fromEnvironment('FACEBOOK_API_VERSION', defaultValue: 'v22.0');
  static const String huaweiAppId = String.fromEnvironment('HUAWEI_APP_ID');
  static String huaweiWebClientId = '';
  static String huaweiWebRedirectUri = '';

  /// دالة التهيئة الديناميكية التي يجب استدعاؤها في الـ main() قبل الـ runApp
  static Future<void> initialize() async {
    try {
      final jsonString = await rootBundle.loadString('assets/config/auth_config.json');
      final Map<String, dynamic> config = jsonDecode(jsonString);
      
      googleWebClientId = config['GOOGLE_WEB_CLIENT_ID'] ?? '';
      appleWebClientId = config['APPLE_WEB_CLIENT_ID'] ?? '';
      appleRedirectUri = config['APPLE_REDIRECT_URI'] ?? '';
      facebookAppId = config['FACEBOOK_APP_ID'] ?? '';
      huaweiWebClientId = config['HUAWEI_WEB_CLIENT_ID'] ?? '';
      huaweiWebRedirectUri = config['HUAWEI_WEB_REDIRECT_URI'] ?? '';
      
      debugPrint('Social Auth Config loaded successfully from JSON.');
    } catch (e) {
      debugPrint('Failed to load dynamic social auth config: $e');
      // في حال الفشل، سيعتمد التطبيق على القيم الافتراضية الفارغة دون أن ينهار
    }
  }

  static bool get isGoogleConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return googleWebClientId.isNotEmpty;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return googleServerClientId.isNotEmpty;
  }

  static bool get isFacebookConfiguredForCurrentPlatform {
    if (!facebookAuthEnabled) {
      return false;
    }
    return facebookAppId.isNotEmpty;
  }

  static bool get isAppleConfiguredForCurrentPlatform {
    final hasWebFlowConfig = appleWebClientId.isNotEmpty && appleRedirectUriOrNull != null;
    if (kIsWeb) {
      return hasWebFlowConfig;
    }
    return defaultTargetPlatform == TargetPlatform.android && hasWebFlowConfig;
  }

  static bool get isHuaweiConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return huaweiWebClientId.isNotEmpty && huaweiWebRedirectUriOrNull != null;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return huaweiAppId.isNotEmpty;
  }

  static String? get googleClientIdOrNull => googleWebClientId.isEmpty ? null : googleWebClientId;
  static String? get googleServerClientIdOrNull => googleServerClientId.isEmpty ? null : googleServerClientId;
  static String? get facebookAppIdOrNull => facebookAppId.isEmpty ? null : facebookAppId;

  static Uri? get appleRedirectUriOrNull {
    if (appleRedirectUri.isEmpty) return null;
    return Uri.tryParse(appleRedirectUri);
  }

  static Uri? get huaweiWebRedirectUriOrNull {
    if (huaweiWebRedirectUri.isEmpty) return null;
    return Uri.tryParse(huaweiWebRedirectUri);
  }

  static Uri? get appleRedirectUriForCurrentPlatform {
    final redirectUri = appleRedirectUriOrNull;
    if (redirectUri == null) return null;
    return appleRedirectUriForPlatform(
      redirectUri,
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    );
  }

  @visibleForTesting
  static Uri appleRedirectUriForPlatform(
    Uri redirectUri, {
    required bool isWeb,
    required TargetPlatform targetPlatform,
  }) {
    if (isWeb || targetPlatform != TargetPlatform.android) {
      return redirectUri;
    }
    final queryParameters = Map<String, String>.from(redirectUri.queryParameters);
    queryParameters['platform'] = 'android';
    return redirectUri.replace(queryParameters: queryParameters);
  }
}
