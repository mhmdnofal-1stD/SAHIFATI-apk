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
  static const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');
  static const String facebookApiVersion =
      String.fromEnvironment('FACEBOOK_API_VERSION', defaultValue: 'v22.0');
  static const String huaweiAppId = String.fromEnvironment('HUAWEI_APP_ID');

  static bool get isGoogleConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return googleWebClientId.isNotEmpty;
    }

    return googleServerClientId.isNotEmpty;
  }

  static bool get isFacebookConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return true;
    }

    return facebookAppId.isNotEmpty;
  }

  static bool get isAppleConfiguredForCurrentPlatform {
    final hasWebFlowConfig =
        appleWebClientId.isNotEmpty && appleRedirectUriOrNull != null;

    if (kIsWeb) {
      return hasWebFlowConfig;
    }
    // Native iOS/macOS: Sign In with Apple is built-in, no external config needed
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        (defaultTargetPlatform == TargetPlatform.android && hasWebFlowConfig);
  }

  /// Huawei Account Kit is Android-only and never available on web.
  static bool get isHuaweiConfiguredForCurrentPlatform {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return true;
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
