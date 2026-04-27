import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/controllers/ayat_controller.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/school_level_content.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/services/evaluations_services.dart';
import 'package:sahifaty/services/offline_assessment_store.dart';
import 'package:sahifaty/services/secure_session_storage.dart';

import '../models/chart_evaluation_data.dart';

class EvaluationsProvider with ChangeNotifier {
  EvaluationsProvider() {
    unawaited(_initializeOfflineSupport());
  }

  List<Evaluation> evaluations = [];
  List<UserEvaluation> userEvaluations = [];
  List<ChartEvaluationData> chartEvaluationData = [];
  String chartDimension = 'memorization';
  QuranChartFilters chartFilters = const QuranChartFilters();
  String? chartLoadError;
  bool isLoading = true;
  bool isQuestionsLevelLoading = false;
  int totalCount = 0;
  String? _loadedQuestionsLevelKey;
  int _questionLoadRequestId = 0;
  int _chartLoadRequestId = 0;
  Map<String, List<Ayat>> _questionContentAyahs = {};
  Map<String, bool> _questionContentCompletion = {};
  final EvaluationsServices _evaluationsServices = EvaluationsServices();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncingPending = false;
  int pendingSyncCount = 0;

  List<Evaluation> get memorizationEvaluations => evaluations
      .where((evaluation) =>
          evaluation.id != 0 && evaluation.type != 'comprehension')
      .toList();

  List<Evaluation> get comprehensionEvaluations => evaluations
      .where((evaluation) => evaluation.type == 'comprehension')
      .toList();

  Future<List<Evaluation?>> getAllEvaluations({String? type}) async {
    setLoading();
    try {
      evaluations = await _evaluationsServices.getAllEvaluations(type: type);
      _refreshUserEvaluationMetadata();
      await syncPendingEvaluations();
      return evaluations;
    } finally {
      resetLoading();
    }
  }

