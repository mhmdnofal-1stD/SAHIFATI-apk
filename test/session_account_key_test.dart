import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/models/user.dart';

void main() {
  test('deriveUserAccountKeyFromMap prefers explicit account key', () {
    final accountKey = deriveUserAccountKeyFromMap({
      'accountKey': 'id:existing-account',
      'id': '507f1f77bcf86cd799439011',
      'email': 'user@example.com',
    });

    expect(accountKey, 'id:existing-account');
  });

  test('user preserves raw object id in account key and map', () {
    final user = User.fromJson({
      'id': '507f1f77bcf86cd799439011',
      'username': 'reader.one',
      'email': 'reader@example.com',
    });

    expect(user.id, 0);
    expect(user.rawId, '507f1f77bcf86cd799439011');
    expect(user.accountKey, 'id:507f1f77bcf86cd799439011');
    expect(user.toMap()['accountKey'], 'id:507f1f77bcf86cd799439011');
  });

  test('account key falls back to normalized email when id is missing', () {
    final accountKey = deriveUserAccountKeyFromMap({
      'email': 'Reader@Example.com',
      'username': 'Reader',
    });

    expect(accountKey, 'email:reader@example.com');
  });
}