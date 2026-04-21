import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:sahifaty/screens/sahifa_screen/sahifa_screen.dart';
import 'package:sahifaty/screens/welcome_screen/welcome_screen.dart';

typedef LoginRouteReplacer = void Function(Widget page);
typedef LoginDestinationBuilder = Widget Function();

Widget _buildDefaultWelcomeScreen() => const WelcomeScreen();

Widget _buildDefaultSahifaScreen() => const SahifaScreen(firstScreen: false);

void _replaceLoginRoute(Widget page) {
  Get.offAll(() => page);
}

Future<void> navigateAfterSuccessfulLogin({
  required int userId,
  required bool isFirstLogin,
  required Future<void> Function(int userId) loadChartData,
  LoginRouteReplacer? replaceRoute,
  LoginDestinationBuilder? buildWelcomeScreen,
  LoginDestinationBuilder? buildSahifaScreen,
}) async {
  final replace = replaceRoute ?? _replaceLoginRoute;

  if (!isFirstLogin) {
    await loadChartData(userId);
    replace((buildSahifaScreen ?? _buildDefaultSahifaScreen)());
    return;
  }

  replace((buildWelcomeScreen ?? _buildDefaultWelcomeScreen)());
}