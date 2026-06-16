import 'dart:async';
import 'package:get/get.dart';
import 'package:google_identity_services_web/loader.dart';
import 'package:google_identity_services_web/id.dart' as gis_id;

Future<void>? _googleWebSdkFuture;

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

  // التوليد القياسي الآمن للـ ID Token ليتوافق مع السيرفر دون انكسار البناء
  gis_id.id.initialize(
    gis_id.IdConfiguration(
      client_id: clientId,
      auto_select: false,
      callback: (gis_id.CredentialResponse response) {
        if (completer.isCompleted) return;
        
        final idToken = response.credential;
        if (idToken != null && idToken.isNotEmpty) {
          completer.complete(idToken);
          return;
        }
        completer.completeError({
          'errorCode': 'SOCIAL_LOGIN_FAILED',
          'provider': 'google',
          'message': 'social_google_sign_in_failed'.tr
        });
      },
    ),
  );

  gis_id.id.prompt((gis_id.PromptMomentNotification notification) {
    if (notification.isDismissed() && !completer.isCompleted) {
      completer.completeError({
        'errorCode': 'SOCIAL_LOGIN_CANCELLED',
        'provider': 'google',
        'message': 'social_cancelled'.tr
      });
    }
  });

  return completer.future;
}
