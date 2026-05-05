import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:sahifaty/controllers/users_controller.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/services/secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final provider = UsersProvider();
    provider.selectedUser = null;
    provider.isFirstLogin = false;
    provider.debugRefreshTokensOverride = null;

    final controller = UsersController();
    controller.loginEmailController.clear();
    controller.loginPasswordController.clear();
    controller.rememberMe = true;
  });

  test('selector prefill does not become remembered email implicitly', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', 'remembered@example.com');

    final controller = UsersController();
    await controller.getLoginInfo(preferredEmail: 'stored-user@example.com');

    expect(controller.loginEmailController.text, 'stored-user@example.com');
    expect(controller.rememberMe, isFalse);
  });

  test('first-login state stays true until onboarding completes', () async {
    final provider = UsersProvider();
    final user = User(id: 7, username: 'test_user', email: 'test@example.com');

    provider.selectedUser = user;

    await provider.checkFirstLogin(user: user);
    expect(provider.isFirstLogin, isTrue);

    await provider.checkFirstLogin(user: user);
    expect(provider.isFirstLogin, isTrue);

    await provider.markOnboardingCompleted(user: user);
    await provider.checkFirstLogin(user: user);
    expect(provider.isFirstLogin, isFalse);
  });

  test('auto login restores onboarding-based routing state for the active user', () async {
    final provider = UsersProvider();
    final user = User(id: 11, username: 'auto_login', email: 'auto@example.com');

    await provider.saveUserSession(user, 'access-token');
    provider.selectedUser = null;
    provider.isFirstLogin = false;

    final firstAutoLogin = await provider.tryAutoLogin();
    expect(firstAutoLogin, isTrue);
    expect(provider.selectedUser?.id, user.id);
    expect(provider.isFirstLogin, isTrue);

    await provider.markOnboardingCompleted(user: user);
    provider.selectedUser = null;
    provider.isFirstLogin = true;

    final secondAutoLogin = await provider.tryAutoLogin();
    expect(secondAutoLogin, isTrue);
    expect(provider.selectedUser?.id, user.id);
    expect(provider.isFirstLogin, isFalse);
  });

  test('switching stored user silently refreshes an expired access token',
      () async {
    final provider = UsersProvider();
    final user = User(
      id: 21,
      username: 'stored_user',
      email: 'stored@example.com',
    );

    await provider.saveUserSession(
      user,
      'stale-access-token',
      refreshToken: 'refresh-token-21',
    );

    FlutterSecureStorage.setMockInitialValues({
      'refreshToken:21': 'refresh-token-21',
      'active_session_account_key': '21',
    });

    provider.debugRefreshTokensOverride = (refreshToken) async {
      expect(refreshToken, 'refresh-token-21');
      return AuthData(
        accessToken: 'renewed-access-token',
        refreshToken: 'renewed-refresh-token',
      );
    };

    final switched = await provider.switchToStoredUser({
      'id': 21,
      'email': 'stored@example.com',
      'username': 'stored_user',
    });

    expect(switched, isTrue);
    expect(provider.selectedUser?.id, 21);
    expect(
      await SecureSessionStorage.readAccessToken(accountKey: '21'),
      'renewed-access-token',
    );
    expect(
      await SecureSessionStorage.readRefreshToken(accountKey: '21'),
      'renewed-refresh-token',
    );
  });

  test('corrupt stored device users are discarded instead of breaking bootstrap',
      () async {
    SharedPreferences.setMockInitialValues({
      'stored_device_users': 'not-json',
    });

    final provider = UsersProvider();
    final users = await provider.getStoredDeviceUsers();
    final prefs = await SharedPreferences.getInstance();

    expect(users, isEmpty);
    expect(prefs.getString('stored_device_users'), isNull);
  });

  test('logout clears only the active account session and preserves others',
      () async {
    final provider = UsersProvider();
    final userA = User(id: 31, username: 'alpha', email: 'alpha@example.com');
    final userB = User(id: 32, username: 'beta', email: 'beta@example.com');

    await provider.saveUserToDevice(userA);
    await provider.saveUserToDevice(userB);
    await provider.saveUserSession(
      userA,
      'access-a',
      refreshToken: 'refresh-a',
    );
    await provider.saveUserSession(
      userB,
      'access-b',
      refreshToken: 'refresh-b',
    );

    final switchedToA = await provider.switchToStoredUser({
      'id': 31,
      'email': 'alpha@example.com',
      'username': 'alpha',
    });
    expect(switchedToA, isTrue);

    await provider.logout();

    final storedUsers = await provider.getStoredDeviceUsers();
    final alpha = storedUsers.firstWhere((user) => user['id'] == 31);
    final beta = storedUsers.firstWhere((user) => user['id'] == 32);

    expect(provider.selectedUser, isNull);
    expect(alpha['hasActiveSession'], isFalse);
    expect(beta['hasActiveSession'], isTrue);
    expect(alpha['isCurrent'], isFalse);
    expect(beta['isCurrent'], isFalse);
    expect(
      await SecureSessionStorage.readAccessToken(accountKey: '31'),
      isNull,
    );
    expect(
      await SecureSessionStorage.readAccessToken(accountKey: '32'),
      'access-b',
    );
  });

  test('removing a non-current device user clears only that account data',
      () async {
    final provider = UsersProvider();
    final userA = User(id: 41, username: 'alpha', email: 'alpha@example.com');
    final userB = User(id: 42, username: 'beta', email: 'beta@example.com');

    await provider.saveUserToDevice(userA);
    await provider.saveUserToDevice(userB);
    await provider.saveUserSession(
      userA,
      'access-a',
      refreshToken: 'refresh-a',
    );
    await provider.saveUserSession(
      userB,
      'access-b',
      refreshToken: 'refresh-b',
    );

    final switchedToA = await provider.switchToStoredUser({
      'id': 41,
      'email': 'alpha@example.com',
      'username': 'alpha',
    });
    expect(switchedToA, isTrue);

    await provider.removeUserFromDevice('beta@example.com');

    final storedUsers = await provider.getStoredDeviceUsers();
    expect(storedUsers.length, 1);
    expect(storedUsers.single['id'], 41);
    expect(storedUsers.single['isCurrent'], isTrue);
    expect(storedUsers.single['hasActiveSession'], isTrue);
    expect(provider.selectedUser?.id, 41);
    expect(
      await SecureSessionStorage.readAccessToken(accountKey: '41'),
      'access-a',
    );
    expect(
      await provider.hasStoredSessionForUser({
        'id': 42,
        'email': 'beta@example.com',
        'username': 'beta',
      }),
      isFalse,
    );
  });

  test('removing the current device user preserves other stored accounts',
      () async {
    final provider = UsersProvider();
    final userA = User(id: 51, username: 'alpha', email: 'alpha@example.com');
    final userB = User(id: 52, username: 'beta', email: 'beta@example.com');

    await provider.saveUserToDevice(userA);
    await provider.saveUserToDevice(userB);
    await provider.saveUserSession(
      userA,
      'access-a',
      refreshToken: 'refresh-a',
    );
    await provider.saveUserSession(
      userB,
      'access-b',
      refreshToken: 'refresh-b',
    );

    final switchedToA = await provider.switchToStoredUser({
      'id': 51,
      'email': 'alpha@example.com',
      'username': 'alpha',
    });
    expect(switchedToA, isTrue);

    await provider.removeUserFromDevice('alpha@example.com');

    final storedUsers = await provider.getStoredDeviceUsers();
    expect(storedUsers.length, 1);
    expect(storedUsers.single['id'], 52);
    expect(storedUsers.single['isCurrent'], isFalse);
    expect(storedUsers.single['hasActiveSession'], isTrue);
    expect(provider.selectedUser, isNull);
    expect(
      await provider.hasStoredSessionForUser({
        'id': 51,
        'email': 'alpha@example.com',
        'username': 'alpha',
      }),
      isFalse,
    );
    expect(
      await SecureSessionStorage.readAccessToken(accountKey: '52'),
      'access-b',
    );
  });

  test('User.fromJson ignores legacy fullName-only payload as live identity',
      () {
    final user = User.fromJson({
      'id': 99,
      'fullName': 'Legacy Name',
      'email': 'legacy@example.com',
    });

    expect(user.username, isEmpty);
    expect(user.email, 'legacy@example.com');
  });
}