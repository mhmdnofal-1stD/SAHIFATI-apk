import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:sahifaty/models/user.dart';

void main() {
  test('User.fromJson maps string role values to numeric userRoleId', () {
    final user = User.fromJson({
      '_id': 7,
      'username': 'supervisor-one',
      'email': 'supervisor@example.com',
      'role': 'supervisor',
    });

    expect(user.userRoleId, 1);
  });

  test('AuthData.fromJson preserves string role mapping in embedded user', () {
    final authData = AuthData.fromJson({
      'id': 9,
      'username': 'student-one',
      'email': 'student@example.com',
      'role': 'student',
      'token': 'access',
      'refreshToken': 'refresh',
    });

    expect(authData.user, isNotNull);
    expect(authData.user!.userRoleId, 0);
  });
}