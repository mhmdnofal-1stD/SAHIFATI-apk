import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../controllers/users_controller.dart';
import '../core/constants/colors.dart';
import '../models/user.dart';
import '../services/sahifaty_api.dart';
import '../services/secure_session_storage.dart';
import '../services/users_services.dart';

class UsersProvider with ChangeNotifier {
  static final UsersProvider _instance = UsersProvider._internal();

  factory UsersProvider() => _instance;

  UsersProvider._internal();

  User? selectedUser;

  final UsersServices _usersService = UsersServices();
  bool isLoading = false;
  bool isFirstLogin = false;
  bool showMemorizationColors = true;
  bool showComprehensionUnderline = true;
  bool _readingDisplayPreferencesLoaded = false;

  void _applyReadingDisplayPreferencesFromProfile(
      Map<String, dynamic> profile) {
    showMemorizationColors =
        profile['showMemorizationColors'] as bool? ?? true;
    showComprehensionUnderline =
        profile['showComprehensionUnderline'] as bool? ?? true;
  }

  void _resetReadingDisplayPreferencesState() {
    showMemorizationColors = true;
    showComprehensionUnderline = true;
    _readingDisplayPreferencesLoaded = false;
  }

  Future<void> ensureReadingDisplayPreferencesLoaded(
      {bool forceRefresh = false}) async {
    if (_readingDisplayPreferencesLoaded && !forceRefresh) {
      return;
    }

    try {
      final profile = await _usersService.getCurrentUserProfile();
      _applyReadingDisplayPreferencesFromProfile(profile);
    } catch (_) {
      showMemorizationColors = true;
      showComprehensionUnderline = true;
    }

    _readingDisplayPreferencesLoaded = true;
    notifyListeners();
  }

  Future<void> updateReadingDisplayPreferences({
    bool? showMemorizationColors,
    bool? showComprehensionUnderline,
  }) async {
    final previousShowMemorizationColors = this.showMemorizationColors;
    final previousShowComprehensionUnderline =
        this.showComprehensionUnderline;

    if (showMemorizationColors != null) {
      this.showMemorizationColors = showMemorizationColors;
    }
    if (showComprehensionUnderline != null) {
      this.showComprehensionUnderline = showComprehensionUnderline;
    }
    notifyListeners();

    try {
      final profile = await _usersService.updateCurrentUserProfile(
        showMemorizationColors: showMemorizationColors,
        showComprehensionUnderline: showComprehensionUnderline,
      );
      _applyReadingDisplayPreferencesFromProfile(profile);
      _readingDisplayPreferencesLoaded = true;
      notifyListeners();
    } catch (ex) {
      this.showMemorizationColors = previousShowMemorizationColors;
      this.showComprehensionUnderline =
          previousShowComprehensionUnderline;
      notifyListeners();
      rethrow;
    }
  }

  Future<AuthData> register(
      String username, String email, String password) async {
    setLoading();
    try {
      final result = await _usersService.register(
        username: username,
        email: email,
        password: password,
      );

      // result can be User or String error
      if (result is AuthData) {
        if (result.user != null) {
            await saveUserToDevice(result.user!);
        }
        return result;
      } else {
        // throw error to be caught in UI
        throw result;
      }
    } finally {
      resetLoading();
    }
  }

