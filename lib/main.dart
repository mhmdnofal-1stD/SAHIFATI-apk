import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'controllers/general_controller.dart';
import 'core/constants/colors.dart';
import 'providers/ayat_provider.dart';
import 'providers/evaluations_provider.dart';
import 'providers/general_provider.dart';
import 'providers/school_provider.dart';
import 'providers/surahs_provider.dart';
import 'providers/users_provider.dart';
import 'providers/language_provider.dart';
import 'screens/main_screen/main_screen.dart';
import 'screens/authentication_screens/login_screen.dart';
import 'screens/authentication_screens/select_user_screen.dart';
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
    return FutureBuilder(
        future: GeneralController().checkConnectivity(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final hasConnection = snapshot.data ?? false;

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
            home:
                hasConnection ? const InitialScreen() : const MainScreen(comesFirst: true),
          );
        });
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

    final bool isLoggedIn = await usersProvider.tryAutoLogin();

    if (isLoggedIn && usersProvider.selectedUser != null) {
      try {
        await evaluationsProvider
            .getQuranChartData(usersProvider.selectedUser!.id);
        Get.off(() => const SahifaScreen(firstScreen: true,));
      } catch (e) {
        // Error getting data, fall back to stored users check
        _routeToLoginOrSelectUser(usersProvider);
      }
    } else {
        _routeToLoginOrSelectUser(usersProvider);
    }
  }

  Future<void> _routeToLoginOrSelectUser(UsersProvider usersProvider) async {
    final storedUsers = await usersProvider.getStoredDeviceUsers();
    if (storedUsers.isNotEmpty) {
      Get.off(() => const SelectUserScreen(firstScreen: true,));
    } else {
      Get.off(() => const LoginScreen(firstScreen: true));
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

