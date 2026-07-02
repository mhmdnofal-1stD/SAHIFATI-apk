import 'dart:async';
import 'package:get/get.dart';
import 'package:google_identity_services_web/loader.dart';
import 'package:google_identity_services_web/id.dart' as gis_id;

Future<void>? _googleWebSdkFuture;
bool _gisInitialized = false;
Completer<String>? _activeCompleter;

Future<void> initializeGoogleWebPopupAuth({
  required String clientId,
}) async {
  if (clientId.isEmpty) {
    throw <String, dynamic>{
      'errorCode': 'SOCIAL_CONFIG_MISSING',
      'provider': 'google',
      'message': 'social_google_requires_client_id'.tr
    };
  }
  _googleWebSdkFuture ??= loadWebSdk().catchError((Object error) {
    _googleWebSdkFuture = null;
    throw error;
  });
  await _googleWebSdkFuture;
}

Future<String> requestGoogleWebAccessToken({
  required String clientId,
}) async {
  await initializeGoogleWebPopupAuth(clientId: clientId);
  final completer = Completer<String>();
  _activeCompleter = completer;

  if (!_gisInitialized) {
    gis_id.id.initialize(
      gis_id.IdConfiguration(
        client_id: clientId,
        auto_select: false,
        callback: (gis_id.CredentialResponse response) {
          final current = _activeCompleter;
          if (current == null || current.isCompleted) return;

          final idToken = response.credential;
          if (idToken != null && idToken.isNotEmpty) {
            current.complete(idToken);
            return;
          }
          current.completeError({
            'errorCode': 'SOCIAL_LOGIN_FAILED',
            'provider': 'google',
            'message': 'social_google_sign_in_failed'.tr
          });
        },
      ),
    );
    _gisInitialized = true;
  }

  gis_id.id.prompt((gis_id.PromptMomentNotification notification) {
    if (completer.isCompleted) return;
    if (notification.isNotDisplayed() ||
        notification.isSkippedMoment() ||
        notification.isDismissedMoment()) {
      completer.completeError({
        'errorCode': 'SOCIAL_LOGIN_CANCELLED',
        'provider': 'google',
        'message': 'social_cancelled'.tr
      });
    }
  });

  return completer.future.timeout(
    const Duration(minutes: 3),
    onTimeout: () {
      if (!completer.isCompleted) {
        completer.completeError({
          'errorCode': 'SOCIAL_LOGIN_CANCELLED',
          'provider': 'google',
          'message': 'social_cancelled'.tr
        });
      }
      throw TimeoutException(
        'Google sign-in timed out waiting for GIS response',
        const Duration(minutes: 3),
      );
    },
  );
}