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
  static const String _legacyHasLoggedInBeforeKey = 'has_logged_in_before';
  static const String _legacyOnboardingCompleteKey = 'onboarding_complete';
  static const String _storedDeviceUsersKey = 'stored_device_users';
  static const String _storedAccountSessionsKey = 'stored_account_sessions';
  static const String _activeUserDataKey = 'userData';

  factory UsersProvider() => _instance;

  UsersProvider._internal();

  User? selectedUser;
  String? pendingVerificationEmail;
  DateTime? pendingVerificationSentAt;

  final UsersServices _usersService = UsersServices();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool isLoading = false;
  bool isProfileLoading = false;
  bool isFirstLogin = false;
  bool showMemorizationColors = true;
  bool showComprehensionUnderline = true;
  bool _readingDisplayPreferencesLoaded = false;
  bool _googleInitialized = false;
  bool _facebookWebInitialized = false;

  String _accountKeyForUser(User user) => user.id.toString();

  String _onboardingCompletionKeyForUser(User user) =>
      '${_legacyOnboardingCompleteKey}_${_accountKeyForUser(user)}';

  String? _accountKeyFromUserMap(Map<String, dynamic> userMap) {
    final id = userMap['id'];
    if (id == null) {
      return null;
    }

    return id.toString();
  }

  Map<String, dynamic> _buildStoredSessionRecord(User user) {
    return {
      'user': user.toMap(),
      'lastUsedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _readStoredAccountSessions(
    SharedPreferences prefs,
  ) async {
    final storedSessionsStr = prefs.getString(_storedAccountSessionsKey);
    if (storedSessionsStr == null || storedSessionsStr.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = json.decode(storedSessionsStr);
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _writeStoredAccountSessions(
    SharedPreferences prefs,
    Map<String, dynamic> sessions,
  ) async {
    if (sessions.isEmpty) {
      await prefs.remove(_storedAccountSessionsKey);
      return;
    }

    await prefs.setString(_storedAccountSessionsKey, json.encode(sessions));
  }

  Future<void> _setActiveUserSnapshot(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUserDataKey, json.encode(user.toMap()));
  }

  Future<void> _removeActiveUserSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeUserDataKey);
  }

  Future<void> _migrateLegacySessionIfNeeded(SharedPreferences prefs) async {
    final legacyUserData = prefs.getString(_activeUserDataKey);
    if (legacyUserData == null || legacyUserData.isEmpty) {
      return;
    }

    try {
      final decodedUser = json.decode(legacyUserData) as Map<String, dynamic>;
      final user = User.fromJson(decodedUser);
      final accountKey = _accountKeyForUser(user);
      final sessions = await _readStoredAccountSessions(prefs);

      sessions[accountKey] ??= _buildStoredSessionRecord(user);
      await _writeStoredAccountSessions(prefs, sessions);
      await saveUserToDevice(user);
      await SecureSessionStorage.migrateLegacySessionToAccount(accountKey);

      final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
      if (activeAccountKey == null || activeAccountKey.isEmpty) {
        await SecureSessionStorage.setActiveAccountKey(accountKey);
      }
    } catch (_) {
      await prefs.remove(_activeUserDataKey);
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
    }
  }

  Future<void> _removeStoredSessionByAccountKey(
    String accountKey, {
    bool notify = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _readStoredAccountSessions(prefs);
    sessions.remove(accountKey);
    await _writeStoredAccountSessions(prefs, sessions);
    await SecureSessionStorage.deleteAccountSessionTokens(accountKey);

    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    if (activeAccountKey == null || activeAccountKey == accountKey) {
      await _removeActiveUserSnapshot();
      selectedUser = null;
      _resetReadingDisplayPreferencesState();
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> _persistAccountSession(
    User user,
    String accessToken, {
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _readStoredAccountSessions(prefs);
    final accountKey = _accountKeyForUser(user);

    sessions[accountKey] = _buildStoredSessionRecord(user);
    await _writeStoredAccountSessions(prefs, sessions);
    await SecureSessionStorage.writeAccountSessionTokens(
      accountKey: accountKey,
      accessToken: accessToken,
      refreshToken: refreshToken,
      setActive: true,
    );
    await _setActiveUserSnapshot(user);
  }

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
    String email,
    String password, {
    String? username,
  }) async {
    setLoading();
    try {
      final result = await _usersService.register(
        email: email,
        password: password,
        username: username,
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
    await _migrateLegacySessionIfNeeded(prefs);
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();

    if (activeAccountKey != null && activeAccountKey.isNotEmpty) {
      await _removeStoredSessionByAccountKey(activeAccountKey);
    }

    await prefs.remove(_activeUserDataKey);
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('password');
    await SecureSessionStorage.setActiveAccountKey(null);
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

  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    return requestPasswordReset(email);
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    setLoading();
    try {
      return await _usersService.requestPasswordReset(email: email);
    } finally {
      resetLoading();
    }
  }

  Future<Map<String, dynamic>> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    setLoading();
    try {
      return await _usersService.completePasswordReset(
        token: token,
        newPassword: newPassword,
      );
    } finally {
      resetLoading();
    }
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

  Future<void> _persistSelectedUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    selectedUser = user;
    await prefs.setString('userData', json.encode(user.toMap()));
    await saveUserToDevice(user);
  }

  Future<User?> loadCurrentUserProfile() async {
    isProfileLoading = true;
    notifyListeners();

    try {
      final profile = await _usersService.getCurrentUserProfile();
      final normalizedProfile = <String, dynamic>{
        ...profile,
        'id': profile['id'] ?? profile['_id'] ?? selectedUser?.id,
        'email': profile['email'] ?? selectedUser?.email ?? '',
        'fullName': profile['fullName'] ?? selectedUser?.fullName ?? '',
        'userRoleId': profile['userRoleId'] ?? selectedUser?.userRoleId,
      };
      final user = User.fromJson(normalizedProfile);
      await _persistSelectedUser(user);
      _applyReadingDisplayPreferencesFromProfile(profile);
      _readingDisplayPreferencesLoaded = true;
      notifyListeners();
      return user;
    } finally {
      isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<User> updateStructuredProfile({
    required String fullName,
    required String gender,
    required int birthYear,
    required String country,
    required int countryCode,
    required String city,
    String? mobile,
    String? educationLevel,
    String? workType,
  }) async {
    isProfileLoading = true;
    notifyListeners();

    try {
      final profile = await _usersService.updateCurrentUserProfile(
        fullName: fullName,
        gender: gender,
        birthYear: birthYear,
        country: country,
        countryCode: countryCode,
        city: city,
        mobile: mobile,
        educationLevel: educationLevel,
        workType: workType,
      );

      final normalizedProfile = <String, dynamic>{
        ...profile,
        'id': profile['id'] ?? profile['_id'] ?? selectedUser?.id,
        'email': profile['email'] ?? selectedUser?.email ?? '',
        'fullName': profile['fullName'] ?? fullName,
        'userRoleId': profile['userRoleId'] ?? selectedUser?.userRoleId,
      };
      final user = User.fromJson(normalizedProfile);
      await _persistSelectedUser(user);
      _applyReadingDisplayPreferencesFromProfile(profile);
      _readingDisplayPreferencesLoaded = true;
      notifyListeners();
      return user;
    } finally {
      isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacySessionIfNeeded(prefs);

      final sessions = await _readStoredAccountSessions(prefs);
      if (sessions.isEmpty) {
        return false;
      }

      String? activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
      if (activeAccountKey == null || activeAccountKey.isEmpty) {
        activeAccountKey = sessions.keys.first;
        await SecureSessionStorage.setActiveAccountKey(activeAccountKey);
      }

      final sessionRecord = sessions[activeAccountKey];
      if (sessionRecord is! Map<String, dynamic>) {
        await _removeStoredSessionByAccountKey(activeAccountKey);
        return false;
      }

      final accessToken = await SecureSessionStorage.readAccessToken(
        accountKey: activeAccountKey,
      );
      if (accessToken == null || accessToken.isEmpty) {
        await _removeStoredSessionByAccountKey(activeAccountKey, notify: true);
        return false;
      }

      final extractedUserData =
          Map<String, dynamic>.from(sessionRecord['user'] as Map);

      selectedUser = User.fromJson(extractedUserData);
      await _setActiveUserSnapshot(selectedUser!);
        await checkFirstLogin(user: selectedUser);
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
    await _persistAccountSession(
      user,
      accessToken,
      refreshToken: refreshToken,
    );
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('password');
    _resetReadingDisplayPreferencesState();
  }

  Future<bool> isOnboardingCompleted({User? user}) async {
    final targetUser = user ?? selectedUser;
    if (targetUser == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _onboardingCompletionKeyForUser(targetUser);
    final scopedValue = prefs.getBool(scopedKey);
    if (scopedValue != null) {
      return scopedValue;
    }

    final legacyScopedLoginFlag =
        prefs.getBool('${_legacyHasLoggedInBeforeKey}_${_accountKeyForUser(targetUser)}');
    if (legacyScopedLoginFlag == true) {
      await prefs.setBool(scopedKey, true);
      return true;
    }

    final legacyOnboardingComplete = prefs.getBool(_legacyOnboardingCompleteKey);
    if (legacyOnboardingComplete == true) {
      await prefs.setBool(scopedKey, true);
      return true;
    }

    return false;
  }

  Future<void> markOnboardingCompleted({User? user}) async {
    final targetUser = user ?? selectedUser;
    if (targetUser == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletionKeyForUser(targetUser), true);

    if (selectedUser?.id == targetUser.id) {
      isFirstLogin = false;
      notifyListeners();
    }
  }

  Future<void> checkFirstLogin({User? user}) async {
    final targetUser = user ?? selectedUser;
    if (targetUser == null) {
      isFirstLogin = false;
      notifyListeners();
      return;
    }

    final onboardingCompleted = await isOnboardingCompleted(user: targetUser);
    isFirstLogin = !onboardingCompleted;
    notifyListeners();
  }

  Future<bool> switchToStoredUser(Map<String, dynamic> userData) async {
    final accountKey = _accountKeyFromUserMap(userData);
    if (accountKey == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacySessionIfNeeded(prefs);
    final sessions = await _readStoredAccountSessions(prefs);
    final sessionRecord = sessions[accountKey];
    if (sessionRecord is! Map<String, dynamic>) {
      return false;
    }

    final accessToken = await SecureSessionStorage.readAccessToken(
      accountKey: accountKey,
    );
    if (accessToken == null || accessToken.isEmpty) {
      await _removeStoredSessionByAccountKey(accountKey, notify: true);
      return false;
    }

    final user = User.fromJson(Map<String, dynamic>.from(sessionRecord['user'] as Map));
    await SecureSessionStorage.setActiveAccountKey(accountKey);
    await _setActiveUserSnapshot(user);
    selectedUser = user;
    _resetReadingDisplayPreferencesState();
    await checkFirstLogin(user: user);
    notifyListeners();
    return true;
  }

  Future<bool> hasStoredSessionForUser(Map<String, dynamic> userData) async {
    final accountKey = _accountKeyFromUserMap(userData);
    if (accountKey == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacySessionIfNeeded(prefs);
    final sessions = await _readStoredAccountSessions(prefs);
    return sessions.containsKey(accountKey);
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
    final String? storedUsersStr = prefs.getString(_storedDeviceUsersKey);
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

    await prefs.setString(_storedDeviceUsersKey, json.encode(storedUsersList));
  }

  Future<List<Map<String, dynamic>>> getStoredDeviceUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacySessionIfNeeded(prefs);
    final sessions = await _readStoredAccountSessions(prefs);
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    final String? storedUsersStr = prefs.getString(_storedDeviceUsersKey);
    if (storedUsersStr != null) {
      List<dynamic> decodedList = json.decode(storedUsersStr);
      final users = decodedList.map<Map<String, dynamic>>((rawUser) {
        final userMap = Map<String, dynamic>.from(rawUser as Map);
        final accountKey = _accountKeyFromUserMap(userMap);
        return {
          ...userMap,
          'hasActiveSession':
              accountKey != null && sessions.containsKey(accountKey),
          'isCurrent': accountKey != null && accountKey == activeAccountKey,
        };
      }).toList();

      users.sort((a, b) {
        final currentA = a['isCurrent'] == true ? 1 : 0;
        final currentB = b['isCurrent'] == true ? 1 : 0;
        if (currentA != currentB) {
          return currentB.compareTo(currentA);
        }

        final activeA = a['hasActiveSession'] == true ? 1 : 0;
        final activeB = b['hasActiveSession'] == true ? 1 : 0;
        if (activeA != activeB) {
          return activeB.compareTo(activeA);
        }

        return (a['fullName'] ?? '').toString().compareTo(
              (b['fullName'] ?? '').toString(),
            );
      });

      return users;
    }
    return [];
  }

  Future<void> removeUserFromDevice(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedUsersStr = prefs.getString(_storedDeviceUsersKey);
    
    if (storedUsersStr != null) {
      List<dynamic> storedUsersList = json.decode(storedUsersStr);
      final dynamic removedUser = storedUsersList.cast<dynamic>().firstWhere(
            (element) => element['email'] == email,
            orElse: () => null,
          );
      storedUsersList.removeWhere((element) => element['email'] == email);

      // Save updated list back
      await prefs.setString(_storedDeviceUsersKey, json.encode(storedUsersList));

      if (removedUser is Map) {
        final accountKey = _accountKeyFromUserMap(
          Map<String, dynamic>.from(removedUser),
        );
        if (accountKey != null) {
          await _removeStoredSessionByAccountKey(accountKey, notify: true);
        }
      }
    }
  }
}
