import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'core/auth/verification_flow.dart';
import 'controllers/general_controller.dart';
import 'core/constants/colors.dart';
import 'providers/ayat_provider.dart';
import 'providers/evaluations_provider.dart';
import 'providers/general_provider.dart';
import 'providers/school_provider.dart';
import 'providers/surahs_provider.dart';
import 'providers/users_provider.dart';
import 'providers/language_provider.dart';
import 'screens/authentication_screens/email_verification_pending_screen.dart';
import 'screens/authentication_screens/email_verification_result_screen.dart';
import 'screens/authentication_screens/login_screen.dart';
import 'screens/authentication_screens/select_user_screen.dart';
import 'screens/authentication_screens/sign_up_screen.dart';
import 'screens/sahifa_screen/sahifa_screen.dart';
import 'services/localization_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the LocalizationService before running the app
  await LocalizationService().init();
  Locale initialLocale = await LocalizationService.getCurrentLocale();

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
        ChangeNotifierProvider(create: (_) => SurahsProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MyApp(initialLocale: initialLocale),
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
        scaffoldBackgroundColor: AppColors.backgroundColor,
        brightness: Brightness.light,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.blackFontColor),
        ),
        colorScheme: const ColorScheme.light(
          surface: AppColors.backgroundColor,
          primary: AppColors.backgroundColor,
          secondary: AppColors.buttonColor,
        ),
      ),
      darkTheme: ThemeData(
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
    await usersProvider.loadPendingVerificationState();

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

    if (usersProvider.hasPendingVerification) {
      Get.offAllNamed(
        '/verification-pending',
        parameters: {
          'email': usersProvider.pendingVerificationEmail!,
        },
      );
      return;
    }

    final hasConnection = await GeneralController().checkConnectivity();

    if (!mounted) {
      return;
    }

    if (!hasConnection) {
      await usersProvider.clearPersistedSession();
      await _routeToLoginOrSelectUser(usersProvider);
      return;
    }

    final bool isLoggedIn = await usersProvider.tryAutoLogin();

    if (!mounted) {
      return;
    }

    if (isLoggedIn && usersProvider.selectedUser != null) {
      try {
        await evaluationsProvider
            .getQuranChartData(usersProvider.selectedUser!.id);
        if (!mounted) {
          return;
        }
        Get.off(() => const SahifaScreen(firstScreen: true,));
      } catch (e) {
        await usersProvider.clearPersistedSession();
        _routeToLoginOrSelectUser(usersProvider);
      }
    } else {
        await usersProvider.clearPersistedSession();
        _routeToLoginOrSelectUser(usersProvider);
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

