import 'dart:convert';
import 'package:web/web.dart' as web;

const String _googleRedirectResultKey =
    'sahifati_google_redirect_result';

/// Reads and removes the Google redirect result from sessionStorage.
///
/// The backend `POST /auth/social/google/redirect` endpoint stores the
/// credential (or error) in sessionStorage under this key before redirecting
/// back to the Flutter app. This function consumes that value once.
Map<String, dynamic>? consumeGoogleWebRedirectResult() {
  final raw = web.window.sessionStorage.getItem(_googleRedirectResultKey);
  if (raw == null || raw.isEmpty) {
    return null;
  }

  web.window.sessionStorage.removeItem(_googleRedirectResultKey);

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // The stored value is not valid JSON — already cleared above.
  }

  return null;
}