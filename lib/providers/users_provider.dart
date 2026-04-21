import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../controllers/users_controller.dart';
import '../core/auth/social_auth_config.dart';
import '../core/constants/colors.dart';
import '../models/user.dart';
import '../services/sahifaty_api.dart';
import '../services/secure_session_storage.dart';
import '../services/users_services.dart';

class UsersProvider with ChangeNotifier {
  static final UsersProvider _instance = UsersProvider._internal();
  static const String _pendingVerificationEmailKey =
      'pending_verification_email';
  static const String _pendingVerificationSentAtKey =
      'pending_verification_sent_at_ms';

  factory UsersProvider() => _instance;

  UsersProvider._internal();

  User? selectedUser;
  String? pendingVerificationEmail;
  DateTime? pendingVerificationSentAt;

  final UsersServices _usersService = UsersServices();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool isLoading = false;
  bool isFirstLogin = false;
  bool showMemorizationColors = true;
  bool showComprehensionUnderline = true;
  bool _readingDisplayPreferencesLoaded = false;
  bool _googleInitialized = false;
  bool _facebookWebInitialized = false;

  String extractErrorMessage(Object error) {
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }

      if (message is List && message.isNotEmpty) {
        return message.join(', ');
      }

      if (message is Map) {
        final nestedMessage = message['message'];
        if (nestedMessage is String && nestedMessage.isNotEmpty) {
          return nestedMessage;
        }

        if (nestedMessage is List && nestedMessage.isNotEmpty) {
          return nestedMessage.join(', ');
        }
      }
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  bool get hasPendingVerification =>
      pendingVerificationEmail != null && pendingVerificationEmail!.isNotEmpty;

  Map<String, dynamic> _buildSocialAuthError(
    String code,
    String message, {
    String? provider,
    Map<String, dynamic>? extra,
  }) {
    return {
      'errorCode': code,
      'message': message,
      if (provider != null) 'provider': provider,
      ...?extra,
    };
  }