  Future<http.Response> evaluateAyah(Map<String, dynamic> body) async {
    try {
      setLoading();
      if (!await _canUseRemoteSync()) {
        return _queueEvaluation('single', body);
      }

      http.Response response = await _evaluationsServices.evaluateAyah(body);
      if (_isSuccessStatus(response.statusCode)) {
        await syncPendingEvaluations();
      }
      return response;
    } catch (ex) {
      if (_shouldDeferToOffline(ex)) {
        return _queueEvaluation('single', body);
      }

      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<http.Response> evaluateMultipleAyat(Map<String, dynamic> body) async {
    try {
      setLoading();
      if (!await _canUseRemoteSync()) {
        return _queueEvaluation('bulk', body);
      }

      http.Response response =
          await _evaluationsServices.evaluateMultipleAyat(body);
      if (_isSuccessStatus(response.statusCode)) {
        await syncPendingEvaluations();
      }
      return response;
    } catch (ex) {
      if (_shouldDeferToOffline(ex)) {
        return _queueEvaluation('bulk', body);
      }

      rethrow;
    } finally {
      resetLoading();
    }
  }

  Future<void> getQuranChartData(
    int userId, {
    String dimension = 'memorization',
    QuranChartFilters? filters,
  }) async {
    final effectiveFilters = filters ?? chartFilters;
    final requestId = ++_chartLoadRequestId;
    try {
      setLoading();
      chartLoadError = null;
      chartDimension = dimension;
      chartFilters = effectiveFilters;

      final cacheScopeKey = await _resolveChartCacheScopeKey(userId);
      final cachedPayload = await _readCachedChartPayload(
        cacheScopeKey: cacheScopeKey,
        dimension: dimension,
        filters: effectiveFilters,
      );

      if (cachedPayload != null) {
        _applyChartPayload(
          cachedPayload,
          dimension: dimension,
          filters: effectiveFilters,
        );
        resetLoading();
        unawaited(
          _maybeRefreshQuranChartDataInBackground(
            requestId: requestId,
            userId: userId,
            dimension: dimension,
            filters: effectiveFilters,
            cacheScopeKey: cacheScopeKey,
          ),
        );
        return;
      }

      chartEvaluationData.clear();
      totalCount = 0;
      notifyListeners();

      final response = await _evaluationsServices.getQuranChartData(
        userId,
        dimension: dimension,
        filters: effectiveFilters,
      );

      await _cacheChartPayload(
        cacheScopeKey: cacheScopeKey,
        dimension: dimension,
        filters: effectiveFilters,
        payload: response,
      );

      if (requestId != _chartLoadRequestId) {
        return;
      }

      _applyChartPayload(
        response,
        dimension: dimension,
        filters: effectiveFilters,
      );
    } catch (e) {
      chartLoadError = e.toString().replaceFirst('Exception: ', '').trim();
      if (kDebugMode) {
        print("Error fetching chart data: $e");
      }
      rethrow;
    } finally {
      if (requestId == _chartLoadRequestId) {
        resetLoading();
      }
    }
  }

  Future<void> _maybeRefreshQuranChartDataInBackground({
    required int requestId,
    required int userId,
    required String dimension,
    required QuranChartFilters filters,
    required String cacheScopeKey,
  }) async {
    if (!await _canUseRemoteSync()) {
      return;
    }

    await _refreshQuranChartDataInBackground(
      requestId: requestId,
      userId: userId,
      dimension: dimension,
      filters: filters,
      cacheScopeKey: cacheScopeKey,
    );
  }

  Future<void> _refreshQuranChartDataInBackground({
    required int requestId,
    required int userId,
    required String dimension,
    required QuranChartFilters filters,
    required String cacheScopeKey,
  }) async {
    try {
      final response = await _evaluationsServices.getQuranChartData(
        userId,
        dimension: dimension,
        filters: filters,
      );

      await _cacheChartPayload(
        cacheScopeKey: cacheScopeKey,
        dimension: dimension,
        filters: filters,
        payload: response,
      );

      if (requestId != _chartLoadRequestId) {
        return;
      }

      _applyChartPayload(
        response,
        dimension: dimension,
        filters: filters,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Quran chart background refresh skipped: $error');
      }
    }
  }

  Future<String> _resolveChartCacheScopeKey(int userId) async {
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    if (activeAccountKey != null && activeAccountKey.trim().isNotEmpty) {
      return activeAccountKey.trim();
    }

    return 'user_$userId';
  }

  Future<Map<String, dynamic>?> _readCachedChartPayload({
    required String cacheScopeKey,
    required String dimension,
    required QuranChartFilters filters,
  }) async {
    final rawJson = await _offlineStore.getCachedQuranChartJson(
      scopeKey: cacheScopeKey,
      dimension: dimension,
      filtersKey: filters.toCacheKey(),
    );
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to parse cached Quran chart payload: $error');
      }
    }

    return null;
  }

  Future<void> _cacheChartPayload({
    required String cacheScopeKey,
    required String dimension,
    required QuranChartFilters filters,
    required Map<String, dynamic> payload,
  }) async {
    await _offlineStore.cacheQuranChartJson(
      scopeKey: cacheScopeKey,
      dimension: dimension,
      filtersKey: filters.toCacheKey(),
      rawJson: jsonEncode(payload),
    );
  }

