import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:huawei_account/huawei_account.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../controllers/users_controller.dart';
import '../core/auth/huawei_web_auth_flow.dart';
import '../core/auth/huawei_web_oauth.dart';
import '../core/auth/social_auth_config.dart';
import '../core/constants/colors.dart';
import '../models/user_notification_item.dart';
import '../models/user.dart';
import '../services/push_notifications_service.dart';
import '../services/app_exception.dart';
import '../services/initial_data_sync_service.dart';
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
  static const String _manualLogoutKey = 'manual_logout_with_stored_sessions';

  factory UsersProvider() => _instance;

  UsersProvider._internal();

  User? selectedUser;
  User? _previousUser;
  bool _isViewingDelegatedUser = false;
  String? pendingVerificationEmail;
  DateTime? pendingVerificationSentAt;

  final UsersServices _usersService = UsersServices();
    final InitialDataSyncService _initialDataSyncService =
      InitialDataSyncService();
  final PushNotificationsService _pushNotificationsService =
      PushNotificationsService();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<String>? _pushTokenRefreshSubscription;
  bool isLoading = false;
  bool isProfileLoading = false;
  bool isLicenseLoading = false;
  bool isPromoCodesLoading = false;
  bool isNotificationsLoading = false;
  bool isFirstLogin = false;
  bool showMemorizationColors = true;
  bool showComprehensionUnderline = true;
  bool _readingDisplayPreferencesLoaded = false;
  bool _googleInitialized = false;
  bool _facebookWebInitialized = false;
  Map<String, dynamic>? licenseBalanceSummary;
  Map<String, dynamic>? giftPoolSummary;
  String? promoWorkspaceError;
  List<Map<String, dynamic>> myPromoCodes = <Map<String, dynamic>>[];
  List<UserNotificationItem> notifications = <UserNotificationItem>[];
  int unreadNotificationsCount = 0;
  bool _notificationsLoaded = false;
  String? _lastRegisteredPushToken;
  int? _lastRegisteredPushUserId;
  bool _pushTokenSyncInFlight = false;

  @visibleForTesting
  Future<AuthData?> Function(String refreshToken)? debugRefreshTokensOverride;

  String _accountKeyForUser(User user) => user.accountKey;

  String _onboardingCompletionKeyForUser(User user) =>
      '${_legacyOnboardingCompleteKey}_${_accountKeyForUser(user)}';

  String? _accountKeyFromUserMap(Map<String, dynamic> userMap) {
    final accountKey = deriveUserAccountKeyFromMap(userMap).trim();
    return accountKey.isEmpty ? null : accountKey;
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

  Future<List<Map<String, dynamic>>> _readStoredDeviceUsersList(
    SharedPreferences prefs,
  ) async {
    final storedUsersStr = prefs.getString(_storedDeviceUsersKey);
    if (storedUsersStr == null || storedUsersStr.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = json.decode(storedUsersStr);
      if (decoded is! List) {
        await prefs.remove(_storedDeviceUsersKey);
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((rawUser) => Map<String, dynamic>.from(rawUser))
          .toList();
    } catch (_) {
      await prefs.remove(_storedDeviceUsersKey);
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _setActiveUserSnapshot(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUserDataKey, json.encode(user.toMap()));

    final sessions = await _readStoredAccountSessions(prefs);
    final accountKey = _accountKeyForUser(user);
    final sessionRecord = sessions[accountKey];
    if (sessionRecord is Map<String, dynamic>) {
      sessions[accountKey] = {
        ...sessionRecord,
        'user': user.toMap(),
        'lastUsedAt': DateTime.now().toIso8601String(),
      };
      await _writeStoredAccountSessions(prefs, sessions);
    }
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

      final activeAccountKey =
          await SecureSessionStorage.readActiveAccountKey();
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
    await prefs.remove(_manualLogoutKey);
    await _setActiveUserSnapshot(user);
  }

  Future<AuthData?> _refreshTokensForSession(String refreshToken) {
    final override = debugRefreshTokensOverride;
    if (override != null) {
      return override(refreshToken);
    }

    return _usersService.refreshTokens(refreshToken);
  }

  Future<String?> _ensureValidAccessTokenForAccount(
    String accountKey, {
    bool notifyOnFailure = true,
  }) async {
    final accessToken = await SecureSessionStorage.readAccessToken(
      accountKey: accountKey,
    );
    if (SecureSessionStorage.isAccessTokenUsable(accessToken)) {
      return accessToken;
    }

    final refreshToken = await SecureSessionStorage.readRefreshToken(
      accountKey: accountKey,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      // No refresh token stored at all — definitive auth failure.
      await _removeStoredSessionByAccountKey(accountKey,
          notify: notifyOnFailure);
      return null;
    }

    // Attempt to exchange the refresh token for a new access token.
    // _refreshTokensForSession throws FetchDataException on network/timeout
    // errors and returns null when the server explicitly rejects the token.
    // Only clear the stored session in the latter case; transient network
    // failures must leave the session intact so the user is not silently
    // signed out due to a momentary connectivity problem.
    AuthData? refreshed;
    try {
      refreshed = await _refreshTokensForSession(refreshToken);
    } catch (_) {
      // Network or transient error — keep session alive, let caller handle.
      return null;
    }

    final refreshedAccessToken = refreshed?.accessToken;
    if (refreshedAccessToken == null || refreshedAccessToken.isEmpty) {
      // Server responded but explicitly rejected the refresh token.
      await _removeStoredSessionByAccountKey(accountKey,
          notify: notifyOnFailure);
      return null;
    }

    await SecureSessionStorage.writeAccountSessionTokens(
      accountKey: accountKey,
      accessToken: refreshedAccessToken,
      refreshToken: refreshed?.refreshToken ?? refreshToken,
      setActive: false,
    );
    return refreshedAccessToken;
  }

  String extractErrorMessage(Object error) {
    final errorCode = _extractErrorCode(error);
    final localizedByCode = _localizedErrorMessageForCode(
      errorCode,
      error,
    );
    if (localizedByCode != null) {
      return localizedByCode;
    }

    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return _localizeBackendMessage(message, error: error);
      }

      if (message is List && message.isNotEmpty) {
        return message
            .map((item) =>
                _localizeBackendMessage(item.toString(), error: error))
            .join(', ');
      }

      if (message is Map) {
        final nestedMessage = message['message'];
        if (nestedMessage is String && nestedMessage.isNotEmpty) {
          return _localizeBackendMessage(nestedMessage, error: error);
        }

        if (nestedMessage is List && nestedMessage.isNotEmpty) {
          return nestedMessage
              .map((item) =>
                  _localizeBackendMessage(item.toString(), error: error))
              .join(', ');
        }
      }
    }

    final fallback = error.toString().replaceFirst('Exception: ', '');
    return _localizeBackendMessage(fallback, error: error);
  }

  String? _extractErrorCode(Object error) {
    if (error is! Map) {
      return null;
    }

    final directCode = error['errorCode'];
    if (directCode is String && directCode.isNotEmpty) {
      return directCode;
    }

    final message = error['message'];
    if (message is Map) {
      final nestedCode = message['errorCode'];
      if (nestedCode is String && nestedCode.isNotEmpty) {
        return nestedCode;
      }
    }

    return null;
  }

  String? _localizedErrorMessageForCode(String? errorCode, Object error) {
    if (errorCode == null || errorCode.isEmpty) {
      return null;
    }

    switch (errorCode) {
      case 'ACCOUNT_NOT_VERIFIED':
        return 'auth_account_not_verified'.tr;
      case 'LICENSE_REQUIRED':
        return 'auth_license_required'.tr;
      case 'VERIFICATION_EMAIL_UNAVAILABLE':
        return 'auth_registration_verification_email_unavailable'.tr;
      case 'ACCOUNT_EXISTS_WITH_PASSWORD':
        return 'social_account_exists_with_password'.tr;
      case 'ACCOUNT_EXISTS_WITH_DIFFERENT_PROVIDER':
        final provider = error is Map ? error['existingProvider'] : null;
        return 'social_account_exists_with_different_provider'.trParams({
          'provider': _providerLabel((provider ?? 'provider').toString()),
        });
      case 'SOCIAL_ACCOUNT_ALREADY_LINKED':
        return 'social_account_already_linked'.tr;
      case 'CHILD_PIN_NOT_SET':
        return 'child_pin_not_set'.tr;
      default:
        return null;
    }
  }

  String _localizeBackendMessage(String rawMessage, {Object? error}) {
    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed == 'invalid credentials' || trimmed == 'Invalid credentials') {
      return 'invalid_credentials'.tr;
    }

    if (trimmed == 'User with this email already exists' ||
        trimmed.toLowerCase().contains('email already in use')) {
      return 'email_taken'.tr;
    }

    if (trimmed == 'Please verify your email before logging in.') {
      return 'auth_account_not_verified'.tr;
    }

    if (trimmed == 'An active license is required to access this feature.') {
      return 'auth_license_required'.tr;
    }

    if (trimmed ==
        'Not enough owned licenses are available to contribute to the gift pool.') {
      return 'license_hub_gift_pool_not_enough'.tr;
    }

    if (trimmed == 'Please verify your email before managing promo codes.') {
      return 'license_hub_gift_pool_verify_email'.tr;
    }

    if (trimmed ==
        'Please verify your email before contributing licenses to the gift pool.') {
      return 'license_hub_gift_pool_verify_email'.tr;
    }

    if (trimmed ==
        'This account uses social authentication. Please use the social login option.') {
      return 'auth_login_use_social_auth'.tr;
    }

    if (trimmed ==
        'Registration is temporarily unavailable because the verification email could not be sent. Please try again shortly.') {
      return 'auth_registration_verification_email_unavailable'.tr;
    }

    if (trimmed == 'This account is already verified.') {
      return 'email_verification_pending_already_verified'.tr;
    }

    if (trimmed ==
        'If that email exists and is unverified, a new email has been sent.') {
      return 'email_verification_pending_resend_success'.tr;
    }

    if (trimmed ==
        'If that email exists and can reset its password, a password reset email has been sent.') {
      return 'forgot_password_request_accepted_body'.tr;
    }

    if (trimmed == 'Password reset completed successfully.' ||
        trimmed == 'Password changed successfully') {
      return 'forgot_password_reset_success_body'.tr;
    }

    if (trimmed == 'Password reset token is invalid or has expired.') {
      return 'forgot_password_reset_expired_body'.tr;
    }

    if (trimmed == 'Verification token is invalid or has expired.') {
      return 'email_verification_result_expired_body'.tr;
    }

    if (trimmed == 'password must contain at least one uppercase letter') {
      return 'auth_password_validation_uppercase'.tr;
    }

    if (trimmed == 'password must contain at least one lowercase letter') {
      return 'auth_password_validation_lowercase'.tr;
    }

    if (trimmed == 'password must contain at least one number') {
      return 'auth_password_validation_number'.tr;
    }

    if (trimmed == 'password must contain at least one symbol') {
      return 'auth_password_validation_symbol'.tr;
    }

    if (trimmed == 'child_pin_not_set') {
      return 'child_pin_not_set'.tr;
    }

    if (trimmed == 'child_name_taken') {
      return 'child_name_taken'.tr;
    }

    if (trimmed == 'child_login_child_name_required') {
      return 'child_login_child_name_required'.tr;
    }

    if (trimmed.startsWith('Please wait ') &&
        trimmed.contains(
            ' seconds before requesting another verification email.')) {
      final seconds =
          RegExp(r'Please wait (\d+) seconds').firstMatch(trimmed)?.group(1);
      if (seconds != null) {
        return 'email_verification_pending_resend_wait'.trParams({
          'seconds': seconds,
        });
      }
    }

    return trimmed;
  }

  bool isExpiredVerificationError(Object error) {
    final raw = _extractRawMessage(error).toLowerCase();
    return raw.contains('verification token is invalid or has expired') ||
        raw.contains('expired');
  }

  bool isExpiredPasswordResetError(Object error) {
    final raw = _extractRawMessage(error).toLowerCase();
    if (raw.contains('password reset token is invalid or has expired')) {
      return true;
    }

    if (raw.contains('already used')) {
      return true;
    }

    if (raw.contains('invalid or has expired')) {
      return true;
    }

    if (error is Map) {
      final statusCode = error['statusCode'];
      if (statusCode == 400) {
        return true;
      }
    }

    return false;
  }

  String _extractRawMessage(Object error) {
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

  bool _isUnauthorizedError(Object error) {
    if (error is Map) {
      final statusCode = error['statusCode'];
      if (statusCode == 401) {
        return true;
      }
    }

    final raw = _extractRawMessage(error).toLowerCase();
    return raw.contains('unauthorized') || raw.contains('unauthenticated');
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'social_provider_google'.tr;
      case 'facebook':
        return 'social_provider_facebook'.tr;
      case 'apple':
        return 'Apple';
      case 'huawei':
        return 'social_provider_huawei'.tr;
      default:
        return provider;
    }
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
            ? 'social_google_requires_client_id'.tr
            : 'social_google_requires_mobile_config'.tr,
        provider: 'google',
      );
    }

    await _googleSignIn.initialize(
      clientId: kIsWeb ? SocialAuthConfig.googleClientIdOrNull : null,
      serverClientId: kIsWeb
          ? null
          : SocialAuthConfig.googleServerClientIdOrNull ??
              SocialAuthConfig.googleClientIdOrNull,
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
        'social_facebook_requires_app_id'.tr,
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

  Future<AuthData> signInWithApple() async {
    setLoading();
    try {
      if (!SocialAuthConfig.isAppleConfiguredForCurrentPlatform) {
        throw _buildSocialAuthError(
          'SOCIAL_CONFIG_MISSING',
          'social_apple_requires_web_config'.tr,
          provider: 'apple',
        );
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.android)
            ? WebAuthenticationOptions(
                clientId: SocialAuthConfig.appleWebClientId,
                redirectUri:
                    SocialAuthConfig.appleRedirectUriForCurrentPlatform!,
              )
            : null,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw _buildSocialAuthError(
          'SOCIAL_ID_TOKEN_MISSING',
          'social_missing_id_token'.tr,
          provider: 'apple',
        );
      }

      return await signInWithAppleIdentityToken(
        identityToken,
        manageLoading: false,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw _buildSocialAuthError(
          'SOCIAL_LOGIN_CANCELLED',
          'social_cancelled'.tr,
          provider: 'apple',
        );
      }

      if (error.code == AuthorizationErrorCode.invalidResponse) {
        throw _buildSocialAuthError(
          'SOCIAL_AUTH_INVALID_RESPONSE',
          'social_auth_invalid_response'.tr,
          provider: 'apple',
        );
      }

      throw _buildSocialAuthError(
        'SOCIAL_LOGIN_FAILED',
        '${'social_apple_sign_in_failed'.tr} (${error.code})',
        provider: 'apple',
      );
    } catch (e) {
      // Extract the Apple error code if available (e.g., popup_blocked_by_browser,
      // user_cancelled_authorize, invalid_client)
      String detail = '';
      try {
        // sign_in_with_apple_web wraps errors as SignInWithAppleCredentialsException
        // with message like "Authentication failed with <code>"
        final msg = e.toString();
        if (msg.contains('Authentication failed with')) {
          detail = ' (${msg.replaceAll('Authentication failed with ', '').trim()})';
        } else if (msg.isNotEmpty && msg.length < 80) {
          detail = ' ($msg)';
        }
      } catch (_) {}
      throw _buildSocialAuthError(
        'SOCIAL_LOGIN_FAILED',
        '${'social_apple_sign_in_failed'.tr}$detail',
        provider: 'apple',
      );
    } finally {
      resetLoading();
    }
  }

  Future<AuthData> signInWithAppleIdentityToken(
    String identityToken, {
    bool manageLoading = true,
  }) async {
    if (manageLoading) {
      setLoading();
    }

    try {
      final result = await _usersService.loginWithApple(identityToken);
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

  void _applyReadingDisplayPreferencesFromProfile(
      Map<String, dynamic> profile) {
    showMemorizationColors = profile['showMemorizationColors'] as bool? ?? true;
    showComprehensionUnderline =
        profile['showComprehensionUnderline'] as bool? ?? true;
    // Mirror back into the typed User model so all readers stay in sync
    if (selectedUser != null) {
      selectedUser!.showMemorizationColors = showMemorizationColors;
      selectedUser!.showComprehensionUnderline = showComprehensionUnderline;
    }
  }

  void _resetReadingDisplayPreferencesState() {
    showMemorizationColors = true;
    showComprehensionUnderline = true;
    _readingDisplayPreferencesLoaded = false;
  }

  void _resetNotificationsState() {
    notifications = <UserNotificationItem>[];
    unreadNotificationsCount = 0;
    isNotificationsLoading = false;
    _notificationsLoaded = false;
  }

  void _resetPushNotificationsSession({bool cancelSubscription = false}) {
    if (cancelSubscription) {
      _pushTokenRefreshSubscription?.cancel();
      _pushTokenRefreshSubscription = null;
    }

    _lastRegisteredPushToken = null;
    _lastRegisteredPushUserId = null;
    _pushTokenSyncInFlight = false;
  }

  String _resolvePushPlatform() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  Future<void> _bootstrapPushNotificationsForCurrentUser() async {
    if (selectedUser == null) {
      return;
    }

    try {
      await _pushNotificationsService.ensureInitialized();
      _pushTokenRefreshSubscription ??=
          _pushNotificationsService.onTokenRefresh.listen(
        (token) => unawaited(_syncPushTokenForCurrentUser(token)),
      );

      final token = await _pushNotificationsService.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _syncPushTokenForCurrentUser(token);
      }
    } catch (error) {
      debugPrint('Push notification bootstrap skipped: $error');
    }
  }

  Future<void> _syncPushTokenForCurrentUser(String rawToken) async {
    final user = selectedUser;
    final token = rawToken.trim();
    if (user == null || token.isEmpty) {
      return;
    }

    if (_lastRegisteredPushUserId == user.id &&
        _lastRegisteredPushToken == token) {
      return;
    }

    if (_pushTokenSyncInFlight) {
      return;
    }

    _pushTokenSyncInFlight = true;
    try {
      await _usersService.registerPushToken(
        token: token,
        platform: _resolvePushPlatform(),
        locale: Get.locale?.languageCode,
      );

      _lastRegisteredPushToken = token;
      _lastRegisteredPushUserId = user.id;
    } catch (error) {
      debugPrint('Push token sync failed: $error');
    } finally {
      _pushTokenSyncInFlight = false;
    }
  }

  Future<void> ensureReadingDisplayPreferencesLoaded(
      {bool forceRefresh = false}) async {
    if (_readingDisplayPreferencesLoaded && !forceRefresh) {
      return;
    }

    if (selectedUser == null) {
      showMemorizationColors = true;
      showComprehensionUnderline = true;
      _readingDisplayPreferencesLoaded = true;
      notifyListeners();
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

  Future<void> ensureNotificationsLoaded({bool forceRefresh = false}) async {
    if (selectedUser == null) {
      _resetNotificationsState();
      notifyListeners();
      return;
    }

    if (_notificationsLoaded && !forceRefresh) {
      return;
    }

    if (!forceRefresh) {
      final cachedPayload = await _usersService.getCachedNotificationsPayload();
      if (cachedPayload != null) {
        _applyNotificationsPayload(cachedPayload);
        isNotificationsLoading = false;
        notifyListeners();
        unawaited(_refreshNotificationsInBackground());
        return;
      }
    }

    isNotificationsLoading = true;
    notifyListeners();

    try {
      await _refreshNotificationsFromRemote();
    } finally {
      isNotificationsLoading = false;
      notifyListeners();
    }
  }

  void _applyNotificationsPayload(Map<String, dynamic> payload) {
    final rawItems = payload['items'];
    notifications = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (entry) => UserNotificationItem.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList()
        : <UserNotificationItem>[];
    unreadNotificationsCount = (payload['unreadCount'] as num?)?.toInt() ??
        notifications.where((item) => !item.isRead).length;
    _notificationsLoaded = true;
  }

  Map<String, dynamic> _buildNotificationsPayload() {
    return {
      'items': notifications.map((item) => item.toJson()).toList(),
      'unreadCount': unreadNotificationsCount,
    };
  }

  Future<void> _refreshNotificationsInBackground() async {
    try {
      await _refreshNotificationsFromRemote();
      notifyListeners();
    } catch (error) {
      debugPrint('Notifications background refresh skipped: $error');
    }
  }

  Future<void> _refreshNotificationsFromRemote() async {
    final payload = await _usersService.listMyNotifications();
    _applyNotificationsPayload(payload);
    await _usersService.storeNotificationsPayload(_buildNotificationsPayload());
  }

  Future<void> markNotificationRead(String notificationId) async {
    final index = notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1 || notifications[index].isRead) {
      return;
    }

    final updated = await _usersService.markNotificationRead(
      notificationId: notificationId,
    );

    final current = notifications[index];
    notifications[index] = UserNotificationItem(
      id: current.id,
      type: current.type,
      title: current.title,
      body: current.body,
      meta: current.meta,
      createdAt: current.createdAt,
      readAt: updated.readAt ?? DateTime.now(),
    );
    unreadNotificationsCount =
        notifications.where((item) => !item.isRead).length;
    await _usersService.storeNotificationsPayload(_buildNotificationsPayload());
    notifyListeners();
  }

  String? get normalizedLicenseStatus {
    final normalized = selectedUser?.licenseStatus?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool get hasActiveLicense => normalizedLicenseStatus == 'active';

  bool get hasKnownLicenseState => normalizedLicenseStatus != null;

  // License expiry fields — populated by ensureLicenseStateLoaded
  DateTime? licenseExpiresAt;
  DateTime? licenseGrantedAt;
  int? licenseDaysRemaining;
  String? licenseSource;

  bool get canProceedWithoutFreshLicenseCheck {
    return selectedUser != null && (!hasKnownLicenseState || hasActiveLicense);
  }

  /// Returns true if the current session is in guest mode (no authenticated user).
  /// Guest mode allows limited access to content without registration.
  bool get isGuestMode => selectedUser == null;

  /// Returns true if user is authenticated but does not have an active license.
  /// These users have more access than guests but fewer features than licensed users.
  bool get isRegisteredWithoutLicense =>
      selectedUser != null && !hasActiveLicense;

  /// Returns true if user is authenticated and has an active license.
  bool get isLicensedUser => selectedUser != null && hasActiveLicense;

  Future<void> ensureLicenseStateLoaded({bool forceRefresh = false}) async {
    if (selectedUser == null) {
      return;
    }

    if (!forceRefresh &&
        selectedUser?.licenseStatus != null &&
        (selectedUser?.licenseStatus != 'active' || licenseExpiresAt != null)) {
      return;
    }

    isLicenseLoading = true;
    notifyListeners();

    try {
      final licenseState = await _usersService.getLicenseState();
      selectedUser?.licenseStatus = licenseState['licenseStatus'] as String?;
      // Extract expiry info from the enriched response
      final expiresAtRaw = licenseState['expiresAt'];
      if (expiresAtRaw is String) {
        licenseExpiresAt = DateTime.tryParse(expiresAtRaw)?.toLocal();
      } else {
        licenseExpiresAt = null;
      }
      final daysRaw = licenseState['daysRemaining'];
      licenseDaysRemaining = daysRaw is int ? daysRaw : (daysRaw is num ? daysRaw.toInt() : null);
      licenseSource = licenseState['source'] as String?;
      final grantedAtRaw = licenseState['grantedAt'];
      if (grantedAtRaw is String) {
        licenseGrantedAt = DateTime.tryParse(grantedAtRaw)?.toLocal();
      } else {
        licenseGrantedAt = null;
      }
      if (selectedUser != null) {
        await _setActiveUserSnapshot(selectedUser!);
      }
    } finally {
      isLicenseLoading = false;
      notifyListeners();
    }
  }

  Future<void> activateGiftLicense() async {
    if (selectedUser == null) {
      throw Exception('welcome_kickoff_error_missing_user'.tr);
    }

    isLicenseLoading = true;
    notifyListeners();

    try {
      final activation = await _usersService.activateGiftLicense();
      selectedUser?.licenseStatus = activation['licenseStatus'] as String?;
      if (selectedUser != null) {
        await _setActiveUserSnapshot(selectedUser!);
      }
    } finally {
      isLicenseLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPromoWorkspace({bool forceRefresh = false}) async {
    if (selectedUser == null) {
      return;
    }

    if (!forceRefresh &&
        licenseBalanceSummary != null &&
        giftPoolSummary != null &&
        myPromoCodes.isNotEmpty) {
      return;
    }

    isPromoCodesLoading = true;
    promoWorkspaceError = null;
    notifyListeners();

    try {
      final balance = await _usersService.getLicenseBalance();
      final giftPool = await _usersService.getGiftPoolState();
      final promoCodes = await _usersService.listMyPromoCodes();
      licenseBalanceSummary = balance;
      giftPoolSummary = giftPool;
      myPromoCodes = promoCodes;
      promoWorkspaceError = null;
    } catch (error) {
      if (_isUnauthorizedError(error)) {
        // SahifatyApi has already expired the active session tokens and
        // triggered navigation to /select-user.  Do NOT call
        // clearPersistedSession() here — it would wipe every stored account,
        // including ones that are still valid, which is wrong in multi-account
        // scenarios.
        promoWorkspaceError = 'service_api_unauthorized'.tr;
        return;
      }

      licenseBalanceSummary = null;
      giftPoolSummary = null;
      myPromoCodes = <Map<String, dynamic>>[];
      promoWorkspaceError = extractErrorMessage(error);
    } finally {
      isPromoCodesLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> contributeToGiftPool({
    required int quantity,
  }) async {
    if (selectedUser == null) {
      throw Exception('welcome_kickoff_error_missing_user'.tr);
    }

    isPromoCodesLoading = true;
    notifyListeners();

    try {
      final response = await _usersService.contributeToGiftPool(
        quantity: quantity,
      );
      await loadPromoWorkspace(forceRefresh: true);
      return response;
    } finally {
      isPromoCodesLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createPromoCode({required int maxUses}) async {
    if (selectedUser == null) {
      throw Exception('welcome_kickoff_error_missing_user'.tr);
    }

    isPromoCodesLoading = true;
    notifyListeners();

    try {
      final createdPromo =
          await _usersService.createPromoCode(maxUses: maxUses);
      await loadPromoWorkspace(forceRefresh: true);
      return createdPromo;
    } finally {
      isPromoCodesLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> revokePromoCode(String codeId) async {
    if (selectedUser == null) {
      throw Exception('welcome_kickoff_error_missing_user'.tr);
    }

    isPromoCodesLoading = true;
    notifyListeners();

    try {
      final revokedPromo = await _usersService.revokePromoCode(codeId: codeId);
      await loadPromoWorkspace(forceRefresh: true);
      return revokedPromo;
    } finally {
      isPromoCodesLoading = false;
      notifyListeners();
    }
  }

  Future<void> activatePromoLicense(String code) async {
    if (selectedUser == null) {
      throw Exception('welcome_kickoff_error_missing_user'.tr);
    }

    isLicenseLoading = true;
    notifyListeners();

    try {
      final activation = await _usersService.activatePromoLicense(code: code);
      selectedUser?.licenseStatus = activation['licenseStatus'] as String?;
      if (selectedUser != null) {
        await _setActiveUserSnapshot(selectedUser!);
      }
    } finally {
      isLicenseLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createPurchaseIntent({int quantity = 20}) async {
    if (selectedUser == null) {
      throw Exception('welcome_kickoff_error_missing_user'.tr);
    }

    isLicenseLoading = true;
    notifyListeners();

    try {
      return await _usersService.createPurchaseIntent(quantity: quantity);
    } finally {
      isLicenseLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateReadingDisplayPreferences({
    bool? showMemorizationColors,
    bool? showComprehensionUnderline,
  }) async {
    final previousShowMemorizationColors = this.showMemorizationColors;
    final previousShowComprehensionUnderline = this.showComprehensionUnderline;

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
      this.showComprehensionUnderline = previousShowComprehensionUnderline;
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

  Future<AuthData> loginAsChild({
    required String guardianEmail,
    required String password,
    required String childId,
  }) async {
    setLoading();
    try {
      final result = await _usersService.loginChild(
        guardianEmail: guardianEmail,
        password: password,
        childId: childId,
      );

      if (result is AuthData) {
        if (result.user != null) {
          await saveUserToDevice(result.user!);
        }
        return result;
      }

      throw result;
    } finally {
      resetLoading();
    }
  }

  Future<List<Map<String, dynamic>>> getChildLoginOptions({
    required String guardianEmail,
    required String password,
  }) {
    return _usersService.getChildLoginOptions(
      guardianEmail: guardianEmail,
      password: password,
    );
  }

  Future<AuthData> finalizeAuthenticatedUser(AuthData authData) async {
    if (authData.user == null || authData.accessToken == null) {
      throw _buildSocialAuthError(
        'SOCIAL_AUTH_INVALID_RESPONSE',
        'social_auth_invalid_response'.tr,
      );
    }

    final user = User(
      id: authData.user!.id,
      rawId: authData.user!.rawId,
      accountKey: authData.user!.accountKey,
      username: authData.user!.username,
      email: authData.user!.email,
      authProvider: authData.user!.authProvider,
      guardianUserId: authData.user!.guardianUserId,
      userRoleId: authData.user!.userRoleId,
      licenseStatus: authData.user!.licenseStatus,
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
    _resetPushNotificationsSession();
    await _bootstrapPushNotificationsForCurrentUser();
    unawaited(_initialDataSyncService.runIfNeeded(user.id));
    return authData;
  }

  Future<AuthData> signInWithGoogle() async {
    setLoading();
    try {
      await ensureGoogleInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw _buildSocialAuthError(
          'SOCIAL_PROVIDER_UNSUPPORTED',
          'social_provider_temporarily_unavailable'.trParams({
            'provider': _providerLabel('google'),
          }),
          provider: 'google',
        );
      }

      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw _buildSocialAuthError(
          'SOCIAL_ID_TOKEN_MISSING',
          'social_missing_id_token'.tr,
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

      final message = switch (code) {
        'SOCIAL_LOGIN_CANCELLED' => 'social_cancelled'.tr,
        'SOCIAL_PROVIDER_UNSUPPORTED' =>
          'social_provider_temporarily_unavailable'.trParams({
            'provider': _providerLabel('google'),
          }),
        _ => 'social_google_sign_in_failed'.tr,
      };

      throw _buildSocialAuthError(
        code,
        message,
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
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (loginResult.status == LoginStatus.success) {
        final AccessToken? accessToken = loginResult.accessToken;
        if (accessToken == null) {
          throw _buildSocialAuthError(
            'SOCIAL_ACCESS_TOKEN_MISSING',
            'social_missing_id_token'.tr,
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
          'social_cancelled'.tr,
          provider: 'facebook',
        );
      }

      throw _buildSocialAuthError(
        'SOCIAL_LOGIN_FAILED',
        'social_facebook_sign_in_failed'.tr,
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

  Future<AuthData> signInWithHuawei() async {
    if (kIsWeb) {
      await beginHuaweiWebSignIn();
      return Future<AuthData>.error(
        _buildSocialAuthError(
          'SOCIAL_LOGIN_CANCELLED',
          'social_cancelled'.tr,
          provider: 'huawei',
        ),
      );
    }

    setLoading();
    try {
      if (!SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform) {
        throw _buildSocialAuthError(
          'SOCIAL_CONFIG_MISSING',
          'social_huawei_requires_app_id'.tr,
          provider: 'huawei',
        );
      }

      final authParams =
          AccountAuthParamsHelper(AccountAuthParams.defaultAuthRequestParam)
            ..setEmail()
            ..setIdToken()
            ..setProfile();

      final authService =
          AccountAuthManager.getService(authParams.createParams());
      final AuthAccount account = await authService.signIn();

      final token = account.idToken ?? '';

      if (token.isEmpty) {
        throw _buildSocialAuthError(
          'SOCIAL_ID_TOKEN_MISSING',
          'social_missing_id_token'.tr,
          provider: 'huawei',
        );
      }

      return await signInWithHuaweiIdToken(token, manageLoading: false);
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<AuthData> signInWithHuaweiIdToken(
    String token, {
    bool manageLoading = true,
  }) async {
    if (manageLoading) {
      setLoading();
    }

    try {
      final result = await _usersService.loginWithHuawei(token);
      if (result is! AuthData) {
        throw result;
      }

      return await finalizeAuthenticatedUser(result);
    } catch (ex) {
      rethrow;
    } finally {
      if (manageLoading) {
        resetLoading();
      }
    }
  }

  Future<void> beginHuaweiWebSignIn() async {
    if (!kIsWeb) {
      throw _buildSocialAuthError(
        'SOCIAL_PROVIDER_UNSUPPORTED',
        'social_provider_temporarily_unavailable'.trParams({
          'provider': _providerLabel('huawei'),
        }),
        provider: 'huawei',
      );
    }

    setLoading();
    try {
      if (!SocialAuthConfig.isHuaweiConfiguredForCurrentPlatform) {
        throw _buildSocialAuthError(
          'SOCIAL_CONFIG_MISSING',
          'social_huawei_requires_app_id'.tr,
          provider: 'huawei',
        );
      }

      final state = _buildOAuthStateToken();
      final nonce = _buildOAuthStateToken();
      await persistPendingHuaweiWebAuthRequest(state: state, nonce: nonce);
      final authorizationUrl = await _usersService.getHuaweiWebAuthorizationUrl(
        state: state,
        nonce: nonce,
      );
      redirectToHuaweiWebAuthorizationUrl(authorizationUrl);
    } catch (ex) {
      clearPendingHuaweiWebAuthRequest();
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<bool> tryCompleteHuaweiWebSignIn(Uri uri) async {
    if (!kIsWeb) {
      return false;
    }

    final intent = resolveHuaweiWebAuthRoute(uri);
    if (intent.kind == HuaweiWebAuthRouteKind.none) {
      return false;
    }

    final expectedState = readPendingHuaweiWebState();
    final expectedNonce = readPendingHuaweiWebNonce();
    clearPendingHuaweiWebAuthRequest();
    clearHuaweiWebCallbackUrl();

    if (expectedState == null ||
        expectedState.isEmpty ||
        intent.state != expectedState) {
      throw _buildSocialAuthError(
        'SOCIAL_AUTH_INVALID_RESPONSE',
        'social_auth_invalid_response'.tr,
        provider: 'huawei',
      );
    }

    if (intent.hasError) {
      throw _buildSocialAuthError(
        intent.errorCode!,
        intent.errorMessage?.trim().isNotEmpty == true
            ? intent.errorMessage!.trim()
            : 'social_huawei_sign_in_failed'.tr,
        provider: 'huawei',
      );
    }

    final token = intent.token?.trim() ?? '';
    if (token.isEmpty || !_doesJwtNonceMatch(token, expectedNonce)) {
      throw _buildSocialAuthError(
        'SOCIAL_AUTH_INVALID_RESPONSE',
        'social_auth_invalid_response'.tr,
        provider: 'huawei',
      );
    }

    await signInWithHuaweiIdToken(token, manageLoading: false);
    return true;
  }

  String _buildOAuthStateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  bool _doesJwtNonceMatch(String token, String? expectedNonce) {
    if (expectedNonce == null || expectedNonce.isEmpty) {
      return false;
    }

    final segments = token.split('.');
    if (segments.length < 2) {
      return false;
    }

    try {
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is! Map<String, dynamic>) {
        return false;
      }

      final nonce = payload['nonce'];
      if (nonce is! String || nonce.isEmpty) {
        return false;
      }

      return nonce == expectedNonce || nonce == 'default';
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _usersService.logout();
    await _deactivateCurrentSession(preserveStoredSession: true);
  }

  Future<void> clearPersistedSession() async {
    await _deactivateCurrentSession(preserveStoredSession: false);
  }

  Future<void> _deactivateCurrentSession({
    required bool preserveStoredSession,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacySessionIfNeeded(prefs);

    if (preserveStoredSession) {
      // Only remove the active user's session and tokens.
      // Other device accounts must keep their valid sessions intact.
      final activeAccountKey =
          await SecureSessionStorage.readActiveAccountKey();
      if (activeAccountKey != null && activeAccountKey.isNotEmpty) {
        final sessions = await _readStoredAccountSessions(prefs);
        sessions.remove(activeAccountKey);
        await _writeStoredAccountSessions(prefs, sessions);
        await SecureSessionStorage.deleteAccountSessionTokens(activeAccountKey);
      }
      // Clean up any stale legacy global-scope tokens.
      await SecureSessionStorage.clearSessionTokens();
    } else {
      final activeAccountKey =
          await SecureSessionStorage.readActiveAccountKey();
      if (activeAccountKey != null && activeAccountKey.isNotEmpty) {
        await _removeStoredSessionByAccountKey(activeAccountKey);
      }
    }

    await prefs.remove(_activeUserDataKey);
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('password');
    if (preserveStoredSession) {
      await prefs.setBool(_manualLogoutKey, true);
    } else {
      await prefs.remove(_manualLogoutKey);
    }
    await SecureSessionStorage.setActiveAccountKey(null);
    _resetPushNotificationsSession(cancelSubscription: true);
    selectedUser = null;
    isLicenseLoading = false;
    isPromoCodesLoading = false;
    licenseBalanceSummary = null;
    giftPoolSummary = null;
    promoWorkspaceError = null;
    myPromoCodes = <Map<String, dynamic>>[];
    _resetReadingDisplayPreferencesState();
    _resetNotificationsState();
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
      throw Exception('email_verification_pending_resend_missing_email'.tr);
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

      return await finalizeAuthenticatedUser(result);
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

  bool get hasPushedSelectedUser =>
      _previousUser != null &&
      selectedUser != null &&
      _previousUser!.id != selectedUser!.id;

  bool get isViewingDelegatedUser => _isViewingDelegatedUser;

  User? get activeAccountUser =>
      hasPushedSelectedUser ? _previousUser : selectedUser;

  void setSelectedUser(User user) {
    selectedUser = user;
    _resetReadingDisplayPreferencesState();
    _resetNotificationsState();
    notifyListeners();
  }

  void pushSelectedUser(User user) {
    _isViewingDelegatedUser = true;
    _previousUser = selectedUser;
    setSelectedUser(user);
  }

  void popSelectedUser() {
    final previousUser = _previousUser;
    if (previousUser == null) {
      return;
    }

    _previousUser = null;
    _isViewingDelegatedUser = false;
    setSelectedUser(previousUser);
  }

  Future<void> _persistSelectedUser(User user) async {
    selectedUser = user;
    _resetNotificationsState();
    await _setActiveUserSnapshot(user);
    await saveUserToDevice(user);
  }

  Future<void> _persistActiveAccountUser(User user) async {
    if (hasPushedSelectedUser) {
      _previousUser = user;
      await _setActiveUserSnapshot(user);
      await saveUserToDevice(user);
      return;
    }

    await _persistSelectedUser(user);
  }

  User _buildUserFromProfile(Map<String, dynamic> profile) {
    final fallbackUser = activeAccountUser;
    final normalizedProfile = <String, dynamic>{
      ...profile,
      'id': profile['id'] ?? profile['_id'] ?? fallbackUser?.id,
      'rawId': profile['rawId'] ??
          profile['id'] ??
          profile['_id'] ??
          fallbackUser?.rawId,
      'accountKey': profile['accountKey'] ?? fallbackUser?.accountKey,
      'email': profile['email'] ?? fallbackUser?.email ?? '',
      'username': profile['username'] ?? fallbackUser?.username ?? '',
      'userRoleId': profile['userRoleId'] ?? fallbackUser?.userRoleId,
    };
    return User.fromJson(normalizedProfile);
  }

  Future<User?> getCachedCurrentUserProfile() async {
    final cachedProfile = await _usersService.getCachedCurrentUserProfile();
    if (cachedProfile == null) {
      return activeAccountUser;
    }

    final user = _buildUserFromProfile(cachedProfile);
    await _persistActiveAccountUser(user);
    _applyReadingDisplayPreferencesFromProfile(cachedProfile);
    _readingDisplayPreferencesLoaded = true;
    notifyListeners();
    return user;
  }

  Future<void> refreshCurrentUserProfileInBackground({
    void Function(User user)? onUpdated,
  }) async {
    try {
      final user = await loadCurrentUserProfile(notifyLoading: false);
      if (user != null) {
        onUpdated?.call(user);
      }
    } catch (error) {
      debugPrint('Current user profile background refresh skipped: $error');
    }
  }

  Future<User?> loadCurrentUserProfile({bool notifyLoading = true}) async {
    if (notifyLoading) {
      isProfileLoading = true;
      notifyListeners();
    }

    try {
      final profile = await _usersService.getCurrentUserProfile();
      final user = _buildUserFromProfile(profile);
      await _persistActiveAccountUser(user);
      _applyReadingDisplayPreferencesFromProfile(profile);
      _readingDisplayPreferencesLoaded = true;
      notifyListeners();
      return user;
    } finally {
      if (notifyLoading) {
        isProfileLoading = false;
        notifyListeners();
      }
    }
  }

  Future<User> updateStructuredProfile({
    required String username,
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
        username: username,
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
        'id': profile['id'] ?? profile['_id'] ?? activeAccountUser?.id,
        'rawId': profile['rawId'] ??
            profile['id'] ??
            profile['_id'] ??
            activeAccountUser?.rawId,
        'accountKey': profile['accountKey'] ?? activeAccountUser?.accountKey,
        'email': profile['email'] ?? activeAccountUser?.email ?? '',
        'username': profile['username'] ?? username,
        'userRoleId': profile['userRoleId'] ?? activeAccountUser?.userRoleId,
      };
      final user = User.fromJson(normalizedProfile);
      await _persistActiveAccountUser(user);
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
        await prefs.remove(_manualLogoutKey);
        return false;
      }

      String? activeAccountKey =
          await SecureSessionStorage.readActiveAccountKey();
      final manualLogout = prefs.getBool(_manualLogoutKey) == true;
      if (manualLogout &&
          (activeAccountKey == null || activeAccountKey.isEmpty)) {
        return false;
      }

      if (activeAccountKey == null || activeAccountKey.isEmpty) {
        activeAccountKey = sessions.keys.first;
        await SecureSessionStorage.setActiveAccountKey(activeAccountKey);
      }

      final sessionRecord = sessions[activeAccountKey];
      if (sessionRecord is! Map<String, dynamic>) {
        await _removeStoredSessionByAccountKey(activeAccountKey);
        return false;
      }

      final accessToken = await _ensureValidAccessTokenForAccount(
        activeAccountKey,
      );
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      final rawUserData = sessionRecord['user'];
      if (rawUserData is! Map) {
        await _removeStoredSessionByAccountKey(activeAccountKey, notify: true);
        return false;
      }

      final extractedUserData = Map<String, dynamic>.from(rawUserData);

      selectedUser = User.fromJson(extractedUserData);
      // Sync provider-level preference booleans from the newly parsed model
      showMemorizationColors = selectedUser!.showMemorizationColors;
      showComprehensionUnderline = selectedUser!.showComprehensionUnderline;
      _resetNotificationsState();
      await _setActiveUserSnapshot(selectedUser!);
      await prefs.remove(_manualLogoutKey);
      await checkFirstLogin(user: selectedUser);
      _resetPushNotificationsSession();
      await _bootstrapPushNotificationsForCurrentUser();
      unawaited(_initialDataSyncService.runIfNeeded(selectedUser!.id));
      notifyListeners();
      return true;
    } on FetchDataException {
      // Transient network / connectivity error — the stored tokens are still
      // valid.  Return false without touching the session so the user can
      // retry on next app launch or reconnect without being signed out.
      return false;
    } catch (_) {
      // Only reached for genuine data-corruption errors (e.g. malformed
      // stored JSON that User.fromJson cannot parse).  Safe to clear.
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
    _resetNotificationsState();
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

    final legacyScopedLoginFlag = prefs.getBool(
        '${_legacyHasLoggedInBeforeKey}_${_accountKeyForUser(targetUser)}');
    if (legacyScopedLoginFlag == true) {
      await prefs.setBool(scopedKey, true);
      return true;
    }

    final legacyOnboardingComplete =
        prefs.getBool(_legacyOnboardingCompleteKey);
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

    final accessToken = await _ensureValidAccessTokenForAccount(accountKey);
    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    final rawUserData = sessionRecord['user'];
    if (rawUserData is! Map) {
      await _removeStoredSessionByAccountKey(accountKey, notify: true);
      return false;
    }

    final user = User.fromJson(Map<String, dynamic>.from(rawUserData));
    await SecureSessionStorage.setActiveAccountKey(accountKey);
    await prefs.remove(_manualLogoutKey);
    await _setActiveUserSnapshot(user);
    selectedUser = user;
    isLicenseLoading = false;
    isPromoCodesLoading = false;
    licenseBalanceSummary = null;
    giftPoolSummary = null;
    promoWorkspaceError = null;
    myPromoCodes = <Map<String, dynamic>>[];
    _resetReadingDisplayPreferencesState();
    _resetNotificationsState();
    await checkFirstLogin(user: user);
    _resetPushNotificationsSession();
    await _bootstrapPushNotificationsForCurrentUser();
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
        throw responseData['message'] ?? 'delete_account_error'.tr;
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

    final storedUsersList = await _readStoredDeviceUsersList(prefs);
    final accountKey = _accountKeyForUser(user);

    // Check if user already exists — match by stable account key so stored
    // sessions remain bound to the same logical account even if id shapes vary.
    final int existingIndex = storedUsersList.indexWhere(
      (element) =>
          _accountKeyFromUserMap(Map<String, dynamic>.from(element)) ==
          accountKey,
    );

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
    final storedUsers = await _readStoredDeviceUsersList(prefs);
    final users = storedUsers.map((userMap) {
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

      return (a['username'] ?? '').toString().compareTo(
            (b['username'] ?? '').toString(),
          );
    });

    return users;
  }

  Future<void> removeUserFromDevice(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUsersList = await _readStoredDeviceUsersList(prefs);

    if (storedUsersList.isNotEmpty) {
      final dynamic removedUser = storedUsersList.cast<dynamic>().firstWhere(
            (element) => element['email'] == email,
            orElse: () => null,
          );
      storedUsersList.removeWhere((element) => element['email'] == email);

      // Save updated list back
      await prefs.setString(
          _storedDeviceUsersKey, json.encode(storedUsersList));

      if (removedUser is Map) {
        final accountKey = _accountKeyFromUserMap(
          Map<String, dynamic>.from(removedUser),
        );
        if (accountKey != null) {
          await _removeStoredSessionByAccountKey(accountKey, notify: true);
          await _usersService.clearOfflineCacheForAccountKey(accountKey);
        }
      }
    }
  }

  Future<void> removeUserFromDeviceById(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUsersList = await _readStoredDeviceUsersList(prefs);

    if (storedUsersList.isNotEmpty) {
      final dynamic removedUser = storedUsersList.cast<dynamic>().firstWhere(
            (element) => element['id'] == userId,
            orElse: () => null,
          );
      storedUsersList.removeWhere((element) => element['id'] == userId);

      await prefs.setString(
          _storedDeviceUsersKey, json.encode(storedUsersList));

      if (removedUser is Map) {
        final accountKey = _accountKeyFromUserMap(
          Map<String, dynamic>.from(removedUser),
        );
        if (accountKey != null) {
          await _removeStoredSessionByAccountKey(accountKey, notify: true);
          await _usersService.clearOfflineCacheForAccountKey(accountKey);
        }
      }
    }
  }

  // ── Child account methods ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> createChildAccount(
    String username, {
    int? birthYear,
  }) async {
    final body = <String, dynamic>{'username': username};
    if (birthYear != null) {
      body['birthYear'] = birthYear;
    }
    final response = await SahifatyApi().post(url: 'auth/child', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final data = json.decode(response.body);
    throw Exception(
      data is Map
          ? extractErrorMessage(Map<String, dynamic>.from(data))
          : 'child_create_error'.tr,
    );
  }

  Future<List<Map<String, dynamic>>> getChildAccounts() async {
    final response = await SahifatyApi().get('auth/child');
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    final data = json.decode(response.body);
    throw data['message'] ?? 'child_list_error';
  }

  Future<void> switchToChild(String childId, {String? pin}) async {
    setLoading();
    try {
      final body = <String, dynamic>{'childId': childId};
      if (pin != null) body['pin'] = pin;
      final response =
          await SahifatyApi().post(url: 'auth/child/switch', body: body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final data = json.decode(response.body);
        throw data['message'] ?? 'child_switch_error';
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      final accessToken = (data['accessToken'] ?? data['token']) as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('auth_invalid_response');
      }
      final user = User.fromJson(data);
      await saveUserToDevice(user);
      await _persistAccountSession(user, accessToken,
          refreshToken: refreshToken);
      selectedUser = user;
      showMemorizationColors = user.showMemorizationColors;
      showComprehensionUnderline = user.showComprehensionUnderline;
      await checkFirstLogin(user: user);
      _resetPushNotificationsSession();
      await _bootstrapPushNotificationsForCurrentUser();
      notifyListeners();
    } catch (ex) {
      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<void> setChildPin(String childId, String pin) async {
    final response = await SahifatyApi().post(
        url: 'auth/child/pin',
        body: <String, dynamic>{'childId': childId, 'pin': pin});
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = json.decode(response.body);
      throw data['message'] ?? 'child_pin_error';
    }
  }

  Future<void> deleteChildAccount(String childId) async {
    final response = await SahifatyApi().delete('auth/child/$childId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = json.decode(response.body);
      throw data['message'] ?? 'child_delete_error';
    }
  }

  Future<void> renameChildAccount(String childId, String username) async {
    final response = await SahifatyApi().patch(
      url: 'auth/child/$childId/rename',
      body: <String, dynamic>{'username': username},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = json.decode(response.body);
      throw data['message'] ?? 'child_rename_error';
    }
  }

  Future<bool> setLocalPassword({
    required String password,
    required String confirmPassword,
  }) async {
    try {
      if (password != confirmPassword) {
        throw AppException('كلمات المرور غير متطابقة');
      }

      if (password.isEmpty) {
        throw AppException('كلمة المرور مطلوبة');
      }

      // Validate password strength
      if (password.length < 8) {
        throw AppException('يجب أن تكون كلمة المرور 8 أحرف على الأقل');
      }

      if (!RegExp(r'[A-Z]').hasMatch(password)) {
        throw AppException('يجب أن تحتوي على حرف كبير');
      }

      if (!RegExp(r'[a-z]').hasMatch(password)) {
        throw AppException('يجب أن تحتوي على حرف صغير');
      }

      if (!RegExp(r'[0-9]').hasMatch(password)) {
        throw AppException('يجب أن تحتوي على رقم');
      }

      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
        throw AppException('يجب أن تحتوي على رمز خاص');
      }

      final response = await _usersService.setLocalPassword(
        password: password,
        confirmPassword: confirmPassword,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = json.decode(response.body);
        throw AppException(data['message'] ?? 'set_password_error');
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('خطأ: ${e.toString()}');
    }
  }
}
