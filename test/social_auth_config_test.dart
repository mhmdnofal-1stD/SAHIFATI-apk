import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Huawei stays enabled on Android without a dart-define app id', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(SocialAuthConfig.huaweiAppId, isEmpty);
    expect(SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform, isTrue);
  });

  test('Huawei stays disabled on non-Android platforms', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform, isFalse);
  });

  test('Apple Android redirect uri adds the android platform marker', () {
    final redirectUri = SocialAuthConfig.appleRedirectUriForPlatform(
      Uri.parse('https://sahifati.org/api/auth/social/apple/callback'),
      isWeb: false,
      targetPlatform: TargetPlatform.android,
    );

    expect(redirectUri.queryParameters['platform'], 'android');
  });

  test('Apple web redirect uri keeps the configured callback unchanged', () {
    final redirectUri = SocialAuthConfig.appleRedirectUriForPlatform(
      Uri.parse('https://sahifati.org/api/auth/social/apple/callback'),
      isWeb: true,
      targetPlatform: TargetPlatform.android,
    );

    expect(
      redirectUri.toString(),
      'https://sahifati.org/api/auth/social/apple/callback',
    );
  });
}