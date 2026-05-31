import 'package:flutter/foundation.dart';

class SocialAuthConfig {
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const String appleWebClientId =
      String.fromEnvironment('APPLE_WEB_CLIENT_ID');
  static const String appleRedirectUri =
      String.fromEnvironment('APPLE_REDIRECT_URI');
  static const bool facebookAuthEnabled = bool.fromEnvironment(
    'FACEBOOK_AUTH_ENABLED',
    defaultValue: true,
  );
  static const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');
  static const String facebookApiVersion =
      String.fromEnvironment('FACEBOOK_API_VERSION', defaultValue: 'v22.0');
  static const String huaweiAppId = String.fromEnvironment('HUAWEI_APP_ID');
    static const String huaweiWebClientId =
      String.fromEnvironment('HUAWEI_WEB_CLIENT_ID');
    static const String huaweiWebRedirectUri =
      String.fromEnvironment('HUAWEI_WEB_REDIRECT_URI');

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

    if (kIsWeb) {
      return facebookAppId.isNotEmpty;
    }

    return facebookAppId.isNotEmpty;
  }

  static bool get isAppleConfiguredForCurrentPlatform {
    final hasWebFlowConfig =
        appleWebClientId.isNotEmpty && appleRedirectUriOrNull != null;

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

  static String? get googleClientIdOrNull =>
      googleWebClientId.isEmpty ? null : googleWebClientId;

  static String? get googleServerClientIdOrNull =>
      googleServerClientId.isEmpty ? null : googleServerClientId;

  static String? get facebookAppIdOrNull =>
      facebookAppId.isEmpty ? null : facebookAppId;

  static Uri? get appleRedirectUriOrNull {
    if (appleRedirectUri.isEmpty) {
      return null;
    }

    return Uri.tryParse(appleRedirectUri);
  }

  static Uri? get huaweiWebRedirectUriOrNull {
    if (huaweiWebRedirectUri.isEmpty) {
      return null;
    }

    return Uri.tryParse(huaweiWebRedirectUri);
  }

  static Uri? get appleRedirectUriForCurrentPlatform {
    final redirectUri = appleRedirectUriOrNull;
    if (redirectUri == null) {
      return null;
    }

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
