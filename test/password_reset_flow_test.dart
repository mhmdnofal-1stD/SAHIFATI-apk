import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/core/auth/password_reset_flow.dart';

void main() {
  group('resolvePasswordResetRoute', () {
    test('parses hash forgot-password route with prefilled email', () {
      final uri = Uri.parse(
        'http://localhost:5173/#/forgot-password?email=test@example.com',
      );

      final intent = resolvePasswordResetRoute(uri);

      expect(intent.kind, PasswordResetRouteKind.request);
      expect(intent.email, 'test@example.com');
      expect(intent.token, isNull);
    });

    test('parses reset-password route with token from mail link', () {
      final uri = Uri.parse(
        'http://localhost:5173/reset-password?token=abc123',
      );

      final intent = resolvePasswordResetRoute(uri);

      expect(intent.kind, PasswordResetRouteKind.reset);
      expect(intent.token, 'abc123');
      expect(intent.email, isNull);
    });

    test('preserves preview state for explicit mocked walkthrough routes', () {
      final uri = Uri.parse(
        'http://localhost:5173/#/forgot-password?email=test@example.com&preview=requestAccepted',
      );

      final intent = resolvePasswordResetRoute(uri);

      expect(intent.kind, PasswordResetRouteKind.request);
      expect(intent.email, 'test@example.com');
      expect(intent.preview, 'requestAccepted');
    });
  });
}