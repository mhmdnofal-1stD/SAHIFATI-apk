import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cards_service.dart';
import 'evaluations_services.dart';
import 'school_services.dart';
import 'secure_session_storage.dart';
import 'subjects_lookup_service.dart';
import 'teacher_supervisions_services.dart';
import 'users_services.dart';

class InitialDataSyncService {
  final SchoolServices _schoolServices = SchoolServices();
  final EvaluationsServices _evaluationsServices = EvaluationsServices();
  final UsersServices _usersServices = UsersServices();
  final CardsService _cardsService = CardsService();
  final TeacherSupervisionsService _teacherSupervisionsService =
      TeacherSupervisionsService();

  Future<void> runIfNeeded(int userId) async {
    final accountKey = await _resolveAccountKey();
    final prefs = await SharedPreferences.getInstance();
    final completionKey = _completionKey(accountKey);
    if (prefs.getBool(completionKey) == true) {
      return;
    }

    if (!await _isOnline()) {
      return;
    }

    await _runStep(
      'quick school',
      () => _schoolServices.getQuickQuestionsSchool(),
      userId,
    );
    await _runStep(
      'schools catalog',
      () => _schoolServices.getAllSchools(),
      userId,
    );
    await _runStep(
      'subjects hierarchy',
      () => SubjectsLookupService.instance.loadHierarchy(),
      userId,
    );
    await _runStep(
      'evaluations',
      () => _evaluationsServices.getAllEvaluations(),
      userId,
    );
    await _runStep(
      'current profile',
      () => _usersServices.getCurrentUserProfile(),
      userId,
    );
    await _runStep(
      'supervision code',
      () => _usersServices.getMySupervisionCode(),
      userId,
    );
    await _runStep(
      'cards page 1',
      () => _cardsService.getCards(page: 1),
      userId,
    );
    await _runStep(
      'supervision links',
      () => _teacherSupervisionsService.listLinks(),
      userId,
    );
    await _runStep(
      'supervision requests',
      () => _teacherSupervisionsService.listIncomingRequests(),
      userId,
    );
    await _runStep(
      'supervision limits',
      () => _teacherSupervisionsService.getLimits(),
      userId,
    );

    await prefs.setBool(completionKey, true);
  }

  Future<void> _runStep(
    String label,
    Future<Object?> Function() step,
    int userId,
  ) async {
    try {
      await step();
    } catch (error, stackTrace) {
      debugPrint(
        'InitialDataSyncService skipped $label for user $userId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String> _resolveAccountKey() async {
    final accountKey = await SecureSessionStorage.readActiveAccountKey();
    if (accountKey != null && accountKey.trim().isNotEmpty) {
      return accountKey.trim();
    }

    return 'default';
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  String _completionKey(String accountKey) =>
      'initial_data_sync_done.$accountKey';
}