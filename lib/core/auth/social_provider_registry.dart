import 'social_auth_config.dart';
import 'social_provider.dart';

/// Single source of truth for which social providers are enabled
/// on the current platform with the current dart-define configuration.
///
/// Screens must not evaluate [SocialAuthConfig] platform guards directly —
/// they rely on this registry so that adding a new provider only requires
/// changes in [SocialAuthConfig] (dart-define) and [SocialProviderRegistry]
/// (inclusion), not in every screen.
class SocialProviderRegistry {
  const SocialProviderRegistry._();

  /// Returns all providers currently enabled for this platform + build config.
  static List<SocialProvider> get enabled => [
        if (SocialAuthConfig.isGoogleConfiguredForCurrentPlatform)
          SocialProvider.google,
        if (SocialAuthConfig.isAppleConfiguredForCurrentPlatform)
          SocialProvider.apple,
        if (SocialAuthConfig.isFacebookConfiguredForCurrentPlatform)
          SocialProvider.facebook,
        if (SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform)
          SocialProvider.huawei,
      ];

  /// Returns `true` if [provider] is enabled on the current platform.
  static bool isEnabled(SocialProvider provider) =>
      enabled.contains(provider);
}
