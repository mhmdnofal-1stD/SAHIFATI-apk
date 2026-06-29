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

  // [تم الإصلاح] استخدام فلو آمن للنافذة المنبثقة: لا نُلغي إلا عند الإشارات
  // الصريحة من الـ SDK بأن النافذة لم تُعرض أو تم تخطّيها أو إغلاقها.
  gis_id.id.prompt((gis_id.PromptMomentNotification notification) {
    if (completer.isCompleted) return;
    // نُكمل بخطأ الإلغاء عند الحالات الفعلية للإخفاء/التخطّي/الإغلاق اليدوي،
    // وليس عند لحظة العرض (display) التي تُطلق دائماً عند الفتح.
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

  // ضمانة أمان: حتى لو لم يُطلق الـ GIS أي إشارة معروفة (مثلاً حجب المتصفح
  // للنوافذ المنبثقة)، يجب أن تُحلّ الـ future دائماً كي لا يبقى الزر معلّقاً.
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
      // الـ completer لم يُكمل خلال المهلة؛ نُطلق استثناء الإلغاء للمُستهلك.
      throw TimeoutException(
        'Google sign-in timed out waiting for GIS response',
        const Duration(minutes: 3),
      );
    },
  );
}