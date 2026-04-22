import 'package:get/get.dart';

typedef LoginRouteReplacer = void Function(
  String routeName, {
  Map<String, String>? parameters,
});

void _replaceLoginRoute(
  String routeName, {
  Map<String, String>? parameters,
}) {
  Get.offAllNamed(routeName, parameters: parameters);
}

Future<void> navigateAfterSuccessfulLogin({
  required int userId,
  required bool isFirstLogin,
  required Future<void> Function(int userId) loadChartData,
  LoginRouteReplacer? replaceRoute,
}) async {
  final replace = replaceRoute ?? _replaceLoginRoute;

  if (!isFirstLogin) {
    await loadChartData(userId);
    replace(
      '/sahifa',
      parameters: const {'firstScreen': 'false'},
    );
    return;
  }

  replace('/welcome');
}