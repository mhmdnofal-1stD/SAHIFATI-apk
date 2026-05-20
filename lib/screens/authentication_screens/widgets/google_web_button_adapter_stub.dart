Future<void> initializeGoogleWebPopupAuth({
  required String clientId,
}) async {}

Future<String> requestGoogleWebAccessToken({
  required String clientId,
}) async {
  throw UnsupportedError('Google web auth is only available on web.');
}