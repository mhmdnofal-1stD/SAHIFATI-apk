// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

const String _pendingHuaweiStateKey = 'sahifati.huawei_web_oauth.state';
const String _pendingHuaweiNonceKey = 'sahifati.huawei_web_oauth.nonce';

Future<void> persistPendingHuaweiWebAuthRequest({
  required String state,
  required String nonce,
}) async {
  html.window.sessionStorage[_pendingHuaweiStateKey] = state;
  html.window.sessionStorage[_pendingHuaweiNonceKey] = nonce;
}

String? readPendingHuaweiWebState() {
  return html.window.sessionStorage[_pendingHuaweiStateKey];
}

String? readPendingHuaweiWebNonce() {
  return html.window.sessionStorage[_pendingHuaweiNonceKey];
}

void clearPendingHuaweiWebAuthRequest() {
  html.window.sessionStorage.remove(_pendingHuaweiStateKey);
  html.window.sessionStorage.remove(_pendingHuaweiNonceKey);
}

void redirectToHuaweiWebAuthorizationUrl(String authorizationUrl) {
  html.window.location.assign(authorizationUrl);
}

void clearHuaweiWebCallbackUrl() {
  final cleanUrl =
      '${html.window.location.pathname}${html.window.location.search}';
  html.window.history.replaceState(null, html.document.title, cleanUrl);
}