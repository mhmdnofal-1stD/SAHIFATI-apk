import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'core/auth/authenticated_route_gate.dart';
import 'core/auth/password_reset_flow.dart';
import 'core/auth/post_auth_navigation.dart';
import 'core/reading/reading_session.dart';
import 'core/auth/verification_flow.dart';
import 'core/constants/colors.dart';
import 'core/typography/app_typography.dart';
import 'core/typography/typography_config.dart';
import 'providers/ayat_provider.dart';
import 'providers/cards_provider.dart';
import 'providers/evaluations_provider.dart';
import 'providers/general_provider.dart';
import 'providers/school_provider.dart';
import 'providers/surahs_provider.dart';
import 'providers/users_provider.dart';
import 'providers/language_provider.dart';
import 'screens/authentication_screens/email_verification_pending_screen.dart';
import 'screens/authentication_screens/email_verification_result_screen.dart';
import 'screens/authentication_screens/forget_password_screen.dart';
import 'screens/authentication_screens/license_activation_screen.dart';
import 'screens/authentication_screens/login_screen.dart';
import 'screens/authentication_screens/select_user_screen.dart';
import 'screens/authentication_screens/sign_up_screen.dart';
import 'screens/cards_screen/card_detail_screen.dart';
import 'screens/cards_screen/cards_list_screen.dart';
import 'screens/main_screen/main_screen.dart';
import 'screens/quran_view/index_page.dart';
import 'screens/welcome_screen/welcome_screen.dart';
import 'screens/profile_screen/profile_screen.dart';
import 'screens/supervision_screen/incoming_requests_screen.dart';
import 'screens/settings_screen/my_licenses_screen.dart';
import 'services/localization_service.dart';
import 'services/typography_config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the LocalizationService before running the app
  await LocalizationService().init();
  Locale initialLocale = await LocalizationService.getCurrentLocale();

  // Load cached/seed typography config so the first paint already uses the
  // admin-tunable styles. Remote refresh runs after the app is up.
  final TypographyConfig initialTypography =
      await TypographyConfigService.loadCachedOrSeed();
  final TypographyConfigController typographyController =
      TypographyConfigController(initialTypography);

  await SystemChrome.setPreferredOrientations(
    kIsWeb
        ? DeviceOrientation.values
        : [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ],
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeneralProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => SchoolProvider()),
        ChangeNotifierProvider(create: (_) => AyatProvider()),
        ChangeNotifierProvider(create: (_) => EvaluationsProvider()),
        ChangeNotifierProvider(create: (_) => CardsProvider()),
        ChangeNotifierProvider(create: (_) => SurahsProvider()),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(
            initialLangCode: initialLocale.languageCode,
          ),
        ),
        ChangeNotifierProvider<TypographyConfigController>.value(
          value: typographyController,
        ),
      ],
      child: MyApp(initialLocale: initialLocale),
    ),
  );

  // Pull latest translation bundles from the central translation library in
  // the background. Failures (offline, server down) are swallowed so the app
  // keeps using the cached/seed copy without blocking startup.
  unawaited(LocalizationService.refreshFromRemote());

  // Pull the latest typography config in the background and update the
  // controller so live text styles re-render with the admin's overrides.
  unawaited(
    TypographyConfigService.refreshInBackground(
      onUpdated: typographyController.update,
    ),
  );
}

