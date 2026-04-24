import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/colors.dart';
import '../providers/users_provider.dart';
import '../screens/authentication_screens/login_screen.dart';
import '../screens/authentication_screens/select_user_screen.dart';

class UsersController {
  static final UsersController _instance = UsersController._internal();
  static const String _rememberedEmailKey = 'email';
  static const String _legacySavedForPrefix = 'saved for ';

  factory UsersController() => _instance;

  UsersController._internal();

  TextEditingController usernameController = TextEditingController();
  TextEditingController loginEmailController = TextEditingController();
  TextEditingController loginPasswordController = TextEditingController();
  TextEditingController signUpEmailController = TextEditingController();
  TextEditingController signUpPasswordController = TextEditingController();
  TextEditingController signUpUsernameController = TextEditingController();
  TextEditingController signUpConfirmedPasswordController =
      TextEditingController();
  TextEditingController forgotPasswordEmailController = TextEditingController();
  Color signUpEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
  Color signUpPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
  Color signUpUsernameTextFieldBorderColor = AppColors.textFieldBorderColor;
  Color loginEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
  Color loginPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
  Color confirmPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
  bool noneIsEmpty = true;
  bool isMatched = true;
  bool passwordIsValid = true;
  bool rememberMe = true;

  bool checkEmptyFields(bool login) {
    if (login == false) {
      noneIsEmpty = signUpEmailController.text.isNotEmpty &&
          signUpUsernameController.text.isNotEmpty &&
          signUpPasswordController.text.isNotEmpty &&
          signUpConfirmedPasswordController.text.isNotEmpty;
    } else {
      noneIsEmpty = loginEmailController.text.isNotEmpty &&
          loginPasswordController.text.isNotEmpty;
    }

    return noneIsEmpty;
  }

  void checkMatchedPassword() {
    isMatched = signUpPasswordController.text ==
        signUpConfirmedPasswordController.text;
  }

  void checkValidPassword() {
    String password = signUpPasswordController.text;

    if (password.isEmpty) {
      throw Exception('auth_password_validation_required'.tr);
    } else if (password.length < 8) {
      throw Exception('auth_password_validation_length'.tr);
    } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
      throw Exception('auth_password_validation_uppercase'.tr);
    } else if (!RegExp(r'[a-z]').hasMatch(password)) {
      throw Exception('auth_password_validation_lowercase'.tr);
    } else if (!RegExp(r'\d').hasMatch(password)) {
      throw Exception('auth_password_validation_number'.tr);
    } else if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      throw Exception('auth_password_validation_symbol'.tr);
    }
  }

  bool isEmailValid(String email) {
    return GetUtils.isEmail(email);
  }

  void changeTextFieldsColors(bool login) {
    if (!noneIsEmpty) {
      if (login == false) {
        if (signUpEmailController.text.isEmpty) {
          signUpEmailTextFieldBorderColor = AppColors.errorColor;
        } else {
          signUpEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
        }
        if (signUpUsernameController.text.isEmpty) {
          signUpUsernameTextFieldBorderColor = AppColors.errorColor;
        } else {
          signUpUsernameTextFieldBorderColor = AppColors.textFieldBorderColor;
        }
        if (signUpPasswordController.text.isEmpty) {
          signUpPasswordTextFieldBorderColor = AppColors.errorColor;
        } else {
          signUpPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
        }
      } else {
        if (loginEmailController.text.isEmpty) {
          loginEmailTextFieldBorderColor = AppColors.errorColor;
        } else {
          loginEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
        }
        if (loginPasswordController.text.isEmpty) {
          loginPasswordTextFieldBorderColor = AppColors.errorColor;
        } else {
          loginPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
        }
      }

      if (signUpConfirmedPasswordController.text.isEmpty) {
        confirmPasswordTextFieldBorderColor = AppColors.errorColor;
      } else {
        confirmPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
      }
    } else {
      if (login == false) {
        if (!isMatched || !passwordIsValid) {
          signUpEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
          signUpUsernameTextFieldBorderColor = AppColors.textFieldBorderColor;
          signUpPasswordTextFieldBorderColor = AppColors.errorColor;
          confirmPasswordTextFieldBorderColor = AppColors.errorColor;
        } else {
          signUpEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
          signUpPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
          signUpUsernameTextFieldBorderColor = AppColors.textFieldBorderColor;
          confirmPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
        }
      } else {
        loginPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
        loginEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
      }
      return;
    }
  }

  void toggleRememberMe() {
    rememberMe = !rememberMe;
  }

  bool _matchesRememberedEmail(String currentEmail, String rememberedEmail) {
    return currentEmail.isNotEmpty &&
        rememberedEmail.isNotEmpty &&
        currentEmail.toLowerCase() == rememberedEmail.toLowerCase();
  }

  Future<void> saveLoginInfo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final previousEmail = prefs.getString(_rememberedEmailKey);

    if (previousEmail != null && previousEmail.isNotEmpty && previousEmail != email) {
      await prefs.remove('$_legacySavedForPrefix$previousEmail');
    }
    await prefs.setString(_rememberedEmailKey, email);
    await prefs.remove('password');
    await prefs.setBool('$_legacySavedForPrefix$email', true);
  }

  Future<void> clearLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final previousEmail = prefs.getString(_rememberedEmailKey);

    if (previousEmail != null && previousEmail.isNotEmpty) {
      await prefs.remove('$_legacySavedForPrefix$previousEmail');
    }

    await prefs.remove(_rememberedEmailKey);
    await prefs.remove('password');
  }

  Future<void> getLoginInfo({String? preferredEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString(_rememberedEmailKey) ?? '';
    final email = (preferredEmail != null && preferredEmail.isNotEmpty)
        ? preferredEmail
        : rememberedEmail;
    loginEmailController.text = email;
    loginPasswordController.clear();
    rememberMe = _matchesRememberedEmail(email, rememberedEmail);
  }



  Future<void> completeOnboarding() async {
    await UsersProvider().markOnboardingCompleted();
  }

  Future<void> logout(UsersProvider usersProvider) async {
    await usersProvider.logout();

    final storedUsers = await usersProvider.getStoredDeviceUsers();
    if (storedUsers.isNotEmpty) {
      Get.offAll(() => const SelectUserScreen(firstScreen: false));
      return;
    }

    Get.offAll(() => const LoginScreen(firstScreen: false));
  }

  void clearTextFields() {
    signUpEmailController.clear();
    signUpUsernameController.clear();
    signUpPasswordController.clear();
    signUpConfirmedPasswordController.clear();
  }

  void resetSignUpState() {
    clearTextFields();
    signUpEmailTextFieldBorderColor = AppColors.textFieldBorderColor;
    signUpPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
    signUpUsernameTextFieldBorderColor = AppColors.textFieldBorderColor;
    confirmPasswordTextFieldBorderColor = AppColors.textFieldBorderColor;
    noneIsEmpty = true;
    isMatched = true;
    passwordIsValid = true;
  }
}
