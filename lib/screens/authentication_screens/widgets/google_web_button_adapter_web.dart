import 'dart:async';
import 'package:get/get.dart';
import 'package:google_identity_services_web/loader.dart';
import 'package:google_identity_services_web/oauth2.dart' as gis_oauth2;

// تبديل النطاق ليشمل الـ openid للحصول على الـ Id Token الفيدرالي
const List<String> _googleAuthScopes = <String>['openid', 'email', 'profile'];

Future<void>? _googleWebSdkFuture;

/// تهيئة مكتبة جوجل على الويب
Future<void> initializeGoogleWebPopupAuth({
  required String clientId,
}) async {
  if (clientId.isEmpty) {
    throw _buildGoogleWebError(
      'SOCIAL_CONFIG_MISSING',
      'social_google_requires_client_id'.tr,
    );
  }

  _googleWebSdkFuture ??= loadWebSdk().catchError((Object error) {
    _googleWebSdkFuture = null;
    throw error;
  });

  await _googleWebSdkFuture;
}

/// [تم الإصلاح] جلب الـ ID Token بدلاً من الـ Access Token ليتوافق مع NestJS
Future<String> requestGoogleWebAccessToken({
  required String clientId,
}) async {
  await initializeGoogleWebPopupAuth(clientId: clientId);

  final completer = Completer<String>();
  
  // استخدام initIdTokenClient بدلاً من initTokenClient للحصول على شهادة المصادقة الفيدرالية
  final idTokenClient = gis_oauth2.oauth2.initIdTokenClient(
    gis_oauth2.IdTokenClientConfig(
      client_id: clientId,
      // الـ callback هنا يرجع كائن يحتوي على الكود المشفر للمستخدم (Credential/IdToken)
      callback: (response) {
        if (completer.isCompleted) {
          return;
        }

        // استخراج الـ ID Token الحقيقي المتوافق مع معايير السيرفر الخلفي
        final idToken = response.credential;
        if (idToken != null && idToken.isNotEmpty) {
          completer.complete(idToken);
          return;
        }

        completer.completeError(
          _buildGoogleWebResponseError(response.error, response.error_description),
        );
      },
      error_callback: (error) {
        if (completer.isCompleted) {
          return;
        }
        completer.completeError(_buildGoogleWebGisError(error));
      },
    ),
  );

  // إطلاق نافذة تسجيل الدخول المنبثقة لطلب الهوية للمستخدم
  idTokenClient.requestAccessToken();
  return completer.future;
}

Map<String, dynamic> _buildGoogleWebResponseError(
  String? error,
  String? description,
) {
  final isCancelled = error == 'access_denied';
  return _buildGoogleWebError(
    isCancelled ? 'SOCIAL_LOGIN_CANCELLED' : 'SOCIAL_LOGIN_FAILED',
    isCancelled ? 'social_cancelled'.tr : (description ?? 'social_google_sign_in_failed'.tr),
  );
}

Map<String, dynamic> _buildGoogleWebGisError(
  gis_oauth2.GoogleIdentityServicesError? error,
) {
  final type = error?.type;
  if (type == gis_oauth2.GoogleIdentityServicesErrorType.popup_closed) {
    return _buildGoogleWebError('SOCIAL_LOGIN_CANCELLED', 'social_cancelled'.tr);
  }

  if (type == gis_oauth2.GoogleIdentityServicesErrorType.popup_failed_to_open) {
    return _buildGoogleWebError(
      'SOCIAL_PROVIDER_UNSUPPORTED',
      'social_provider_temporarily_unavailable'.trParams({
        'provider': 'social_provider_google'.tr,
      }),
    );
  }

  return _buildGoogleWebError(
    'SOCIAL_LOGIN_FAILED',
    error?.message ?? 'social_google_sign_in_failed'.tr,
  );
}

Map<String, dynamic> _buildGoogleWebError(String code, String message) {
  return <String, dynamic>{
    'errorCode': code,
    'provider': 'google',
    'message': message,
  };
}
