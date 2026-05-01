import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/core/auth/purchase_return_flow.dart';

void main() {
  group('resolvePurchaseReturnRoute', () {
    test('parses hash purchase success on the license activation route', () {
      final uri = Uri.parse(
        'https://sahifati.org/app/#/license-activation?purchase=success',
      );

      final intent = resolvePurchaseReturnRoute(uri);

      expect(intent.kind, PurchaseReturnKind.success);
    });

    test('parses direct purchase failure on the my licenses route', () {
      final uri = Uri.parse(
        'https://sahifati.org/app/my-licenses?purchase=failure',
      );

      final intent = resolvePurchaseReturnRoute(uri);

      expect(intent.kind, PurchaseReturnKind.failure);
    });

    test('lets explicit status override a non-matching base uri', () {
      final uri = Uri.parse('https://sahifati.org/');

      final intent = resolvePurchaseReturnRoute(
        uri,
        explicitStatus: 'cancelled',
      );

      expect(intent.kind, PurchaseReturnKind.cancelled);
    });

    test('ignores unrelated routes when no purchase state is present', () {
      final uri = Uri.parse('https://sahifati.org/app/#/welcome');

      final intent = resolvePurchaseReturnRoute(uri);

      expect(intent.kind, PurchaseReturnKind.none);
    });
  });
}
