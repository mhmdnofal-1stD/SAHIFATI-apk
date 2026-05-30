import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
import 'package:sahifaty/services/local_quran_chart_service.dart';
import 'package:sahifaty/services/offline_assessment_store.dart';
import 'package:sahifaty/services/school_filter_scope_service.dart';
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
  String? chartDataSource;
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
  final LocalQuranChartService _localQuranChartService =
      const LocalQuranChartService();
  final SchoolFilterScopeService _schoolFilterScopeService =
      const SchoolFilterScopeService();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncingPending = false;
  final Set<String> _hydratedUserEvaluationScopes = <String>{};
  final Map<String, Future<void>> _userEvaluationCacheWarmups =
      <String, Future<void>>{};
  int pendingSyncCount = 0;
  int? _activeEvaluationUserId;

  void _debugChart(
    String event, {
    int? userId,
    String? dimension,
    QuranChartFilters? filters,
    int? requestId,
    int? entryCount,
    int? totalVerses,
    String? error,
  }) {
    if (!kDebugMode) {
      return;
    }

    final buffer = StringBuffer('[chart] $event');
    if (requestId != null) {
      buffer.write(' req=$requestId');
    }
    if (userId != null) {
      buffer.write(' user=$userId');
    }
    if (dimension != null && dimension.isNotEmpty) {
      buffer.write(' dim=$dimension');
    }
    if (filters != null) {
      buffer.write(' filters=${filters.toCacheKey()}');
      if (filters.hasAnyActive) {
        buffer.write(' filtered=true');
      }
    }
    if (entryCount != null) {
      buffer.write(' entries=$entryCount');
    }
    if (totalVerses != null) {
      buffer.write(' totalVerses=$totalVerses');
    }
    if (error != null && error.isNotEmpty) {
      buffer.write(' error="$error"');
    }

    debugPrint(buffer.toString());
  }

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
      _debugChart(
        'request:start',
        userId: userId,
        dimension: dimension,
        filters: effectiveFilters,
        requestId: requestId,
      );
      setLoading();
      chartLoadError = null;
      chartDimension = dimension;
      chartFilters = effectiveFilters;

      _debugChart(
        'offline:build',
        dimension: dimension,
        filters: effectiveFilters,
        requestId: requestId,
        userId: userId,
      );
      final response = await buildOfflineQuranChartPayload(
        userId,
        dimension: dimension,
        filters: effectiveFilters,
      );

      if (requestId != _chartLoadRequestId) {
        _debugChart(
          'request:stale_discarded',
          userId: userId,
          dimension: dimension,
          filters: effectiveFilters,
          requestId: requestId,
        );
        return;
      }

      _applyChartPayload(
        response,
        dimension: dimension,
        filters: effectiveFilters,
        source: 'offline-local',
        requestId: requestId,
        userId: userId,
      );
    } catch (e) {
      chartLoadError = e.toString().replaceFirst('Exception: ', '').trim();
      _debugChart(
        'request:error',
        userId: userId,
        dimension: dimension,
        filters: effectiveFilters,
        requestId: requestId,
        error: chartLoadError,
      );
      rethrow;
    } finally {
      if (requestId == _chartLoadRequestId) {
        resetLoading();
        _debugChart(
          'request:end',
          userId: userId,
          dimension: dimension,
          filters: effectiveFilters,
          requestId: requestId,
          entryCount: chartEvaluationData.length,
          totalVerses: totalCount,
          error: chartLoadError,
        );
      }
    }
  }

  Future<Map<String, dynamic>> buildOfflineQuranChartPayload(
    int userId, {
    String dimension = 'memorization',
    QuranChartFilters filters = const QuranChartFilters(),
  }) async {
    final allAyat = await AyatController().loadAllAyat();
    final resolvedUserEvaluations = await loadResolvedUserEvaluations(userId);
    final allowedSchoolAyahIds =
        await _schoolFilterScopeService.resolveAllowedAyahIds(filters);
    return _localQuranChartService.buildChartPayload(
      allAyat: allAyat,
      userEvaluations: resolvedUserEvaluations,
      evaluations: evaluations,
      dimension: dimension,
      filters: filters,
      allowedSchoolAyahIds: allowedSchoolAyahIds,
    );
  }

  Future<String> _resolveChartCacheScopeKey(int userId) async {
    final activeAccountKey = await SecureSessionStorage.readActiveAccountKey();
    if (activeAccountKey != null && activeAccountKey.trim().isNotEmpty) {
      return '${activeAccountKey.trim()}.user_$userId';
    }

    return 'user_$userId';
  }

  void _applyChartPayload(
    Map<String, dynamic> payload, {
    required String dimension,
    required QuranChartFilters filters,
    String source = 'unknown',
    int? requestId,
    int? userId,
  }) {
    chartDimension = dimension;
    chartFilters = filters;
    chartDataSource = source;
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
    _debugChart(
      'payload:applied:$source',
      userId: userId,
      dimension: dimension,
      filters: filters,
      requestId: requestId,
      entryCount: chartEvaluationData.length,
      totalVerses: totalCount,
    );
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

  Future<List<UserEvaluation>> loadResolvedUserEvaluations(int userId) async {
    _prepareUserScope(userId);
    final allAyat = await AyatController().loadAllAyat();
    final ayatById = <int, Ayat>{
      for (final ayah in allAyat)
        if (ayah.id != null) ayah.id!: ayah,
    };

    final scopeKey = await _resolveChartCacheScopeKey(userId);
    final authenticatedUserId = await _resolveAuthenticatedUserId();
    if (authenticatedUserId == userId) {
      await _ensureUserEvaluationCacheHydrated(
        userId: userId,
        scopeKey: scopeKey,
      );
    }

    final cachedEvaluations =
        await _readCachedUserEvaluations(scopeKey: scopeKey);
    final mergedByAyahId = <int, UserEvaluation>{
      for (final evaluation in cachedEvaluations)
        if ((evaluation.ayah?.id ?? evaluation.ayahId) != null)
          (evaluation.ayah?.id ?? evaluation.ayahId)!: evaluation,
    };

    if (authenticatedUserId == userId) {
      for (final evaluation in userEvaluations) {
        final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
        if (ayahId != null) {
          mergedByAyahId[ayahId] = evaluation;
        }
      }

      final pendingOverlay = await _buildPendingEvaluationOverlay(
        ayatById.keys.toSet(),
      );
      mergedByAyahId.addAll(pendingOverlay);
    }

    final resolved = <UserEvaluation>[];
    for (final entry in mergedByAyahId.entries) {
      final evaluation = entry.value;
      final ayah = evaluation.ayah ?? ayatById[entry.key];
      final resolvedEvaluation = UserEvaluation(
        id: evaluation.id,
        ayahId: entry.key,
        ayahIds: evaluation.ayahIds,
        memoId: evaluation.memoId,
        compreId: evaluation.compreId,
        comment: evaluation.comment,
        memoEvaluation: evaluation.memoEvaluation,
        compreEvaluation: evaluation.compreEvaluation,
        ayah: ayah,
      );
      _enrichUserEvaluation(resolvedEvaluation);
      resolved.add(resolvedEvaluation);
    }

    return resolved;
  }

  Future<void> getAllUserEvaluations(int userId, List<int> ayatIds) async {
    _prepareUserScope(userId);
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

  /// Ensures ALL user evaluations are loaded using the paginated endpoint
  /// (1000 per page, typically 1-2 API calls total). Safe to call multiple
  /// times — the hydration step is a no-op once already done.
  Future<void> ensureAllUserEvaluationsLoaded(int userId) async {
    _prepareUserScope(userId);
    final scopeKey = await _resolveChartCacheScopeKey(userId);
    await _ensureUserEvaluationCacheHydrated(
      userId: userId,
      scopeKey: scopeKey,
    );
  }

  Future<void> mergeUserEvaluationsForAyatIds(
    int userId,
    List<int> ayatIds, {
    int batchSize = 250,
  }) async {
    _prepareUserScope(userId);
    final normalizedIds = ayatIds.toSet().toList();
    if (normalizedIds.isEmpty) {
      return;
    }

    final mergedByAyahId = <int, UserEvaluation>{
      for (final evaluation in userEvaluations)
        if ((evaluation.ayah?.id ?? evaluation.ayahId) != null)
          (evaluation.ayah?.id ?? evaluation.ayahId)!: evaluation,
    };

    for (var start = 0; start < normalizedIds.length; start += batchSize) {
      final end = math.min(start + batchSize, normalizedIds.length);
      final batch = normalizedIds.sublist(start, end);
      final batchEvaluations = await _loadUserEvaluationsByAyahId(
        userId,
        batch,
      );
      mergedByAyahId.addAll(batchEvaluations);
    }

    userEvaluations = mergedByAyahId.values.toList();
    _refreshUserEvaluationMetadata();
    notifyListeners();
  }

  Future<void> preloadQuestionLevelData(
    int userId,
    List<SchoolLevelContent> contents,
  ) async {
    _prepareUserScope(userId);
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
          ayatIds: ayatIds,
        );

        for (final evaluation in fetchedEvaluations) {
          _enrichUserEvaluation(evaluation);
          final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
          if (ayahId != null) {
            evaluationsByAyahId[ayahId] = evaluation;
          }
        }

        await _mergeCachedUserEvaluations(
          userId: userId,
          evaluations: fetchedEvaluations,
        );
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
    await _persistEvaluationPayloadToLocalCache(body);
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
      // Separate single-endpoint items (batch them) from bulk-endpoint items
      final singleItems = <PendingEvaluationSyncItem>[];
      final bulkItems = <PendingEvaluationSyncItem>[];
      for (final item in pendingItems) {
        if (!_matchesActiveAccount(item, activeAccountKey)) {
          remaining.add(item);
          continue;
        }
        if (item.endpoint == 'bulk') {
          bulkItems.add(item);
        } else {
          singleItems.add(item);
        }
      }

      // Batch-flush all single items in one request
      if (singleItems.isNotEmpty) {
        try {
          final batchPayload = singleItems
              .map((i) => Map<String, dynamic>.from(i.body))
              .toList();
          final response =
              await _evaluationsServices.batchFlushEvaluations(batchPayload);
          if (!_isSuccessStatus(response.statusCode)) {
            // Keep all as remaining if the batch call itself failed
            remaining.addAll(singleItems);
          }
          // On success, individual failures are reported in the response body
          // but we still consider the queue flushed (server accepted the request)
        } catch (_) {
          remaining.addAll(singleItems);
        }
      }

      // Process bulk items individually (each carries multiple ayahIds with same dims)
      for (var index = 0; index < bulkItems.length; index++) {
        final item = bulkItems[index];
        try {
          final response = await _sendPendingEvaluation(item);
          if (!_isSuccessStatus(response.statusCode)) {
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
          remaining.addAll(bulkItems.skip(index + 1));
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
    userEvaluations = <UserEvaluation>[];
    chartEvaluationData = <ChartEvaluationData>[];
    totalCount = 0;
    chartDimension = 'memorization';
    chartDataSource = null;
    chartLoadError = null;
    _loadedQuestionsLevelKey = null;
    _questionContentAyahs = {};
    _questionContentCompletion = {};
    _hydratedUserEvaluationScopes.clear();
    _userEvaluationCacheWarmups.clear();
    _activeEvaluationUserId = null;
    isQuestionsLevelLoading = false;
    pendingSyncCount = 0;
    isLoading = false;
    notifyListeners();
  }

  void _prepareUserScope(int userId) {
    if (_activeEvaluationUserId == userId) {
      return;
    }

    if (_activeEvaluationUserId != null) {
      userEvaluations = <UserEvaluation>[];
      chartEvaluationData = <ChartEvaluationData>[];
      totalCount = 0;
      chartDimension = 'memorization';
      chartDataSource = null;
      chartLoadError = null;
      _loadedQuestionsLevelKey = null;
      _questionContentAyahs = {};
      _questionContentCompletion = {};
      _hydratedUserEvaluationScopes.clear();
      _userEvaluationCacheWarmups.clear();
      isQuestionsLevelLoading = false;
      pendingSyncCount = 0;
      isLoading = false;
    }

    _activeEvaluationUserId = userId;
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

  Future<List<UserEvaluation>> _readCachedUserEvaluations({
    required String scopeKey,
  }) async {
    final rawJson = await _offlineStore.getCachedUserEvaluationsJson(
      scopeKey: scopeKey,
    );
    if (rawJson == null || rawJson.isEmpty) {
      return const <UserEvaluation>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <UserEvaluation>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => UserEvaluation.fromCacheJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: true);
    } catch (_) {
      return const <UserEvaluation>[];
    }
  }

  Future<void> _ensureUserEvaluationCacheHydrated({
    required int userId,
    required String scopeKey,
  }) async {
    if (_hydratedUserEvaluationScopes.contains(scopeKey)) {
      return;
    }

    final existingWarmup = _userEvaluationCacheWarmups[scopeKey];
    if (existingWarmup != null) {
      await existingWarmup;
      return;
    }

    final warmup = _warmUserEvaluationCache(
      userId: userId,
      scopeKey: scopeKey,
    );
    _userEvaluationCacheWarmups[scopeKey] = warmup;
    try {
      await warmup;
    } finally {
      _userEvaluationCacheWarmups.remove(scopeKey);
    }
  }

  Future<void> _warmUserEvaluationCache({
    required int userId,
    required String scopeKey,
  }) async {
    if (!await _canUseRemoteSync()) {
      return;
    }

    try {
      const limit = 1000;
      var page = 1;
      var totalPages = 1;
      final fetched = <UserEvaluation>[];

      while (page <= totalPages) {
        final response = await _evaluationsServices.getUserEvaluationsPage(
          userId,
          limit: limit,
          page: page,
        );
        fetched.addAll(response.data);
        totalPages = response.totalPages > 0 ? response.totalPages : 1;
        page += 1;
      }

      await _mergeCachedUserEvaluations(
        userId: userId,
        evaluations: fetched,
      );

      if (fetched.isNotEmpty) {
        final mergedByAyahId = <int, UserEvaluation>{
          for (final evaluation in userEvaluations)
            if ((evaluation.ayah?.id ?? evaluation.ayahId) != null)
              (evaluation.ayah?.id ?? evaluation.ayahId)!: evaluation,
        };
        for (final evaluation in fetched) {
          final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
          if (ayahId != null) {
            mergedByAyahId[ayahId] = evaluation;
          }
        }
        userEvaluations = mergedByAyahId.values.toList(growable: true);
        _refreshUserEvaluationMetadata();
      }

      _hydratedUserEvaluationScopes.add(scopeKey);
      _debugChart(
        'cache:warm_complete',
        userId: userId,
        entryCount: fetched.length,
      );
    } catch (error) {
      _debugChart(
        'cache:warm_error',
        userId: userId,
        error: error.toString().replaceFirst('Exception: ', '').trim(),
      );
    }
  }

  Future<void> _mergeCachedUserEvaluations({
    required int userId,
    required Iterable<UserEvaluation> evaluations,
  }) async {
    final scopeKey = await _resolveChartCacheScopeKey(userId);
    final existing = await _readCachedUserEvaluations(scopeKey: scopeKey);
    final mergedByAyahId = <int, UserEvaluation>{
      for (final evaluation in existing)
        if ((evaluation.ayah?.id ?? evaluation.ayahId) != null)
          (evaluation.ayah?.id ?? evaluation.ayahId)!: evaluation,
    };

    for (final evaluation in evaluations) {
      final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
      if (ayahId == null) {
        continue;
      }
      mergedByAyahId[ayahId] = evaluation;
    }

    await _offlineStore.cacheUserEvaluationsJson(
      scopeKey: scopeKey,
      rawJson: jsonEncode(
        mergedByAyahId.values
            .map((evaluation) => evaluation.toCacheJson())
            .toList(growable: false),
      ),
    );
  }

  Future<void> _persistEvaluationPayloadToLocalCache(
    Map<String, dynamic> body,
  ) async {
    final userId = await _resolveAuthenticatedUserId();
    if (userId == null) {
      return;
    }

    final updatedEvaluations = <UserEvaluation>[];
    final singleAyahId = _asInt(body['ayahId']);
    if (singleAyahId != null) {
      updatedEvaluations.add(
        UserEvaluation(
          ayahId: singleAyahId,
          memoId: body.containsKey('memo_id') ? _asInt(body['memo_id']) : null,
          compreId:
              body.containsKey('compre_id') ? _asInt(body['compre_id']) : null,
          comment: body.containsKey('comment')
              ? _asNullableString(body['comment'])
              : null,
        ),
      );
    }

    final bulkAyahIds = body['ayahIds'];
    if (bulkAyahIds is List) {
      for (final rawAyahId in bulkAyahIds) {
        final ayahId = _asInt(rawAyahId);
        if (ayahId == null) {
          continue;
        }
        updatedEvaluations.add(
          UserEvaluation(
            ayahId: ayahId,
            memoId:
                body.containsKey('memo_id') ? _asInt(body['memo_id']) : null,
            compreId: body.containsKey('compre_id')
                ? _asInt(body['compre_id'])
                : null,
            comment: body.containsKey('comment')
                ? _asNullableString(body['comment'])
                : null,
          ),
        );
      }
    }

    if (updatedEvaluations.isEmpty) {
      return;
    }

    await _mergeCachedUserEvaluations(
      userId: userId,
      evaluations: updatedEvaluations,
    );
  }

  Future<int?> _resolveAuthenticatedUserId() async {
    final accessToken = await SecureSessionStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final parts = accessToken.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      return _asInt(decoded['sub']);
    } catch (_) {
      return null;
    }
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
