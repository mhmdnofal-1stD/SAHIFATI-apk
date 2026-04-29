import 'package:get/get.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/screens/quran_view/index_page.dart';

typedef LoginRouteReplacer = void Function(
  String routeName, {
  Map<String, String>? parameters,
});

typedef ResumeReadingSessionReplacer = void Function(
  ReadingSession session,
);

void _replaceLoginRoute(
  String routeName, {
  Map<String, String>? parameters,
}) {
  Get.offAllNamed(routeName, parameters: parameters);
}

void _replaceWithReadingSession(ReadingSession session) {
  Get.offAllNamed(
    IndexPage.routeName,
    parameters: IndexPage.routeParametersForSession(session),
  );
}

Future<void> navigateAfterSuccessfulLogin({
  required int userId,
  required bool isFirstLogin,
  required bool hasActiveLicense,
  required Future<void> Function(int userId) loadChartData,
  LoginRouteReplacer? replaceRoute,
  ResumeReadingSessionReplacer? resumeReadingSession,
  ReadingSessionStore? readingSessionStore,
}) async {
  final replace = replaceRoute ?? _replaceLoginRoute;
  final resume = resumeReadingSession ?? _replaceWithReadingSession;
  final sessionStore = readingSessionStore ?? ReadingSessionStore();

  if (!hasActiveLicense) {
    replace('/license-activation');
    return;
  }

  if (!isFirstLogin) {
    final pendingReadingSession =
        await sessionStore.consumePendingAutoResumeForUser(userId);
    if (pendingReadingSession != null) {
      resume(pendingReadingSession);
      return;
    }

    await loadChartData(userId);
    replace(
      MainScreen.routeName,
      parameters: const {'comesFirst': 'false'},
    );
    return;
  }

  replace('/welcome');
}
