import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/controllers/users_controller.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/users_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final provider = UsersProvider();
    provider.selectedUser = null;
    provider.isFirstLogin = false;

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
    final user = User(id: 7, fullName: 'Test User', email: 'test@example.com');

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
    final user = User(id: 11, fullName: 'Auto Login', email: 'auto@example.com');

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
}