class MyApp extends StatelessWidget {
  final Locale initialLocale;
  const MyApp({super.key, required this.initialLocale});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: LocalizationService(),
      locale: Get.locale ?? initialLocale,
      fallbackLocale: LocalizationService.fallbackLocale,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundColor,
        brightness: Brightness.light,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: AppColors.blackFontColor,
            fontSize: 16,
            height: 1.5,
          ),
          bodyLarge: TextStyle(color: AppColors.blackFontColor),
          titleMedium: TextStyle(
            color: AppColors.blackFontColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        colorScheme: const ColorScheme.light(
          surface: AppColors.panelColor,
          primary: AppColors.buttonColor,
          secondary: AppColors.primaryPurple,
          onPrimary: Colors.white,
          onSurface: AppColors.blackFontColor,
        ),
        cardTheme: CardThemeData(
          color: AppColors.panelColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.lineColor),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryPurple,
            side: const BorderSide(color: AppColors.lineColor),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF1E1E1E),
          primary: Color(0xFF121212),
          secondary: AppColors.buttonColor,
        ),
      ),
      initialRoute: '/',
      unknownRoute: GetPage(
        name: '/route-fallback',
        page: () => const InitialScreen(),
      ),
      getPages: [
        GetPage(name: '/', page: () => const InitialScreen()),
        GetPage(
          name: '/login',
          page: () => const LoginScreen(firstScreen: true),
        ),
        GetPage(
          name: '/select-user',
          page: () => const SelectUserScreen(firstScreen: true),
        ),
        GetPage(
          name: '/signup',
          page: () => const SignUpScreen(),
        ),
        GetPage(
          name: '/forgot-password',
          page: () => ForgotPasswordScreen(
            initialEmail: Get.parameters['email'],
            previewState: Get.parameters['preview'],
          ),
        ),
        GetPage(
          name: '/reset-password',
          page: () => ForgotPasswordScreen(
            initialEmail: Get.parameters['email'],
            resetToken: Get.parameters['token'],
            previewState: Get.parameters['preview'],
          ),
        ),
        GetPage(
          name: '/welcome',
          page: () => const AuthenticatedRouteGate(
            child: WelcomeScreen(),
          ),
        ),
        GetPage(
          name: '/profile',
          page: () => const AuthenticatedRouteGate(
            child: ProfileScreen(),
          ),
        ),
        GetPage(
          name: IncomingRequestsScreen.routeName,
          page: () => const AuthenticatedRouteGate(
            child: IncomingRequestsScreen(),
          ),
        ),
        GetPage(
          name: '/license-activation',
          page: () => const LicenseActivationScreen(),
        ),
        GetPage(
          name: '/my-licenses',
          page: () => const AuthenticatedRouteGate(
            child: MyLicensesScreen(),
          ),
        ),
        GetPage(
          name: MainScreen.routeName,
          page: () => AuthenticatedRouteGate(
            child: MainScreen(
              comesFirst: (Get.parameters['comesFirst'] ?? 'false') == 'true',
            ),
          ),
        ),
        GetPage(
          name: '/sahifa',
          page: () => const AuthenticatedRouteGate(
            child: MainScreen(),
          ),
        ),
        GetPage(
          name: CardsListScreen.routeName,
          page: () => const AuthenticatedRouteGate(
            child: CardsListScreen(),
          ),
        ),
        GetPage(
          name: CardDetailScreen.routeName,
          page: () {
            final idStr = Get.parameters['id'] ?? '';
            final id = int.tryParse(idStr);
            if (id == null) return const InitialScreen();
            return AuthenticatedRouteGate(
              child: CardDetailScreen(cardId: id),
            );
          },
        ),
        GetPage(
          name: IndexPage.routeName,
          page: () {
            final readingPage = _buildReadingPageFromParameters(
              Get.parameters.map(
                (key, value) => MapEntry(key, value ?? ''),
              ),
            );
            if (readingPage == null) {
              return const InitialScreen();
            }

            return AuthenticatedRouteGate(child: readingPage);
          },
        ),
        GetPage(
          name: '/verification-pending',
          page: () => EmailVerificationPendingScreen(
            initialEmail: Get.parameters['email'],
          ),
        ),
        GetPage(
          name: '/verify-email',
          page: () => EmailVerificationHandlerScreen(
            token: Get.parameters['token'],
            email: Get.parameters['email'],
          ),
        ),
        GetPage(
          name: '/verification-success',
          page: () => EmailVerificationResultScreen(
            state: VerificationResultState.success,
            email: Get.parameters['email'],
          ),
        ),
        GetPage(
          name: '/verification-failed',
          page: () => EmailVerificationResultScreen(
            state: VerificationResultState.failed,
            email: Get.parameters['email'],
          ),
        ),
        GetPage(
          name: '/verification-expired',
          page: () => EmailVerificationResultScreen(
            state: VerificationResultState.expired,
            email: Get.parameters['email'],
          ),
        ),
      ],
    );
  }
}

IndexPage? _buildReadingPageFromParameters(Map<String, String> parameters) {
  try {
    return IndexPage.fromRouteParameters(parameters);
  } catch (_) {
    return null;
  }
}

