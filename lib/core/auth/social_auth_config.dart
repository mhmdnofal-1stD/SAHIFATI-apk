import 'package:flutter/foundation.dart';

class SocialAuthConfig {
  static const String _defaultGoogleClientId =
      '605484701854-h07an8isp8gr4jim786hi9tqegq62n5k.apps.googleusercontent.com';
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleServerClientId =
      String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: _defaultGoogleClientId,
      );
  static const bool facebookAuthEnabled =
    bool.fromEnvironment('FACEBOOK_AUTH_ENABLED', defaultValue: false);
  static const String facebookAppId =
      String.fromEnvironment('FACEBOOK_APP_ID');
  static const String facebookApiVersion =
      String.fromEnvironment('FACEBOOK_API_VERSION', defaultValue: 'v22.0');

  static bool get isGoogleConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return googleWebClientId.isNotEmpty;
    }

    return googleServerClientId.isNotEmpty;
  }

  static bool get isFacebookConfiguredForCurrentPlatform {
    if (!facebookAuthEnabled) {
      return false;
    }

    return facebookAppId.isNotEmpty;
  }

  static String? get googleClientIdOrNull =>
      googleWebClientId.isEmpty ? null : googleWebClientId;

  static String? get googleServerClientIdOrNull =>
      googleServerClientId.isEmpty ? null : googleServerClientId;

  static String? get facebookAppIdOrNull =>
      facebookAppId.isEmpty ? null : facebookAppId;
}