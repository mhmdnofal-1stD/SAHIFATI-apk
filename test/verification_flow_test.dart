import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/core/auth/verification_flow.dart';

void main() {
  group('resolveVerificationRoute', () {
    test('parses hash verification route with token and email', () {
      final uri = Uri.parse(
        'http://localhost:5173/#/verify-email?token=abc123&email=test@example.com',
      );

      final intent = resolveVerificationRoute(uri);

      expect(intent.kind, VerificationRouteKind.verifyToken);
      expect(intent.token, 'abc123');
      expect(intent.email, 'test@example.com');
    });

    test('parses pending verification route', () {
      final uri = Uri.parse(
        'http://localhost:5173/#/verification-pending?email=user@example.com',
      );

      final intent = resolveVerificationRoute(uri);

      expect(intent.kind, VerificationRouteKind.pending);
      expect(intent.email, 'user@example.com');
    });
  });

  group('maskEmailAddress', () {
    test('masks regular addresses safely', () {
      expect(maskEmailAddress('someone@example.com'), 'so***e@example.com');
    });

    test('handles short local parts', () {
      expect(maskEmailAddress('ab@example.com'), 'a***@example.com');
      expect(maskEmailAddress('a@example.com'), '***@example.com');
    });
  });
}