bool _hasLegacyMinifiedReadingHash(Uri uri) {
  return uri.fragment.contains('minified:');
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final evaluationsProvider =
        Provider.of<EvaluationsProvider>(context, listen: false);
    try {
      await usersProvider.loadPendingVerificationState();

      final passwordResetIntent = resolvePasswordResetRoute(Uri.base);
      if (!mounted) {
        return;
      }

      if (passwordResetIntent.kind == PasswordResetRouteKind.request) {
        Get.offAllNamed(
          '/forgot-password',
          parameters: {
            if (passwordResetIntent.email != null)
              'email': passwordResetIntent.email!,
            if (passwordResetIntent.preview != null)
              'preview': passwordResetIntent.preview!,
          },
        );
        return;
      }

      if (passwordResetIntent.kind == PasswordResetRouteKind.reset) {
        Get.offAllNamed(
          '/reset-password',
          parameters: {
            if (passwordResetIntent.token != null)
              'token': passwordResetIntent.token!,
            if (passwordResetIntent.email != null)
              'email': passwordResetIntent.email!,
            if (passwordResetIntent.preview != null)
              'preview': passwordResetIntent.preview!,
          },
        );
        return;
      }

      final verificationIntent = resolveVerificationRoute(Uri.base);
      if (!mounted) {
        return;
      }

      if (verificationIntent.kind == VerificationRouteKind.verifyToken) {
        Get.offAllNamed(
          '/verify-email',
          parameters: {
            if (verificationIntent.token != null)
              'token': verificationIntent.token!,
            if (verificationIntent.email != null)
              'email': verificationIntent.email!,
          },
        );
        return;
      }

      if (verificationIntent.kind == VerificationRouteKind.pending) {
        Get.offAllNamed(
          '/verification-pending',
          parameters: {
            if (verificationIntent.email != null)
              'email': verificationIntent.email!,
          },
        );
        return;
      }

      if (verificationIntent.kind == VerificationRouteKind.success) {
        Get.offAllNamed(
          '/verification-success',
          parameters: {
            if (verificationIntent.email != null)
              'email': verificationIntent.email!,
          },
        );
        return;
      }

      if (verificationIntent.kind == VerificationRouteKind.failed) {
        Get.offAllNamed(
          '/verification-failed',
          parameters: {
            if (verificationIntent.email != null)
              'email': verificationIntent.email!,
          },
        );
        return;
      }

      if (verificationIntent.kind == VerificationRouteKind.expired) {
        Get.offAllNamed(
          '/verification-expired',
          parameters: {
            if (verificationIntent.email != null)
              'email': verificationIntent.email!,
          },
        );
        return;
      }

      final bool isLoggedIn = await usersProvider.tryAutoLogin();

      if (!mounted) {
        return;
      }

      if (isLoggedIn && usersProvider.selectedUser != null) {
        try {
          await usersProvider.ensureLicenseStateLoaded(forceRefresh: true);

          if (_hasLegacyMinifiedReadingHash(Uri.base) &&
              usersProvider.hasActiveLicense) {
            final readingSession = await ReadingSessionStore().loadForUser(
              usersProvider.selectedUser!.id,
            );
            if (!mounted) {
              return;
            }

            if (readingSession != null) {
              Get.offAllNamed(
                IndexPage.routeName,
                parameters: IndexPage.routeParametersForSession(readingSession),
              );
              return;
            }
          }

          await navigateAfterSuccessfulLogin(
            userId: usersProvider.selectedUser!.id,
            isFirstLogin: usersProvider.isFirstLogin,
            hasActiveLicense:
                usersProvider.canProceedWithoutFreshLicenseCheck,
            loadChartData: (userId) =>
                evaluationsProvider.getQuranChartData(userId),
          );
          if (!mounted) {
            return;
          }
        } catch (error) {
          debugPrint('Initial navigation fallback after cached session: $error');
          await _routeToLoginOrSelectUser(usersProvider);
        }
      } else {
        await _routeToLoginOrSelectUser(usersProvider);
      }
    } catch (error) {
      debugPrint('Initial session bootstrap failed: $error');
      if (!mounted) {
        return;
      }
      await _routeToLoginOrSelectUser(usersProvider);
    }
  }

  Future<void> _routeToLoginOrSelectUser(UsersProvider usersProvider) async {
    final storedUsers = await usersProvider.getStoredDeviceUsers();
    if (storedUsers.isNotEmpty) {
      Get.offAllNamed('/select-user');
    } else {
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
