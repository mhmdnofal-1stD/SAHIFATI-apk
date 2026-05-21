import 'package:get/get.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/screens/quran_view/index_page.dart';
import 'package:sahifaty/screens/user_overview_screen/user_overview_screen.dart';

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
  // isFirstLogin is kept for API compatibility but no longer changes routing
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

  final pendingReadingSession =
      await sessionStore.consumePendingAutoResumeForUser(userId);
  if (pendingReadingSession != null) {
    resume(pendingReadingSession);
    return;
  }

  await loadChartData(userId);
  replace(UserOverviewScreen.routeName);
}