  void _applyChartPayload(
    Map<String, dynamic> payload, {
    required String dimension,
    required QuranChartFilters filters,
  }) {
    chartDimension = dimension;
    chartFilters = filters;
    totalCount = (payload['totalVerses'] as num?)?.toInt() ?? 0;

    final rawEvaluations = payload['evaluations'];
    if (rawEvaluations is! List) {
      chartEvaluationData = <ChartEvaluationData>[];
    } else {
      chartEvaluationData = rawEvaluations
          .whereType<Map>()
          .map<ChartEvaluationData>(
            (item) => ChartEvaluationData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    chartLoadError = null;
    notifyListeners();
  }

  Future<void> applyChartFilters(int userId, QuranChartFilters filters) async {
    await getQuranChartData(
      userId,
      dimension: chartDimension,
      filters: filters,
    );
  }

  Future<void> clearChartFilters(int userId) async {
    if (!chartFilters.hasAnyActive) {
      return;
    }

    await getQuranChartData(
      userId,
      dimension: chartDimension,
      filters: const QuranChartFilters(),
    );
  }

  Future<void> getAllUserEvaluations(int userId, List<int> ayatIds) async {
    setLoading();
    try {
      final evaluationsByAyahId = await _loadUserEvaluationsByAyahId(
        userId,
        ayatIds,
      );
      userEvaluations = evaluationsByAyahId.values.toList();
      _refreshUserEvaluationMetadata();
    } finally {
      resetLoading();
    }
  }

  Future<void> preloadQuestionLevelData(
    int userId,
    List<SchoolLevelContent> contents,
  ) async {
    final nextLevelKey = contents.map((content) => content.cacheKey).join('||');
    if (_loadedQuestionsLevelKey == nextLevelKey &&
        _questionContentAyahs.isNotEmpty) {
      return;
    }

    final requestId = ++_questionLoadRequestId;
    isQuestionsLevelLoading = true;
    notifyListeners();

    try {
      final ayatController = AyatController();
      final Set<int> ayahIds = <int>{};
      final loadedEntries = await Future.wait(
        contents.map((content) async {
          final ayahs = await ayatController.loadAyatForContent(content);
          return MapEntry(content.cacheKey, ayahs);
        }),
      );

      if (requestId != _questionLoadRequestId) {
        return;
      }

      final Map<String, List<Ayat>> ayahsByContent = {
        for (final entry in loadedEntries) entry.key: entry.value,
      };

      for (final ayahs in ayahsByContent.values) {
        ayahIds.addAll(
          ayahs.where((ayah) => ayah.id != null).map((ayah) => ayah.id!),
        );
      }

      final evaluationsByAyahId = await _loadUserEvaluationsByAyahId(
        userId,
        ayahIds.toList(),
      );

      final Map<String, bool> completionByContent = {};

      for (final entry in ayahsByContent.entries) {
        for (final ayah in entry.value) {
          if (ayah.id != null) {
            ayah.userEvaluation = evaluationsByAyahId[ayah.id!];
          }
        }

        completionByContent[entry.key] = entry.value.isNotEmpty &&
            entry.value
                .every((ayah) => ayah.userEvaluation?.hasAnyAssessment == true);
      }

      if (requestId != _questionLoadRequestId) {
        return;
      }

      _questionContentAyahs = ayahsByContent;
      _questionContentCompletion = completionByContent;
      _loadedQuestionsLevelKey = nextLevelKey;
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading question level data: $e');
      }
      rethrow;
    } finally {
      if (requestId == _questionLoadRequestId) {
        isQuestionsLevelLoading = false;
        notifyListeners();
      }
    }
  }

  List<Ayat> getQuestionContentAyahs(SchoolLevelContent content) {
    return _questionContentAyahs[content.cacheKey] ?? const [];
  }

  bool? getQuestionContentCompletion(SchoolLevelContent content) {
    return _questionContentCompletion[content.cacheKey];
  }

  void syncQuestionContentAyahs(
    SchoolLevelContent content,
    List<Ayat> ayahs,
  ) {
    _questionContentAyahs[content.cacheKey] = ayahs;
    _questionContentCompletion[content.cacheKey] = ayahs.isNotEmpty &&
        ayahs.every((ayah) => ayah.userEvaluation?.hasAnyAssessment == true);
    notifyListeners();
  }

  Evaluation? findEvaluationById(int? id) {
    if (id == null) {
      return null;
    }

    return evaluations.firstWhereOrNull((evaluation) => evaluation.id == id);
  }

  UserEvaluation? getUserEvaluationForAyah(int? ayahId) {
    if (ayahId == null) {
      return null;
    }

    return userEvaluations.firstWhereOrNull(
      (evaluation) =>
          evaluation.ayah?.id == ayahId || evaluation.ayahId == ayahId,
    );
  }

  void upsertUserEvaluation(UserEvaluation userEvaluation) {
    _enrichUserEvaluation(userEvaluation);

    final ayahId = userEvaluation.ayah?.id ?? userEvaluation.ayahId;
    if (ayahId == null) {
      return;
    }

    final index = userEvaluations.indexWhere(
      (evaluation) =>
          evaluation.ayah?.id == ayahId || evaluation.ayahId == ayahId,
    );

    if (index == -1) {
      userEvaluations.add(userEvaluation);
    } else {
      userEvaluations[index] = userEvaluation;
    }

    notifyListeners();
  }

  void _refreshUserEvaluationMetadata() {
    for (final userEvaluation in userEvaluations) {
      _enrichUserEvaluation(userEvaluation);
    }
  }

  void _enrichUserEvaluation(UserEvaluation userEvaluation) {
    userEvaluation.memoEvaluation = userEvaluation.memoEvaluation ??
        findEvaluationById(userEvaluation.memoId);
    userEvaluation.compreEvaluation = userEvaluation.compreEvaluation ??
        findEvaluationById(userEvaluation.compreId);
  }

  Future<void> _initializeOfflineSupport() async {
    await _refreshPendingSyncCount(notify: false);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        return;
      }

      unawaited(syncPendingEvaluations());
    });

    unawaited(syncPendingEvaluations());
  }

  Future<Map<int, UserEvaluation>> _loadUserEvaluationsByAyahId(
    int userId,
    List<int> ayatIds,
  ) async {
    final Map<int, UserEvaluation> evaluationsByAyahId = {};
    if (ayatIds.isEmpty) {
      return evaluationsByAyahId;
    }

    if (await _canUseRemoteSync()) {
      try {
        final fetchedEvaluations =
            await _evaluationsServices.getAllUserEvaluations(
          userId,
          ayatIds,
        );

        for (final evaluation in fetchedEvaluations) {
          _enrichUserEvaluation(evaluation);
          final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
          if (ayahId != null) {
            evaluationsByAyahId[ayahId] = evaluation;
          }
        }
      } catch (error) {
        if (!_shouldDeferToOffline(error)) {
          rethrow;
        }
      }
    }

    final pendingOverlay =
        await _buildPendingEvaluationOverlay(ayatIds.toSet());
    evaluationsByAyahId.addAll(pendingOverlay);
    return evaluationsByAyahId;
  }

  Future<Map<int, UserEvaluation>> _buildPendingEvaluationOverlay(
    Set<int> ayatIds,
  ) async {
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    final pendingItems = await _offlineStore.getPendingEvaluationSyncItems();
    final overlay = <int, UserEvaluation>{};

    for (final item in pendingItems) {
      if (!_matchesActiveAccount(item, activeAccountKey)) {
        continue;
      }

      final body = item.body;
      final singleAyahId = _asInt(body['ayahId']);
      if (singleAyahId != null && ayatIds.contains(singleAyahId)) {
        overlay[singleAyahId] = _mergeQueuedEvaluation(
          overlay[singleAyahId],
          singleAyahId,
          body,
        );
      }

      final bulkAyahIds = body['ayahIds'];
      if (bulkAyahIds is List) {
        for (final rawAyahId in bulkAyahIds) {
          final ayahId = _asInt(rawAyahId);
          if (ayahId == null || !ayatIds.contains(ayahId)) {
            continue;
          }

          overlay[ayahId] = _mergeQueuedEvaluation(
            overlay[ayahId],
            ayahId,
            body,
          );
        }
      }
    }

    for (final userEvaluation in overlay.values) {
      _enrichUserEvaluation(userEvaluation);
    }

    return overlay;
  }

  UserEvaluation _mergeQueuedEvaluation(
    UserEvaluation? existing,
    int ayahId,
    Map<String, dynamic> body,
  ) {
    final hasMemo = body.containsKey('memo_id');
    final hasCompre = body.containsKey('compre_id');
    final hasComment = body.containsKey('comment');
    final nextMemoId = hasMemo ? _asInt(body['memo_id']) : existing?.memoId;
    final nextCompreId =
        hasCompre ? _asInt(body['compre_id']) : existing?.compreId;
    final nextComment =
        hasComment ? _asNullableString(body['comment']) : existing?.comment;

    return UserEvaluation(
      id: existing?.id,
      ayahId: ayahId,
      comment: nextComment,
      memoId: nextMemoId,
      compreId: nextCompreId,
      memoEvaluation: findEvaluationById(nextMemoId),
      compreEvaluation: findEvaluationById(nextCompreId),
      ayah: existing?.ayah,
    );
  }

  Future<http.Response> _queueEvaluation(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    await _offlineStore.enqueuePendingEvaluation(
      endpoint: endpoint,
      body: Map<String, dynamic>.from(body),
    );
    await _refreshPendingSyncCount();
    return http.Response('{"queued":true}', 202, headers: {
      'content-type': 'application/json',
    });
  }

  Future<void> syncPendingEvaluations() async {
    if (_isSyncingPending) {
      return;
    }

    final pendingItems = await _offlineStore.getPendingEvaluationSyncItems();
    if (pendingItems.isEmpty) {
      if (pendingSyncCount != 0) {
        pendingSyncCount = 0;
        notifyListeners();
      }
      return;
    }

    if (!await _canUseRemoteSync()) {
      await _refreshPendingSyncCount();
      return;
    }

    _isSyncingPending = true;
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    final remaining = <PendingEvaluationSyncItem>[];

    try {
      for (var index = 0; index < pendingItems.length; index++) {
        final item = pendingItems[index];
        if (!_matchesActiveAccount(item, activeAccountKey)) {
          remaining.add(item);
          continue;
        }

        try {
          final response = await _sendPendingEvaluation(item);
          if (!_isSuccessStatus(response.statusCode)) {
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
          remaining.addAll(pendingItems.skip(index + 1));
          break;
        }
      }

      await _offlineStore.replacePendingEvaluationSyncItems(remaining);
    } finally {
      _isSyncingPending = false;
      await _refreshPendingSyncCount();
    }
  }

  void resetForAccountSwitch() {
    userEvaluations.clear();
    chartEvaluationData.clear();
    totalCount = 0;
    chartDimension = 'memorization';
    chartLoadError = null;
    _loadedQuestionsLevelKey = null;
    _questionContentAyahs = {};
    _questionContentCompletion = {};
    isQuestionsLevelLoading = false;
    pendingSyncCount = 0;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshPendingSyncCount({bool notify = true}) async {
    final nextCount =
        (await _offlineStore.getPendingEvaluationSyncItems()).length;
    final changed = nextCount != pendingSyncCount;
    pendingSyncCount = nextCount;
    if (notify && changed) {
      notifyListeners();
    }
  }

  Future<bool> _canUseRemoteSync() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return false;
    }

    final accessToken = await SecureSessionStorage.readAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  Future<http.Response> _sendPendingEvaluation(
    PendingEvaluationSyncItem item,
  ) async {
    switch (item.endpoint) {
      case 'bulk':
        return _evaluationsServices.evaluateMultipleAyat(item.body);
      case 'single':
      default:
        return _evaluationsServices.evaluateAyah(item.body);
    }
  }

  bool _matchesActiveAccount(
    PendingEvaluationSyncItem item,
    String? activeAccountKey,
  ) {
    final itemAccountKey = item.accountKey;
    if (itemAccountKey == null || itemAccountKey.isEmpty) {
      return true;
    }

    return itemAccountKey == activeAccountKey;
  }

  bool _isSuccessStatus(int statusCode) {
    return statusCode == 200 || statusCode == 201;
  }

  bool _shouldDeferToOffline(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('no internet') ||
        message.contains('communication') ||
        message.contains('socket') ||
        message.contains('timed out') ||
        message.contains('timeout');
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void setLoading() {
    isLoading = true;
    notifyListeners();
  }

  void resetLoading() {
    isLoading = false;
    notifyListeners();
  }

  String getName(int? id, LanguageProvider languageProvider) {
    isLoading = true;
    try {
      if (id == null) return '';

      final evaluation = findEvaluationById(id);

      return evaluation?.name[languageProvider.langCode] ?? '';
    } finally {
      isLoading = false;
    }
  }
}
