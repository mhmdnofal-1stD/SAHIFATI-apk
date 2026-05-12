import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'widgets/auth_social_section.dart';
import 'widgets/google_web_auth_button.dart';

/// Mixin for [State] classes that host social authentication controls.
///
/// Centralises provider action dispatch, error message resolution, and
/// button widget construction. Screens mix this in and call
/// [buildSocialSection] instead of duplicating per-provider logic.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SocialAuthAction {
///   @override
///   void beforeSocialAction() { _inlineError = null; }
///
///   @override
///   Widget build(BuildContext context) {
///     final up = Provider.of<UsersProvider>(context);
///     final ep = Provider.of<EvaluationsProvider>(context);
///     ...
///     buildSocialSection(up, ep, isSignupContext: false),
///   }
/// }
/// ```
mixin SocialAuthAction<T extends StatefulWidget> on State<T> {
  // ── shared state ─────────────────────────────────────────────────────────

  /// Current social-auth status message to display in [AuthSocialSection].
  String? socialStatusMessage;

  /// Whether [socialStatusMessage] represents an error (vs info).
  bool socialStatusIsError = true;

  // ── lifecycle hook ────────────────────────────────────────────────────────

  /// Called inside [setState] immediately before every social action starts.
  ///
  /// Override to reset screen-specific fields, for example an inline error
  /// banner that must be cleared when a new social action begins:
  /// ```dart
  /// @override
  /// void beforeSocialAction() { _inlineError = null; }
  /// ```
  void beforeSocialAction() {}

  // ── error message resolution ──────────────────────────────────────────────

  String _providerDisplayLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'social_provider_google'.tr;
      case 'facebook':
        return 'social_provider_facebook'.tr;
      case 'apple':
        return 'social_provider_apple'.tr;
      case 'huawei':
        return 'social_provider_huawei'.tr;
      default:
        return provider;
    }
  }

  /// Maps a backend or SDK error to a translated user-facing string.
  String resolveSocialErrorMessage(Object error, UsersProvider up) {
    if (error is Map) {
      final code = error['errorCode'];
      final existingProvider = error['existingProvider'];

      if (code == 'SOCIAL_LOGIN_CANCELLED') {
        final p = (error['provider'] ?? '').toString();
        if (!kIsWeb && p == 'google') {
          return 'social_google_mobile_interrupted'.tr;
        }
        return 'social_cancelled'.tr;
      }

      if (code == 'SOCIAL_CONFIG_MISSING') {
        final p = error['provider'];
        if (p == 'google') {
          return kIsWeb
              ? 'social_google_requires_client_id'.tr
              : 'social_google_requires_mobile_config'.tr;
        }
        if (p == 'facebook') return 'social_facebook_requires_app_id'.tr;
        if (p == 'apple') return 'social_apple_requires_web_config'.tr;
      }

      if (code == 'SOCIAL_PROVIDER_UNSUPPORTED') {
        return 'social_provider_temporarily_unavailable'.trParams({
          'provider':
              _providerDisplayLabel((error['provider'] ?? 'provider').toString()),
        });
      }

      if (code == 'SOCIAL_ID_TOKEN_MISSING' ||
          code == 'SOCIAL_ACCESS_TOKEN_MISSING') {
        return 'social_missing_id_token'.tr;
      }

      if (code == 'ACCOUNT_EXISTS_WITH_PASSWORD') {
        return 'social_account_exists_with_password'.tr;
      }

      if (code == 'ACCOUNT_EXISTS_WITH_DIFFERENT_PROVIDER') {
        return 'social_account_exists_with_different_provider'.trParams({
          'provider':
              _providerDisplayLabel((existingProvider ?? 'provider').toString()),
        });
      }
    }

    final message = up.extractErrorMessage(error);
    if (message.toLowerCase().contains('cancel')) {
      return 'social_cancelled'.tr;
    }
    return message;
  }

  // ── core action runner ────────────────────────────────────────────────────

  /// Executes [action], shows an error banner on failure, and navigates on
  /// success. All social buttons delegate to this method.
  Future<void> completeSocialAction(
    Future<dynamic> Function() action,
    UsersProvider up,
    EvaluationsProvider ep,
  ) async {
    if (up.isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      socialStatusMessage = null;
      socialStatusIsError = true;
      beforeSocialAction();
    });
    try {
      await action();
      if (!mounted || up.selectedUser == null) return;
      await navigateAfterSuccessfulLogin(
        userId: up.selectedUser!.id,
        isFirstLogin: up.isFirstLogin,
        hasActiveLicense: up.hasActiveLicense,
        loadChartData: (userId) => ep.getQuranChartData(userId),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        socialStatusMessage = resolveSocialErrorMessage(error, up);
        socialStatusIsError = true;
      });
    }
  }

  // ── per-provider control builders ─────────────────────────────────────────

  Widget _buildGoogleControl(
    UsersProvider up,
    EvaluationsProvider ep, {
    required bool isSignupContext,
  }) {
    if (kIsWeb && SocialAuthConfig.isGoogleConfiguredForCurrentPlatform) {
      return GoogleWebAuthButton(
        initialize: up.ensureGoogleInitialized,
        isBusy: up.isLoading,
        isSignupContext: isSignupContext,
        onIdToken: (idToken) => completeSocialAction(
          () => up.signInWithGoogleIdToken(idToken),
          up,
          ep,
        ),
        onError: (error) {
          if (!mounted) return;
          setState(() {
            socialStatusMessage = resolveSocialErrorMessage(error, up);
            socialStatusIsError = true;
          });
        },
      );
    }
    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_google'.tr,
      onPressed: (!kIsWeb && !up.isLoading)
          ? () => completeSocialAction(up.signInWithGoogle, up, ep)
          : null,
      isBusy: up.isLoading,
      icon: Image.asset(Assets.googleIcon, width: 24, height: 24),
    );
  }

  Widget _buildAppleControl(UsersProvider up, EvaluationsProvider ep) {
    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_apple'.tr,
      onPressed: up.isLoading
          ? null
          : () => completeSocialAction(up.signInWithApple, up, ep),
      isBusy: up.isLoading,
      icon: const Icon(
        Icons.apple_rounded,
        size: 26,
        color: Color(0xFF111111),
      ),
    );
  }

  Widget _buildFacebookControl(UsersProvider up, EvaluationsProvider ep) {
    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_facebook'.tr,
      onPressed: up.isLoading
          ? null
          : () => completeSocialAction(up.signInWithFacebook, up, ep),
      isBusy: up.isLoading,
      icon: const Icon(
        Icons.facebook_rounded,
        color: Color(0xFF1877F2),
        size: 25,
      ),
    );
  }

  Widget _buildHuaweiControl(UsersProvider up, EvaluationsProvider ep) {
    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_huawei'.tr,
      onPressed: up.isLoading
          ? null
          : () => completeSocialAction(up.signInWithHuawei, up, ep),
      isBusy: up.isLoading,
      icon: SvgPicture.asset(Assets.huaweiIcon, width: 24, height: 24),
    );
  }

  // ── section builder ───────────────────────────────────────────────────────

  /// Returns `true` when at least one social provider is enabled on the
  /// current platform. Use this to conditionally hide the entire section.
  bool get hasSocialProviders =>
      SocialAuthConfig.isGoogleConfiguredForCurrentPlatform ||
      SocialAuthConfig.isAppleConfiguredForCurrentPlatform ||
      SocialAuthConfig.isFacebookConfiguredForCurrentPlatform ||
      SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform;

  /// Builds the complete [AuthSocialSection] with all enabled providers.
  ///
  /// [isSignupContext] is forwarded to the Google button so the GSI SDK shows
  /// the correct label ("Sign up" vs "Sign in").
  Widget buildSocialSection(
    UsersProvider up,
    EvaluationsProvider ep, {
    required bool isSignupContext,
    bool showEmailMethod = false,
  }) {
    final controls = <Widget>[
      _buildGoogleControl(up, ep, isSignupContext: isSignupContext),
      if (SocialAuthConfig.isAppleConfiguredForCurrentPlatform)
        _buildAppleControl(up, ep),
      if (SocialAuthConfig.isFacebookConfiguredForCurrentPlatform)
        _buildFacebookControl(up, ep),
      if (SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform)
        _buildHuaweiControl(up, ep),
    ];

    return AuthSocialSection(
      controls: controls,
      showEmailMethod: showEmailMethod,
      statusMessage: socialStatusMessage,
      statusTone: socialStatusIsError
          ? AuthSocialStatusTone.error
          : AuthSocialStatusTone.info,
    );
  }
}
