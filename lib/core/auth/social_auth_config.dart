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
  static const bool facebookAuthEnabled =
    bool.fromEnvironment('FACEBOOK_AUTH_ENABLED', defaultValue: false);
  static const String facebookAppId =
      String.fromEnvironment('FACEBOOK_APP_ID');
  static const String facebookApiVersion =
      String.fromEnvironment('FACEBOOK_API_VERSION', defaultValue: 'v22.0');
  static const String huaweiAppId =
      String.fromEnvironment('HUAWEI_APP_ID');

  static bool get isGoogleConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return googleWebClientId.isNotEmpty;
    }

    return googleServerClientId.isNotEmpty;
  }

  static bool get isFacebookConfiguredForCurrentPlatform {
    // Facebook JS SDK initialization is unreliable on web (SDK load failures,
    // CORS, domain validation). Disable on web; Facebook login still works on
    // Android/iOS via the native SDK.
    if (kIsWeb) return false;

    if (!facebookAuthEnabled) {
      return false;
    }

    return facebookAppId.isNotEmpty;
  }

  static bool get isAppleConfiguredForCurrentPlatform {
    if (!kIsWeb) {
      return false;
    }

    return appleWebClientId.isNotEmpty && appleRedirectUri.isNotEmpty;
  }

  /// Huawei Account Kit is Android-only and never available on web.
  static bool get isHuaweiConfiguredForCurrentPlatform {
    if (kIsWeb) return false;
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
}