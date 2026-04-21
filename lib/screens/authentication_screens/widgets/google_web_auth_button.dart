import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_web_button_adapter.dart';

class GoogleWebAuthButton extends StatefulWidget {
  const GoogleWebAuthButton({
    super.key,
    required this.onIdToken,
    required this.onError,
    required this.initialize,
    required this.isSignupContext,
    required this.isBusy,
  });

  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;
  final Future<void> Function() initialize;
  final bool isSignupContext;
  final bool isBusy;

  @override
  State<GoogleWebAuthButton> createState() => _GoogleWebAuthButtonState();
}

class _GoogleWebAuthButtonState extends State<GoogleWebAuthButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _isInitialized = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
      _subscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          if (event is! GoogleSignInAuthenticationEventSignIn) {
            return;
          }

          final String? idToken = event.user.authentication.idToken;
          if (idToken == null || idToken.isEmpty) {
            widget.onError({
              'errorCode': 'SOCIAL_ID_TOKEN_MISSING',
              'provider': 'google',
              'message': 'Could not retrieve Google identity token.',
            });
            return;
          }

          if (_isSubmitting) {
            return;
          }

          setState(() => _isSubmitting = true);
          try {
            await widget.onIdToken(idToken);
          } catch (error) {
            widget.onError(error);
          } finally {
            if (mounted) {
              setState(() => _isSubmitting = false);
            }
          }
        },
        onError: widget.onError,
      );

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (error) {
      widget.onError(error);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E5EC)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    return AbsorbPointer(
      absorbing: widget.isBusy || _isSubmitting,
      child: Opacity(
        opacity: widget.isBusy || _isSubmitting ? 0.7 : 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            buildGoogleWebButton(
              isSignupContext: widget.isSignupContext,
              locale: Get.locale?.languageCode,
            ),
            if (_isSubmitting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x88FFFFFF),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}