  Future<AuthData> login(String email, String password) async {
    setLoading();
    try {
      final result = await _usersService.login(
        email: email,
        password: password,
      );
      // result can be User or String error
      if (result is AuthData) {
         if (result.user != null) {
          await saveUserToDevice(result.user!);
        }
        return result;
      } else {
        throw result;
      }
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }


//   Future<AuthData> signInWithGoogle() async {
//     setLoading();
//     try {
//       final google_sign_in.GoogleSignIn googleSignIn =
//       google_sign_in.GoogleSignIn(scopes: ['email']);
//
//       final google_sign_in.GoogleSignInAccount? googleUser =
//       await googleSignIn.signIn();
// `
//       if (googleUser == null) throw 'Google Sign In aborted';
//
//       final google_sign_in.GoogleSignInAuthentication googleAuth =
//       await googleUser.authentication;
//
//       final String? idToken = googleAuth.idToken;
//
//       if (idToken == null) throw 'Could not retrieve ID Token';
//
//       final result = await _usersService.loginWithGoogle(idToken);
//       if (result is AuthData) return result;
//
//       throw result;
//     } finally {
//       resetLoading();
//     }
//   }

  Future<AuthData> signInWithFacebook() async {
    setLoading();
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();
      if (loginResult.status == LoginStatus.success) {
        final AccessToken? accessToken = loginResult.accessToken;
        if (accessToken == null) {
          throw 'Could not retrieve Access Token';
        }
        final result =
            await _usersService.loginWithFacebook(accessToken.tokenString);
        if (result is AuthData) {
          return result;
        } else {
          throw result;
        }
      } else {
        throw 'Facebook Sign In failed: ${loginResult.message}';
      }
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<void> logout() async {
    await _usersService.logout();
    await clearPersistedSession();
  }

  Future<void> clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('password');
    await SecureSessionStorage.clearSessionTokens();
    selectedUser = null;
    _resetReadingDisplayPreferencesState();
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(email) async {
    await _usersService.sendPasswordResetEmail(email);
  }

  Future<void> resetSignUpErrorText() async {
    UsersController().signUpEmailTextFieldBorderColor =
        AppColors.textFieldBorderColor;
    UsersController().signUpPasswordTextFieldBorderColor =
        AppColors.textFieldBorderColor;
    UsersController().confirmPasswordTextFieldBorderColor =
        AppColors.textFieldBorderColor;
    notifyListeners();
  }

  Future<void> resetLoginErrorText() async {
    UsersController().loginEmailTextFieldBorderColor =
        AppColors.textFieldBorderColor;
    UsersController().loginPasswordTextFieldBorderColor =
        AppColors.textFieldBorderColor;
    notifyListeners();
  }

  void setLoading() {
    isLoading = true;
    notifyListeners();
  }

  void resetLoading() {
    isLoading = false;
    notifyListeners();
  }

  void setSelectedUser(User user) {
    selectedUser = user;
    _resetReadingDisplayPreferencesState();
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('userData')) {
        return false;
      }

      final accessToken = await SecureSessionStorage.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        await clearPersistedSession();
        return false;
      }

      final extractedUserData =
      json.decode(prefs.getString('userData')!) as Map<String, dynamic>;
      
      selectedUser = User.fromJson(extractedUserData);
      notifyListeners();
      return true;
    } catch (_) {
      await clearPersistedSession();
      return false;
    }
  }

  Future<void> saveUserSession(User user, String accessToken,
      {String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = json.encode(user.toMap());
    await prefs.setString('userData', userData);
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('password');
    await SecureSessionStorage.writeSessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    _resetReadingDisplayPreferencesState();
  }

  Future<void> checkFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';

    isFirstLogin = email == '';
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    setLoading();
    try {
      final response = await SahifatyApi().delete('users/${selectedUser!.id}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Clear all user data
        await logout();
      } else {
        final responseData = json.decode(response.body);
        throw responseData['message'] ?? 'Failed to delete account';
      }
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }

  // --- Stored Device Users Management ---

  Future<void> saveUserToDevice(User user) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Fetch existing users
    final String? storedUsersStr = prefs.getString('stored_device_users');
    List<dynamic> storedUsersList = [];
    if (storedUsersStr != null) {
      storedUsersList = json.decode(storedUsersStr);
    }

    // Check if user already exists
    final int existingIndex = storedUsersList.indexWhere((element) => element['email'] == user.email);
    
    final Map<String, dynamic> userMap = user.toMap();

    if (existingIndex != -1) {
      // Update existing
      storedUsersList[existingIndex] = userMap;
    } else {
      // Add new
      storedUsersList.add(userMap);
    }

    await prefs.setString('stored_device_users', json.encode(storedUsersList));
  }

  Future<List<Map<String, dynamic>>> getStoredDeviceUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedUsersStr = prefs.getString('stored_device_users');
    if (storedUsersStr != null) {
      List<dynamic> decodedList = json.decode(storedUsersStr);
      return decodedList.cast<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<void> removeUserFromDevice(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedUsersStr = prefs.getString('stored_device_users');
    
    if (storedUsersStr != null) {
      List<dynamic> storedUsersList = json.decode(storedUsersStr);
      storedUsersList.removeWhere((element) => element['email'] == email);
      
      // Save updated list back
      await prefs.setString('stored_device_users', json.encode(storedUsersList));
    }
  }
}