  Future<void> ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }

    if (!SocialAuthConfig.isGoogleConfiguredForCurrentPlatform) {
      throw _buildSocialAuthError(
        'SOCIAL_CONFIG_MISSING',
        kIsWeb
            ? 'Google web client ID is missing.'
            : 'Google Sign-In mobile configuration is missing.',
        provider: 'google',
      );
    }

    await _googleSignIn.initialize(
      clientId: SocialAuthConfig.googleClientIdOrNull,
      serverClientId: SocialAuthConfig.googleServerClientIdOrNull,
    );

    _googleInitialized = true;
  }

  Future<void> ensureFacebookInitialized() async {
    if (!kIsWeb || _facebookWebInitialized) {
      return;
    }

    if (!SocialAuthConfig.isFacebookConfiguredForCurrentPlatform) {
      throw _buildSocialAuthError(
        'SOCIAL_CONFIG_MISSING',
        'Facebook app ID is missing.',
        provider: 'facebook',
      );
    }

    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: SocialAuthConfig.facebookAppId,
      cookie: true,
      xfbml: true,
      version: SocialAuthConfig.facebookApiVersion,
    );

    _facebookWebInitialized = true;
  }

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

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    setLoading();
    try {
      final result = await _usersService.register(
        username: username,
        email: email,
        password: password,
      );

      await clearPersistedSession();
      await setPendingVerificationState(email, sentAt: DateTime.now());
      return result;
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

  Future<AuthData> finalizeAuthenticatedUser(AuthData authData) async {
    if (authData.user == null || authData.accessToken == null) {
      throw _buildSocialAuthError(
        'SOCIAL_AUTH_INVALID_RESPONSE',
        'Authentication response is incomplete.',
      );
    }

    final user = User(
      id: authData.user!.id,
      fullName: authData.user!.fullName,
      email: authData.user!.email,
      userRoleId: authData.user!.userRoleId,
    );

    setSelectedUser(user);
    await saveUserToDevice(user);
    await saveUserSession(
      user,
      authData.accessToken!,
      refreshToken: authData.refreshToken,
    );
    await clearPendingVerificationState();
    await checkFirstLogin();
    return authData;
  }

  Future<AuthData> signInWithGoogle() async {
    setLoading();
    try {
      await ensureGoogleInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw _buildSocialAuthError(
          'SOCIAL_PROVIDER_UNSUPPORTED',
          'Google interactive authentication is not supported on this platform.',
          provider: 'google',
        );
      }

      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw _buildSocialAuthError(
          'SOCIAL_ID_TOKEN_MISSING',
          'Could not retrieve Google identity token.',
          provider: 'google',
        );
      }

      return await signInWithGoogleIdToken(idToken, manageLoading: false);
    } on GoogleSignInException catch (error) {
      final code = switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'SOCIAL_LOGIN_CANCELLED',
        GoogleSignInExceptionCode.uiUnavailable =>
          'SOCIAL_PROVIDER_UNSUPPORTED',
        _ => 'SOCIAL_LOGIN_FAILED',
      };

      throw _buildSocialAuthError(
        code,
        error.description ?? 'Google sign-in failed.',
        provider: 'google',
      );
    } finally {
      resetLoading();
    }
  }

  Future<AuthData> signInWithGoogleIdToken(
    String idToken, {
    bool manageLoading = true,
  }) async {
    if (manageLoading) {
      setLoading();
    }

    try {
      final result = await _usersService.loginWithGoogle(idToken);
      if (result is! AuthData) {
        throw result;
      }

      return await finalizeAuthenticatedUser(result);
    } finally {
      if (manageLoading) {
        resetLoading();
      }
    }
  }

  Future<AuthData> signInWithFacebook() async {
    setLoading();
    try {
      await ensureFacebookInitialized();
      final LoginResult loginResult = await FacebookAuth.instance.login();
      if (loginResult.status == LoginStatus.success) {
        final AccessToken? accessToken = loginResult.accessToken;
        if (accessToken == null) {
          throw _buildSocialAuthError(
            'SOCIAL_ACCESS_TOKEN_MISSING',
            'Could not retrieve Facebook access token.',
            provider: 'facebook',
          );
        }
        return await signInWithFacebookAccessToken(
          accessToken.tokenString,
          manageLoading: false,
        );
      }

      if (loginResult.status == LoginStatus.cancelled) {
        throw _buildSocialAuthError(
          'SOCIAL_LOGIN_CANCELLED',
          'Facebook sign-in was cancelled.',
          provider: 'facebook',
        );
      }

      throw _buildSocialAuthError(
        'SOCIAL_LOGIN_FAILED',
        loginResult.message ?? 'Facebook sign-in failed.',
        provider: 'facebook',
      );
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<AuthData> signInWithFacebookAccessToken(
    String accessToken, {
    bool manageLoading = true,
  }) async {
    if (manageLoading) {
      setLoading();
    }

    try {
      final result = await _usersService.loginWithFacebook(accessToken);
      if (result is! AuthData) {
        throw result;
      }

      return await finalizeAuthenticatedUser(result);
    } finally {
      if (manageLoading) {
        resetLoading();
      }
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

  Future<void> loadPendingVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    pendingVerificationEmail = prefs.getString(_pendingVerificationEmailKey);
    final sentAtMs = prefs.getInt(_pendingVerificationSentAtKey);
    pendingVerificationSentAt =
        sentAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(sentAtMs);
    notifyListeners();
  }

  Future<void> setPendingVerificationState(
    String email, {
    DateTime? sentAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    pendingVerificationEmail = email;
    pendingVerificationSentAt = sentAt;
    await prefs.setString(_pendingVerificationEmailKey, email);
    if (sentAt == null) {
      await prefs.remove(_pendingVerificationSentAtKey);
    } else {
      await prefs.setInt(
        _pendingVerificationSentAtKey,
        sentAt.millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

  Future<void> clearPendingVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    pendingVerificationEmail = null;
    pendingVerificationSentAt = null;
    await prefs.remove(_pendingVerificationEmailKey);
    await prefs.remove(_pendingVerificationSentAtKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>> resendVerificationEmail({String? email}) async {
    final targetEmail = email ?? pendingVerificationEmail;
    if (targetEmail == null || targetEmail.isEmpty) {
      throw Exception('لا يوجد بريد محفوظ لإعادة الإرسال');
    }

    setLoading();
    try {
      final result = await _usersService.resendVerification(email: targetEmail);
      await setPendingVerificationState(targetEmail, sentAt: DateTime.now());
      return result;
    } catch (error) {
      if (error is Map) {
        final retryAfter = error['retryAfterSeconds'];
        if (retryAfter is int) {
          final adjustedSentAt =
              DateTime.now().subtract(Duration(seconds: 60 - retryAfter));
          await setPendingVerificationState(
            targetEmail,
            sentAt: adjustedSentAt,
          );
        }
      }
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<AuthData> verifyEmailToken(String token) async {
    setLoading();
    try {
      final result = await _usersService.verifyEmail(token: token);
      if (result is! AuthData || result.user == null) {
        throw result;
      }

      final user = User(
        id: result.user!.id,
        fullName: result.user!.fullName,
        email: result.user!.email,
        userRoleId: result.user!.userRoleId,
      );

      setSelectedUser(user);
      await saveUserToDevice(user);
      await saveUserSession(
        user,
        result.accessToken!,
        refreshToken: result.refreshToken,
      );
      await clearPendingVerificationState();
      return result;
    } finally {
      resetLoading();
    }
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
