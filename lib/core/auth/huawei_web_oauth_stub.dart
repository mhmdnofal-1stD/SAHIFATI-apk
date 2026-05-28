Future<void> persistPendingHuaweiWebAuthRequest({
  required String state,
  required String nonce,
}) async {
  throw UnsupportedError('Huawei web OAuth is only available on the web');
}

String? readPendingHuaweiWebState() => null;

String? readPendingHuaweiWebNonce() => null;

void clearPendingHuaweiWebAuthRequest() {}

void redirectToHuaweiWebAuthorizationUrl(String authorizationUrl) {
  throw UnsupportedError('Huawei web OAuth is only available on the web');
}

void clearHuaweiWebCallbackUrl() {}