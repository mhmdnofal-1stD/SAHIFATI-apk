import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/auth/social_auth_config.dart';

import 'auth_social_section.dart';
import 'google_web_button_adapter.dart';

class GoogleWebAuthButton extends StatefulWidget {
  const GoogleWebAuthButton({
    super.key,
    required this.onToken,
    required this.onError,
    required this.isBusy,
  });

  final Future<void> Function(String token) onToken;
  final void Function(Object error) onError;
  final bool isBusy;

  @override
  State<GoogleWebAuthButton> createState() => _GoogleWebAuthButtonState();
}

class _GoogleWebAuthButtonState extends State<GoogleWebAuthButton> {
  bool _isInitialized = false;
  bool _isSubmitting = false;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await initializeGoogleWebPopupAuth(
        clientId: SocialAuthConfig.googleWebClientId,
      );
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (error) {
      if (mounted) setState(() => _initFailed = true);
      widget.onError(error);
    }
  }

  Future<void> _startGoogleSignIn() async {
    if (!_isInitialized || _isSubmitting || widget.isBusy) {
      return;
    }

    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    try {
      final token = await requestGoogleWebAccessToken(
        clientId: SocialAuthConfig.googleWebClientId,
      );
      await widget.onToken(token);
    } catch (error) {
      widget.onError(error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return const SizedBox(width: 56, height: 56);
    }

    if (!_isInitialized || _isSubmitting || widget.isBusy) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_google'.tr,
      onPressed: _startGoogleSignIn,
      isBusy: false,
      icon: Image.asset(Assets.googleIcon, width: 24, height: 24),
    );
  }
}