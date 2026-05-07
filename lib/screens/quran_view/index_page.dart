import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:sahifaty/providers/language_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sahifaty/controllers/ayat_controller.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/services/evaluations_services.dart';
import 'package:sahifaty/services/local_quran_chart_service.dart';
import 'package:sahifaty/services/school_filter_scope_service.dart';
import 'package:sahifaty/services/teacher_recommendations_service.dart';
import 'package:sahifaty/services/users_services.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import '../../controllers/general_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../core/reading/mushaf_page_layout.dart';
import '../../core/reading/reading_session.dart';
import '../../core/utils/surah_localization.dart';
import '../../models/surah.dart';
import '../../providers/general_provider.dart';
import '../../services/mushaf_layout_service.dart';
import '../widgets/global_drawer.dart';
import '../widgets/assessment_input_dialog.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/pending_sync_banner.dart';
import '../widgets/quran_filter_runtime.dart';
import '../widgets/teacher_recommendation_badge.dart';
import '../widgets/unified_quran_filter_sheet.dart';

enum _ReadingNavigationMode { page, hizbQuarter }

class IndexPage extends StatefulWidget {
  static const String routeName = '/read';

  const IndexPage(
      {super.key,
      required this.surah,
      required this.filterTypeId,
      this.hizb,
      this.hizbQuarter,
      this.juz,
      this.page,
      this.restoredPage,
      this.restoredHizbQuarter});

  factory IndexPage.fromReadingSession(ReadingSession session) {
    return IndexPage(
      surah: session.surah,
      filterTypeId: session.filterTypeId,
      juz: session.juz,
      hizb: session.hizb,
      restoredPage: session.currentPage,
      restoredHizbQuarter: session.currentHizbQuarter,
    );
  }

  factory IndexPage.fromRouteParameters(Map<String, String> parameters) {
    final surahId = int.tryParse(parameters['surahId'] ?? '');
    if (surahId == null) {
      throw ArgumentError('Missing route parameter: surahId');
    }

    return IndexPage(
      surah: Surah(
        id: surahId,
        nameAr: parameters['surahNameAr'] ?? '',
        ayahCount: int.tryParse(parameters['ayahCount'] ?? '') ?? 0,
      ),
      filterTypeId:
          int.tryParse(parameters['filterTypeId'] ?? '') ?? FilterTypes.thirds,
      hizb: int.tryParse(parameters['hizb'] ?? ''),
      hizbQuarter: int.tryParse(parameters['hizbQuarter'] ?? ''),
      juz: int.tryParse(parameters['juz'] ?? ''),
      page: int.tryParse(parameters['page'] ?? ''),
      restoredPage: int.tryParse(parameters['restoredPage'] ?? ''),
      restoredHizbQuarter:
          int.tryParse(parameters['restoredHizbQuarter'] ?? ''),
    );
  }

  static Map<String, String> routeParameters({
    required Surah surah,
    required int filterTypeId,
    int? hizb,
    int? hizbQuarter,
    int? juz,
    int? page,
    int? restoredPage,
    int? restoredHizbQuarter,
  }) {
    return <String, String>{
      'surahId': surah.id.toString(),
      'surahNameAr': surah.nameAr,
      'ayahCount': surah.ayahCount.toString(),
      'filterTypeId': filterTypeId.toString(),
      if (hizb != null) 'hizb': hizb.toString(),
      if (hizbQuarter != null) 'hizbQuarter': hizbQuarter.toString(),
      if (juz != null) 'juz': juz.toString(),
      if (page != null) 'page': page.toString(),
      if (restoredPage != null) 'restoredPage': restoredPage.toString(),
      if (restoredHizbQuarter != null)
        'restoredHizbQuarter': restoredHizbQuarter.toString(),
    };
  }

  static Map<String, String> routeParametersForSession(ReadingSession session) {
    return routeParameters(
      surah: session.surah,
      filterTypeId: session.filterTypeId,
      hizb: session.hizb,
      juz: session.juz,
      restoredPage: session.currentPage,
      restoredHizbQuarter: session.currentHizbQuarter,
    );
  }

  final Surah surah;
  final int filterTypeId;
  final int? hizb;
  final int? hizbQuarter;
  final int? juz;
  final int? page;
  final int? restoredPage;
  final int? restoredHizbQuarter;

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with WidgetsBindingObserver {
  final gc = GeneralController();
  final ReadingSessionStore _readingSessionStore = ReadingSessionStore();
  OverlayEntry? _menuEntry;
  final List<Ayat> _navigationScopeAyat = [];
  final List<Ayat> _ayat = [];
  final List<Ayat> _allAyat = [];
  final Map<int, List<Ayat>> _allAyatByPage = <int, List<Ayat>>{};
  final Map<int, MushafPageLayout> _mushafLayoutsByPage =
      <int, MushafPageLayout>{};
  _ReadingNavigationMode _navigationMode = _ReadingNavigationMode.hizbQuarter;
  List<int> _pageSequence = <int>[];
  int? _currentPage;
  int? _initialPage;
  int? _currentHizbQuarter;
  int? _minHizbQuarter;
  int? _maxHizbQuarter;
  int? _initialHizbQuarter;
  final PageController _pageController = PageController();
  final Set<int> _hydratedEvaluationPages = <int>{};
  final Set<int> _hydratedRecommendationPages = <int>{};
  bool _isInitialLoad = true;
  bool _hasConnection = true;
  bool _isConnectivityResolved = false;
  bool _showMemorizationColors = true;
  bool _showComprehensionUnderline = true;
  bool _canOpenAssessment = true;
  bool _isAyahSelectionMode = false;
  bool _hasLoadedAllEvaluationCoverage = false;
  bool _hasAttemptedMushafLayoutLoad = false;
  String? _readingNotice;
  final Set<int> _selectedAyahKeys = <int>{};
  final Map<int, TapGestureRecognizer> _ayahTapRecognizers =
      <int, TapGestureRecognizer>{};
  final TeacherRecommendationsService _teacherRecommendationsService =
      TeacherRecommendationsService();
  final UsersServices _usersService = UsersServices();
  final LocalQuranChartService _localQuranChartService =
      const LocalQuranChartService();
  final SchoolFilterScopeService _schoolFilterScopeService =
      const SchoolFilterScopeService();
  final QuranFilterAvailabilityBuilder _filterAvailabilityBuilder =
      const QuranFilterAvailabilityBuilder();
  User? _viewerUser;
  Surah? _activeSurah;
  Set<int>? _activeReaderAllowedSchoolAyahIds;

  // Reading display filter (fades non-matching ayahs in the rendered text).
  final Set<String> _filterAyahTypes = <String>{};
  final Set<String> _filterSubjectKeys = <String>{};
  final Set<String> _filterSchoolLevelIds = <String>{};
  final Set<int> _filterMemoEvaluationIds = <int>{};
  final Set<int> _filterCompreEvaluationIds = <int>{};

  // Reader scope uses the same chart-style equation boundary as
  // QuranChartFilters: thirds narrow juzs, and surah/juz selections compose
  // as intersections instead of replacing each other.
  final Set<int> _filterThirds = <int>{};
  final Set<int> _filterJuzs = <int>{};
  final Set<int> _filterSurahIds = <int>{};

  bool get _hasActiveDisplayFilter =>
      _filterAyahTypes.isNotEmpty ||
      _filterSubjectKeys.isNotEmpty ||
      _filterSchoolLevelIds.isNotEmpty ||
      _filterMemoEvaluationIds.isNotEmpty ||
      _filterCompreEvaluationIds.isNotEmpty;

  bool get _hasActiveScopeFilter =>
      _filterThirds.isNotEmpty ||
      _filterJuzs.isNotEmpty ||
      _filterSurahIds.isNotEmpty;

  bool get _hasAnyActiveReaderFilter =>
      _hasActiveDisplayFilter || _hasActiveScopeFilter;

  bool get _hasSelectedAyahs => _selectedAyahKeys.isNotEmpty;

  int _ayahSelectionKey(Ayat ayah) {
    return ayah.id ?? ((ayah.surah.id * 1000) + ayah.ayahNo);
  }

  void _toggleAyahSelectionMode() {
    setState(() {
      final nextValue = !_isAyahSelectionMode;
      _isAyahSelectionMode = nextValue;
      if (!nextValue) {
        _selectedAyahKeys.clear();
      }
    });
  }

  void _toggleAyahSelection(Ayat ayah) {
    final ayahKey = _ayahSelectionKey(ayah);
    setState(() {
      if (_selectedAyahKeys.contains(ayahKey)) {
        _selectedAyahKeys.remove(ayahKey);
      } else {
        _selectedAyahKeys.add(ayahKey);
      }
    });
  }

  List<Ayat> _selectedAyahs() {
    return _allAyat
        .where((ayah) => _selectedAyahKeys.contains(_ayahSelectionKey(ayah)))
        .toList(growable: false);
  }

  List<String> _sharedSubjectKeysForAyahs(List<Ayat> ayahs) {
    if (ayahs.isEmpty) {
      return const <String>[];
    }

    final shared = <String>{
      ...?ayahs.first.subjects,
    };
    for (final ayah in ayahs.skip(1)) {
      shared.removeWhere((key) => !(ayah.subjects?.contains(key) ?? false));
      if (shared.isEmpty) {
        break;
      }
    }

    final result = shared.toList(growable: false);
    result.sort((left, right) => left.compareTo(right));
    return result;
  }

  UnifiedFilterSelection _currentReaderFilterSelection() {
    return UnifiedFilterSelection(
      thirds: {..._filterThirds},
      juzs: {..._filterJuzs},
      surahIds: {..._filterSurahIds},
      ayahTypes: {..._filterAyahTypes},
      subjectKeys: {..._filterSubjectKeys},
      schoolLevelIds: {..._filterSchoolLevelIds},
      memoEvaluationIds: {..._filterMemoEvaluationIds},
      compreEvaluationIds: {..._filterCompreEvaluationIds},
    );
  }

  QuranChartFilters _currentReaderChartFilters() {
    return unifiedSelectionToChartFilters(_currentReaderFilterSelection());
  }

  bool _matchesSelectedEvaluationFilters(UserEvaluation? userEvaluation) {
    if (_filterMemoEvaluationIds.isNotEmpty) {
      final memoId = userEvaluation?.memoId;
      if (memoId == null || !_filterMemoEvaluationIds.contains(memoId)) {
        return false;
      }
    }

    if (_filterCompreEvaluationIds.isNotEmpty) {
      final compreId = userEvaluation?.compreId;
      if (compreId == null || !_filterCompreEvaluationIds.contains(compreId)) {
        return false;
      }
    }

    return true;
  }

  bool _ayahMatchesActiveReaderSelection(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
  ) {
    final userEvaluation =
        ayah.userEvaluation ?? evaluationsProvider.getUserEvaluationForAyah(ayah.id);
    if (!_matchesSelectedEvaluationFilters(userEvaluation)) {
      return false;
    }

    final filters = _currentReaderChartFilters();
    return _localQuranChartService.filterAyat(
      <Ayat>[ayah],
      filters,
      allowedSchoolAyahIds: _activeReaderAllowedSchoolAyahIds,
    ).isNotEmpty;
  }

  String _tr(String key) => key.tr;

  String _trParams(String key, Map<String, String> params) =>
      key.trParams(params);

  String _buildAyahPreviewTitle(Ayat ayah) {
    final raw = quran
        .getVerse(ayah.surah.id, ayah.ayahNo, verseEndSymbol: false)
        .trim();
    const maxLen = 50;
    final preview =
        raw.length > maxLen ? '${raw.substring(0, maxLen).trim()}…' : raw;
    return '$preview (${ayah.ayahNo})';
  }

  Future<List<Ayat>> _readerAvailabilitySourceAyat(
    int userId,
    EvaluationsProvider evaluationsProvider,
  ) async {
    if (_filterMemoEvaluationIds.isEmpty && _filterCompreEvaluationIds.isEmpty) {
      return List<Ayat>.from(_allAyat, growable: false);
    }

    final resolvedEvaluations =
        await evaluationsProvider.loadResolvedUserEvaluations(userId);
    final evaluationsByAyahId = <int, UserEvaluation>{
      for (final evaluation in resolvedEvaluations)
        if ((evaluation.ayah?.id ?? evaluation.ayahId) != null)
          (evaluation.ayah?.id ?? evaluation.ayahId)!: evaluation,
    };

    return _allAyat.where((ayah) {
      final ayahId = ayah.id;
      final userEvaluation = ayah.userEvaluation ??
          (ayahId == null ? null : evaluationsByAyahId[ayahId]);
      if (userEvaluation != null) {
        ayah.userEvaluation ??= userEvaluation;
      }
      return _matchesSelectedEvaluationFilters(userEvaluation);
    }).toList(growable: false);
  }

  Future<List<Ayat>> _filterAyatForReaderFilters(
    Iterable<Ayat> sourceAyat,
    QuranChartFilters filters,
  ) async {
    final allowedSchoolAyahIds = await _schoolFilterScopeService
        .resolveAllowedAyahIds(filters);
    return _localQuranChartService.filterAyat(
      sourceAyat.toList(growable: false),
      filters,
      allowedSchoolAyahIds: allowedSchoolAyahIds,
    );
  }

  Future<UnifiedFilterAvailableData> _buildReaderAvailableData(
    int userId,
    EvaluationsProvider evaluationsProvider,
  ) async {
    if (evaluationsProvider.evaluations.isEmpty) {
      try {
        await evaluationsProvider.getAllEvaluations();
      } catch (_) {
        // Keep going so the sheet can still render content-based filters.
      }
    }

    final sourceAyat = await _readerAvailabilitySourceAyat(
      userId,
      evaluationsProvider,
    );
    return _filterAvailabilityBuilder.build(
      filters: _currentReaderChartFilters(),
      loadScopedAyat: (filters) => _filterAyatForReaderFilters(
        sourceAyat,
        filters,
      ),
      memorizationEvaluations: evaluationsProvider.memorizationEvaluations,
      comprehensionEvaluations: evaluationsProvider.comprehensionEvaluations,
    );
  }

  Future<void> _refreshReaderAllowedSchoolScope() async {
    final filters = _currentReaderChartFilters();
    if (filters.schoolIds.isEmpty && filters.schoolLevelPairs.isEmpty) {
      _activeReaderAllowedSchoolAyahIds = null;
      return;
    }

    _activeReaderAllowedSchoolAyahIds = await _schoolFilterScopeService
        .resolveAllowedAyahIds(filters);
  }

  bool get _isPageNavigation =>
      _navigationMode == _ReadingNavigationMode.page &&
      _pageSequence.isNotEmpty &&
      _currentPage != null;

  bool get _hasNavigationControls =>
      _isPageNavigation || _currentHizbQuarter != null;

  // Page chevrons + horizontal swipe traverse the full mushaf by default
  // (pages 1..604) and never get stuck at the boundary of the originally
  // loaded scope. When the reader filter narrows the scope to a set of
  // surahs, navigation is clamped to that scope (Hard-scope behavior).
  static const int _mushafFirstPage = 1;
  static const int _mushafLastPage = 604;
  static const double _mushafLineHeight = 31;
  static const double _mushafWordFontSize = 20;
  static const double _mushafLandscapeLineHeight = 40;
  static const double _mushafLandscapeWordFontSize = 25.5;
  static const Map<int, Map<int, _MushafLineFineTune>>
      _mushafLineFineTuneOverrides = <int, Map<int, _MushafLineFineTune>>{};
  static final RegExp _mushafVisualMarksPattern = RegExp(
    r'[\s\u0640\u064B-\u065F\u0670\u06D6-\u06ED]',
  );

  String get _navigationProgressLabel {
    if (_isPageNavigation && _currentPage != null) {
      return '$_currentPage / 604';
    }

    return 'Q${_currentHizbQuarter ?? '-'}';
  }

  int? get _currentNavigationJuz {
    final currentPage = _currentPage;
    if (currentPage != null) {
      final currentPageAyat = _ayatForPage(currentPage);
      if (currentPageAyat.isNotEmpty) {
        return currentPageAyat.first.juz;
      }
    }
    return widget.juz;
  }

  bool get _canTapNavigationControls {
    if (_isPageNavigation) {
      return _currentPage != null;
    }
    return _currentHizbQuarter != null;
  }

  int _compareAyatOrder(Ayat left, Ayat right) {
    if (left.id != null && right.id != null) {
      return left.id!.compareTo(right.id!);
    }

    final surahComparison = left.surah.id.compareTo(right.surah.id);
    if (surahComparison != 0) {
      return surahComparison;
    }

    return left.ayahNo.compareTo(right.ayahNo);
  }

  Future<void> _ensureAllAyatIndexedByPage() async {
    if (_allAyat.isNotEmpty && _allAyatByPage.isNotEmpty) {
      return;
    }

    final allAyat = await AyatController().loadAllAyat();
    allAyat.sort(_compareAyatOrder);

    final byPage = <int, List<Ayat>>{};
    for (final ayah in allAyat) {
      final page = ayah.page;
      if (page == null) {
        continue;
      }
      (byPage[page] ??= <Ayat>[]).add(ayah);
    }

    _allAyat
      ..clear()
      ..addAll(allAyat);
    _allAyatByPage
      ..clear()
      ..addAll(byPage);
  }

  Future<void> _ensureMushafLayoutsLoaded() async {
    if (_hasAttemptedMushafLayoutLoad) {
      return;
    }

    _hasAttemptedMushafLayoutLoad = true;
    final layouts = await MushafLayoutService.loadAllPages();
    _mushafLayoutsByPage
      ..clear()
      ..addAll(layouts);
  }

  List<Ayat> _ayatForPage(int page) => _allAyatByPage[page] ?? const <Ayat>[];

  int? get _currentPageSequenceIndex {
    final currentPage = _currentPage;
    if (currentPage == null) {
      return null;
    }
    final index = _pageSequence.indexOf(currentPage);
    return index == -1 ? null : index;
  }

  List<int> _pagesAroundIndex(int index, {int radius = 2}) {
    if (_pageSequence.isEmpty) {
      return const <int>[];
    }

    final start = math.max(0, index - radius);
    final end = math.min(_pageSequence.length - 1, index + radius);
    return _pageSequence.sublist(start, end + 1);
  }

  List<int> _pagesAroundCurrentPage({int radius = 2}) {
    final currentIndex = _currentPageSequenceIndex;
    if (currentIndex == null) {
      return const <int>[];
    }

    return _pagesAroundIndex(currentIndex, radius: radius);
  }

  Surah? _resolveSurahForPage(int? page) {
    if (page == null) {
      return null;
    }

    final pageAyat = _ayatForPage(page);
    if (pageAyat.isEmpty) {
      return null;
    }

    final firstAyah = pageAyat.first;
    return Surah(
      id: firstAyah.surah.id,
      nameAr: firstAyah.surah.nameAr,
      name: firstAyah.surah.name,
      ayahCount: quran.getVerseCount(firstAyah.surah.id),
    );
  }

  void _updateActivePageState(int page) {
    _currentPage = page;
    _activeSurah = _resolveSurahForPage(page) ?? _activeSurah ?? widget.surah;
    _ayat
      ..clear()
      ..addAll(_ayatForPage(page));
  }

  Future<void> _jumpToCurrentPageInList({bool animated = false}) async {
    final currentPage = _currentPage;
    if (currentPage == null || _pageSequence.isEmpty) {
      return;
    }

    final index = _pageSequence.indexOf(currentPage);
    if (index == -1 || !_pageController.hasClients) {
      return;
    }

    if (animated) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  Future<void> _ensureVisiblePageDataLoaded(
    int userId,
    EvaluationsProvider evaluationsProvider, {
    Iterable<int>? pages,
  }) async {
    final targetPages = (pages ?? _pagesAroundCurrentPage())
        .where((page) => _allAyatByPage.containsKey(page))
        .toSet()
        .toList()
      ..sort();

    if (targetPages.isEmpty) {
      return;
    }

    final evaluationPages = targetPages
        .where((page) => !_hydratedEvaluationPages.contains(page))
        .toList();
    if (evaluationPages.isNotEmpty) {
      final ayatIds = evaluationPages
          .expand(_ayatForPage)
          .map((ayah) => ayah.id)
          .whereType<int>()
          .toList();
      if (ayatIds.isNotEmpty) {
        await evaluationsProvider.mergeUserEvaluationsForAyatIds(
            userId, ayatIds);
      }

      for (final page in evaluationPages) {
        for (final ayah in _ayatForPage(page)) {
          ayah.userEvaluation =
              evaluationsProvider.getUserEvaluationForAyah(ayah.id);
        }
      }
      _hydratedEvaluationPages.addAll(evaluationPages);
    }

    final recommendationPages = targetPages
        .where((page) => !_hydratedRecommendationPages.contains(page))
        .toList();
    if (_hasConnection && recommendationPages.isNotEmpty) {
      final recommendationAyat =
          recommendationPages.expand(_ayatForPage).toList();
      final loadedRecommendations =
          await _loadTeacherRecommendations(userId, recommendationAyat);
      if (loadedRecommendations) {
        _hydratedRecommendationPages.addAll(recommendationPages);
      }
    }

    if (mounted && _currentPage != null) {
      setState(() {
        _ayat
          ..clear()
          ..addAll(_ayatForPage(_currentPage!));
      });
    }
  }

  Future<void> _ensureFilterEvaluationCoverage(
    int userId,
    EvaluationsProvider evaluationsProvider,
  ) async {
    if (_hasLoadedAllEvaluationCoverage ||
        (_filterMemoEvaluationIds.isEmpty &&
            _filterCompreEvaluationIds.isEmpty)) {
      return;
    }

    final ayatIds = _allAyat.map((ayah) => ayah.id).whereType<int>().toList();
    await evaluationsProvider.mergeUserEvaluationsForAyatIds(userId, ayatIds);
    for (final ayah in _allAyat) {
      ayah.userEvaluation =
          evaluationsProvider.getUserEvaluationForAyah(ayah.id);
    }
    _hasLoadedAllEvaluationCoverage = true;
  }

  List<int> _computeNavigablePages(EvaluationsProvider evaluationsProvider) {
    if (!_hasAnyActiveReaderFilter) {
      return List<int>.generate(
        _mushafLastPage,
        (index) => _mushafFirstPage + index,
      );
    }

    final pages = <int>[];
    for (var page = _mushafFirstPage; page <= _mushafLastPage; page++) {
      final pageAyat = _ayatForPage(page);
      if (pageAyat.isEmpty) {
        continue;
      }

      final hasMatch = pageAyat.any(
        (ayah) => _ayahMatchesActiveReaderSelection(ayah, evaluationsProvider),
      );
      if (hasMatch) {
        pages.add(page);
      }
    }

    return pages;
  }

  Future<bool> _rebuildNavigablePages({
    required int userId,
    required EvaluationsProvider evaluationsProvider,
    bool jumpToFirstMatch = false,
  }) async {
    await _ensureAllAyatIndexedByPage();
    await _ensureFilterEvaluationCoverage(userId, evaluationsProvider);

    final nextPageSequence = _computeNavigablePages(evaluationsProvider);
    if (nextPageSequence.isEmpty) {
      return false;
    }

    final preferredPage = jumpToFirstMatch
        ? nextPageSequence.first
        : (_currentPage ??
            widget.restoredPage ??
            widget.page ??
            nextPageSequence.first);
    final resolvedPage = _resolveClosestAvailableValue(
      nextPageSequence,
      preferredPage,
    );

    if (!mounted) {
      _pageSequence = nextPageSequence;
      _navigationMode = _ReadingNavigationMode.page;
      _updateActivePageState(resolvedPage);
      _initialPage ??= resolvedPage;
      return true;
    }

    setState(() {
      _pageSequence = nextPageSequence;
      _navigationMode = _ReadingNavigationMode.page;
      _updateActivePageState(resolvedPage);
      _initialPage ??= resolvedPage;
    });
    return true;
  }

  Future<List<Ayat>> _loadNavigationScopeAyat() async {
    if (widget.hizbQuarter != null) {
      return AyatController().loadAyatByHizbQuarter(widget.hizbQuarter!);
    }

    if ((widget.filterTypeId == FilterTypes.parts ||
            widget.filterTypeId == FilterTypes.thirds) &&
        widget.juz != null) {
      return AyatController().loadAyatByJuz(widget.juz!);
    }

    if (widget.hizb != null) {
      return AyatController().loadAyatByHizb(widget.hizb!);
    }

    return AyatController().loadAyatBySurah(widget.surah.id);
  }

  List<int> _extractSortedUniqueValues(
    Iterable<Ayat> ayat,
    int? Function(Ayat ayah) selector,
  ) {
    final values = ayat.map(selector).whereType<int>().toSet().toList();
    values.sort();
    return values;
  }

  int _resolveClosestAvailableValue(List<int> values, int? preferredValue) {
    if (values.isEmpty) {
      throw StateError('Cannot resolve a navigation value from an empty list.');
    }

    if (preferredValue == null) {
      return values.first;
    }

    if (values.contains(preferredValue)) {
      return preferredValue;
    }

    for (final value in values) {
      if (value >= preferredValue) {
        return value;
      }
    }

    return values.last;
  }

  int? _firstValueForSelectedSurah(
    Iterable<Ayat> ayat,
    int? Function(Ayat ayah) selector,
  ) {
    for (final item in ayat) {
      final value = selector(item);
      if (item.surah.id == widget.surah.id && value != null) {
        return value;
      }
    }

    return null;
  }

  static const Color _lightReadingSurfaceColor = Color(0xFFFBF7EF);
  static const Color _darkReadingSurfaceColor = Color(0xFF15171C);

  Color _readingSurfaceColor(bool isDarkMode) {
    return isDarkMode ? _darkReadingSurfaceColor : _lightReadingSurfaceColor;
  }

  double _contrastRatio(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _resolveReadableVerseColor({
    required Color preferredColor,
    required Color fallbackColor,
    required bool isDarkMode,
  }) {
    final surfaceColor = _readingSurfaceColor(isDarkMode);
    final baseCandidate = preferredColor.a >= 1
        ? preferredColor
        : Color.alphaBlend(preferredColor, surfaceColor);

    if (_contrastRatio(baseCandidate, surfaceColor) >= 4.5) {
      return baseCandidate;
    }

    final targetColor = isDarkMode ? Colors.white : fallbackColor;
    for (var step = 1; step <= 8; step++) {
      final candidate = Color.lerp(baseCandidate, targetColor, step / 8)!;
      if (_contrastRatio(candidate, surfaceColor) >= 4.5) {
        return candidate;
      }
    }

    return targetColor;
  }

  Future<void> _ensureNavigationInitialized() async {
    if (_navigationScopeAyat.isEmpty) {
      final scopeAyat = await _loadNavigationScopeAyat();
      scopeAyat.sort(_compareAyatOrder);
      _navigationScopeAyat
        ..clear()
        ..addAll(scopeAyat);
    }

    if (_navigationScopeAyat.isEmpty) {
      return;
    }

    final pageSequence = _extractSortedUniqueValues(
      _navigationScopeAyat,
      (ayah) => ayah.page,
    );
    final hasCompletePageData = pageSequence.isNotEmpty &&
        _navigationScopeAyat.every((ayah) => ayah.page != null);

    if (hasCompletePageData) {
      _navigationMode = _ReadingNavigationMode.page;
      _pageSequence = pageSequence;

      final preferredPage = widget.restoredPage ??
          widget.page ??
          _firstValueForSelectedSurah(
            _navigationScopeAyat,
            (ayah) => ayah.page,
          );

      _currentPage =
          _resolveClosestAvailableValue(_pageSequence, preferredPage);
      _initialPage ??= _currentPage;
      return;
    }

    _navigationMode = _ReadingNavigationMode.hizbQuarter;

    final quarterSequence = _extractSortedUniqueValues(
      _navigationScopeAyat,
      (ayah) => ayah.hizbQuarter,
    );

    if (quarterSequence.isEmpty) {
      return;
    }

    final preferredQuarter = widget.restoredHizbQuarter ??
        widget.hizbQuarter ??
        _firstValueForSelectedSurah(
          _navigationScopeAyat,
          (ayah) => ayah.hizbQuarter,
        );

    _minHizbQuarter = quarterSequence.first;
    _maxHizbQuarter = quarterSequence.last;
    _currentHizbQuarter = _resolveClosestAvailableValue(
      quarterSequence,
      preferredQuarter,
    );
    if (widget.filterTypeId == FilterTypes.parts ||
        widget.filterTypeId == FilterTypes.thirds) {
      _initialHizbQuarter = null;
    } else {
      _initialHizbQuarter ??= _currentHizbQuarter;
    }
  }

  Future<void> _loadAdjacentChunk({required bool forward}) async {
    final selectedUser = context.read<UsersProvider>().selectedUser;
    if (selectedUser == null) {
      return;
    }

    final userId = selectedUser.id;
    final evalProvider = context.read<EvaluationsProvider>();

    if (_isPageNavigation) {
      final currentIndex = _currentPageSequenceIndex;
      if (currentIndex == null) {
        return;
      }

      final nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
      if (nextIndex < 0 || nextIndex >= _pageSequence.length) {
        return;
      }

      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
      // State update (setState + evaluations load + persist) handled in
      // PageView.onPageChanged when the animation completes.
      return;
    }

    if (_currentHizbQuarter == null) {
      return;
    }

    final nextQuarter =
        forward ? _currentHizbQuarter! + 1 : _currentHizbQuarter! - 1;
    if ((_minHizbQuarter != null && nextQuarter < _minHizbQuarter!) ||
        (_maxHizbQuarter != null && nextQuarter > _maxHizbQuarter!)) {
      return;
    }

    setState(() {
      _currentHizbQuarter = nextQuarter;
    });
    await _loadAyat(userId, evalProvider);
    _scheduleReadingScrollResetToTop();
  }

  void _scheduleReadingScrollResetToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentPage == null) {
        return;
      }
      unawaited(_jumpToCurrentPageInList());
    });
  }

  TapGestureRecognizer _getAyahTapRecognizer(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
    LanguageProvider languageProvider,
  ) {
    final usersProvider = context.read<UsersProvider>();
    final ayahKey = _ayahSelectionKey(ayah);
    final recognizer = _ayahTapRecognizers.putIfAbsent(
      ayahKey,
      () => TapGestureRecognizer(),
    );

    if (!_canTapAyah(usersProvider)) {
      recognizer.onTap = null;
      return recognizer;
    }

    if (_isAyahSelectionMode) {
      recognizer.onTap = () => _toggleAyahSelection(ayah);
      return recognizer;
    }

    recognizer.onTap = () => _openAssessmentDialogForAyah(
          ayah,
          evaluationsProvider,
          languageProvider,
        );

    return recognizer;
  }

  Future<void> _loadReadingDisplayPreferences(
      UsersProvider usersProvider) async {
    await usersProvider.ensureReadingDisplayPreferencesLoaded();
    if (!mounted) {
      return;
    }

    setState(() {
      _showMemorizationColors = usersProvider.showMemorizationColors;
      _showComprehensionUnderline = usersProvider.showComprehensionUnderline;
    });
  }

  Future<void> _updateReadingDisplayPreferences({
    bool? showMemorizationColors,
    bool? showComprehensionUnderline,
  }) async {
    final usersProvider = context.read<UsersProvider>();

    setState(() {
      _showMemorizationColors =
          showMemorizationColors ?? _showMemorizationColors;
      _showComprehensionUnderline =
          showComprehensionUnderline ?? _showComprehensionUnderline;
    });

    try {
      await usersProvider.updateReadingDisplayPreferences(
        showMemorizationColors: showMemorizationColors,
        showComprehensionUnderline: showComprehensionUnderline,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _showMemorizationColors = usersProvider.showMemorizationColors;
        _showComprehensionUnderline = usersProvider.showComprehensionUnderline;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _showMemorizationColors = usersProvider.showMemorizationColors;
        _showComprehensionUnderline = usersProvider.showComprehensionUnderline;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('quran_reading_display_preferences_save_error'),
          ),
        ),
      );
    }
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  Future<void> _refreshConnectivity() async {
    final hasConnection = await gc.checkConnectivity();
    if (!mounted) {
      return;
    }

    setState(() {
      _hasConnection = hasConnection;
      _isConnectivityResolved = true;
    });
  }

  Future<User?> _ensureViewerUserLoaded() async {
    if (_viewerUser != null) {
      return _viewerUser;
    }

    try {
      final cachedProfile = await _usersService.getCachedCurrentUserProfile();
      if (cachedProfile != null) {
        final viewer = User.fromJson(cachedProfile);
        if (mounted) {
          setState(() {
            _viewerUser = viewer;
          });
        } else {
          _viewerUser = viewer;
        }
        return viewer;
      }

      final profile = await _usersService.getCurrentUserProfile();
      final viewer = User.fromJson(profile);
      if (mounted) {
        setState(() {
          _viewerUser = viewer;
        });
      } else {
        _viewerUser = viewer;
      }
      return viewer;
    } catch (_) {
      return _viewerUser;
    }
  }

  bool _isSupervisorViewingStudent(UsersProvider usersProvider) {
    final viewer = _viewerUser;
    final selectedUser = usersProvider.selectedUser;
    if (viewer == null || selectedUser == null) {
      return false;
    }

    return usersProvider.hasPushedSelectedUser && viewer.id != selectedUser.id;
  }

  bool _canTapAyah(UsersProvider usersProvider) {
    return _canOpenAssessment;
  }

  int? _evaluationTargetUserId(UsersProvider usersProvider) {
    if (!_isSupervisorViewingStudent(usersProvider)) {
      return null;
    }

    return usersProvider.selectedUser?.id;
  }

  Future<void> _openAssessmentDialogForAyah(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
    LanguageProvider languageProvider,
  ) async {
    await _ensureViewerUserLoaded();
    if (!mounted) {
      return;
    }

    final usersProvider = context.read<UsersProvider>();
    final targetUserId = _evaluationTargetUserId(usersProvider);

    if (!_canOpenAssessment) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'quran_reading_assessment_unavailable_notice',
            ),
          ),
        ),
      );
      return;
    }

    _removeMenu();

    final savedScrollOffset =
        _pageController.hasClients ? _pageController.offset : 0.0;
    final selection = await showAssessmentInputDialog(
      context: context,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
      initialMemoId: ayah.userEvaluation?.memoId,
      initialCompreId: ayah.userEvaluation?.compreId,
      initialComment: ayah.userEvaluation?.comment,
      subjectKeys: ayah.subjects ?? const <Object?>[],
      enableCommentField: true,
      title: _buildAyahPreviewTitle(ayah),
    );

    if (selection == null || !mounted) {
      return;
    }

    await EvaluationsController().sendEvaluationSelection(
      ayah,
      evaluationsProvider,
      null,
      targetUserId: targetUserId,
      memoId: selection.memoId,
      compreId: selection.compreId,
      comment: selection.comment,
      memoChanged: selection.memoChanged,
      commentChanged: selection.commentChanged,
      compreChanged: selection.compreChanged,
    );

    if (!mounted) {
      return;
    }

    final merged = EvaluationsController().mergeUserEvaluation(
      existing: ayah.userEvaluation,
      ayah: ayah,
      evaluationsProvider: evaluationsProvider,
      memoId: selection.memoId,
      compreId: selection.compreId,
      comment: selection.comment,
      memoChanged: selection.memoChanged,
      commentChanged: selection.commentChanged,
      compreChanged: selection.compreChanged,
    );

    evaluationsProvider.upsertUserEvaluation(merged);
    setState(() {
      ayah.userEvaluation = merged;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpTo(savedScrollOffset);
      }
    });
  }

  Future<void> _openBulkAssessmentForSelectedAyahs(
    EvaluationsProvider evaluationsProvider,
    LanguageProvider languageProvider,
  ) async {
    if (!_canOpenAssessment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'quran_reading_assessment_unavailable_notice',
            ),
          ),
        ),
      );
      return;
    }

    final ayahs = _selectedAyahs();
    if (ayahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_verses_found_to_evaluate'.tr)),
      );
      return;
    }

    _removeMenu();

    final savedScrollOffset =
        _pageController.hasClients ? _pageController.offset : 0.0;
    final selection = await showAssessmentInputDialog(
      context: context,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
      subjectKeys: _sharedSubjectKeysForAyahs(ayahs),
      enableCommentField: false,
      showSubjectSummary: true,
      subjectSummaryLabel: 'assessment_dialog_shared_subjects_label'.tr,
      title: 'quran_reading_bulk_assessment_title'.trParams({
        'count': ayahs.length.toString(),
      }),
    );

    if (selection == null || !mounted || !selection.hasChanges) {
      return;
    }

    final usersProvider = context.read<UsersProvider>();
    final targetUserId = _evaluationTargetUserId(usersProvider);

    try {
      await EvaluationsController().sendMultipleEvaluationSelection(
        ayahs,
        evaluationsProvider,
        null,
        'verses'.tr,
        targetUserId: targetUserId,
        memoId: selection.memoId,
        compreId: selection.compreId,
        comment: null,
        memoChanged: selection.memoChanged,
        commentChanged: false,
        compreChanged: selection.compreChanged,
      );
    } catch (_) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      for (final ayah in ayahs) {
        final merged = EvaluationsController().mergeUserEvaluation(
          existing: ayah.userEvaluation,
          ayah: ayah,
          evaluationsProvider: evaluationsProvider,
          memoId: selection.memoId,
          compreId: selection.compreId,
          comment: null,
          memoChanged: selection.memoChanged,
          commentChanged: false,
          compreChanged: selection.compreChanged,
        );

        ayah.userEvaluation = merged;
        evaluationsProvider.upsertUserEvaluation(merged);
      }

      _selectedAyahKeys.clear();
      _isAyahSelectionMode = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpTo(savedScrollOffset);
      }
    });
  }

  Future<void> _persistReadingSession({bool shouldAutoResume = true}) async {
    final selectedUser = context.read<UsersProvider>().selectedUser;
    if (selectedUser == null) {
      return;
    }

    final activeSurah = _activeSurah ?? widget.surah;

    await _readingSessionStore.save(
      ReadingSession(
        userId: selectedUser.id,
        surah: activeSurah,
        filterTypeId: widget.filterTypeId,
        juz: widget.juz,
        hizb: widget.hizb,
        currentPage: _isPageNavigation ? _currentPage : null,
        currentHizbQuarter: _currentHizbQuarter,
        shouldAutoResume: shouldAutoResume,
      ),
    );
  }

  Future<void> _handleExitReading() async {
    final selectedUser = context.read<UsersProvider>().selectedUser;
    await _readingSessionStore.updateAutoResumeForUser(
      selectedUser?.id,
      false,
    );

    if (!mounted) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      Get.back();
      return;
    }

    Get.off(const MainScreen());
  }

  Future<void> _navigateToJuz(int juz) async {
    await _ensureAllAyatIndexedByPage();
    int? targetPage;
    for (final ayah in _allAyat) {
      if (ayah.juz == juz && ayah.page != null) {
        targetPage = ayah.page;
        break;
      }
    }

    if (targetPage != null) {
      await _navigateToPage(targetPage);
    }
  }

  Future<void> _navigateToSurah(int surahNumber) async {
    await _navigateToPage(quran.getPageNumber(surahNumber, 1));
  }

  Future<void> _navigateToPage(int targetPage) async {
    if (targetPage < 1 ||
        targetPage > 604 ||
        !_pageSequence.contains(targetPage)) {
      return;
    }

    final selectedUser = context.read<UsersProvider>().selectedUser;
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final targetIndex = _pageSequence.indexOf(targetPage);

    setState(() {
      _updateActivePageState(targetPage);
    });

    if (selectedUser != null && targetIndex != -1) {
      await _ensureVisiblePageDataLoaded(
        selectedUser.id,
        evaluationsProvider,
        pages: _pagesAroundIndex(targetIndex),
      );
    }

    _scheduleReadingScrollResetToTop();
    await _persistReadingSession();
  }

  Future<void> _openJuzPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ReaderJuzPicker(
        currentJuz: widget.juz,
      ),
    );

    if (selected != null && mounted) {
      await _navigateToJuz(selected);
    }
  }

  Future<void> _openSurahPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ReaderSurahPicker(
        currentSurahId: widget.surah.id,
      ),
    );

    if (selected != null && mounted) {
      await _navigateToSurah(selected);
    }
  }

  Future<void> _openPagePicker() async {
    final currentPage = _currentPage;
    if (currentPage == null) {
      return;
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ReaderPagePicker(
        currentPage: currentPage,
        availablePages: _pageSequence,
      ),
    );

    if (selected != null && mounted) {
      await _navigateToPage(selected);
    }
  }

  Future<void> _openDisplayFilter() async {
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final selectedUser = context.read<UsersProvider>().selectedUser;
    if (selectedUser == null) {
      return;
    }
    await _ensureAllAyatIndexedByPage();
    final availableData = await _buildReaderAvailableData(
      selectedUser.id,
      evaluationsProvider,
    );
    if (!mounted) {
      return;
    }

    final result = await showQuranFilterSurface(
      context,
      initial: _currentReaderFilterSelection(),
      available: availableData,
      presentation: QuranFilterPresentation.sheet,
    );

    if (result != null && mounted) {
      setState(() {
        _filterAyahTypes
          ..clear()
          ..addAll(result.ayahTypes);
        _filterSubjectKeys
          ..clear()
          ..addAll(result.subjectKeys);
        _filterSchoolLevelIds
          ..clear()
          ..addAll(result.schoolLevelIds);
        _filterMemoEvaluationIds
          ..clear()
          ..addAll(result.memoEvaluationIds);
        _filterCompreEvaluationIds
          ..clear()
          ..addAll(result.compreEvaluationIds);
        _filterThirds
          ..clear()
          ..addAll(result.thirds);
        _filterJuzs
          ..clear()
          ..addAll(result.juzs);
        _filterSurahIds
          ..clear()
          ..addAll(result.surahIds);
      });
      await _refreshReaderAllowedSchoolScope();

      final rebuilt = await _rebuildNavigablePages(
        userId: selectedUser.id,
        evaluationsProvider: evaluationsProvider,
        jumpToFirstMatch: _hasAnyActiveReaderFilter,
      );
      if (!rebuilt) {
        return;
      }

      await _ensureVisiblePageDataLoaded(
        selectedUser.id,
        evaluationsProvider,
      );
      _scheduleReadingScrollResetToTop();
      await _persistReadingSession();
    }
  }

  Future<void> _setWakelockEnabled(bool enabled) async {
    if (kIsWeb) {
      return;
    }

    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> _loadAyat(
      int userId, EvaluationsProvider evaluationsProvider) async {
    await _refreshConnectivity();
    var canOpenAssessment = evaluationsProvider.evaluations.isNotEmpty;
    String? readingNotice;

    if (evaluationsProvider.evaluations.isEmpty) {
      try {
        await evaluationsProvider.getAllEvaluations();
      } catch (_) {
        canOpenAssessment = false;
        if (_hasConnection) {
          readingNotice = _tr(
            'quran_reading_assessment_options_error',
          );
        }
      }
    }

    canOpenAssessment = evaluationsProvider.evaluations.isNotEmpty;
    if (!_hasConnection) {
      readingNotice = canOpenAssessment
          ? _tr('quran_reading_connection_notice')
          : _tr('quran_reading_assessment_unavailable_notice');
    }

    await _ensureNavigationInitialized();
    await _ensureAllAyatIndexedByPage();
    await _ensureMushafLayoutsLoaded();
    await _refreshReaderAllowedSchoolScope();

    final rebuilt = await _rebuildNavigablePages(
      userId: userId,
      evaluationsProvider: evaluationsProvider,
    );
    if (!rebuilt) {
      return;
    }

    await _ensureVisiblePageDataLoaded(
      userId,
      evaluationsProvider,
    );

    if (_isInitialLoad && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_jumpToCurrentPageInList());
      });
    }
    _isInitialLoad = false;

    if (!mounted) {
      return;
    }

    setState(() {
      _canOpenAssessment = canOpenAssessment;
      _readingNotice = readingNotice;
      _selectedAyahKeys.clear();
      _isAyahSelectionMode = false;
      if (_currentPage != null) {
        _ayat
          ..clear()
          ..addAll(_ayatForPage(_currentPage!));
      }
    });

    await _persistReadingSession();
  }

  Future<void> _showReadingNoticeDialog() async {
    final message = _readingNotice;
    if (message == null || message.trim().isEmpty || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }

  Future<bool> _loadTeacherRecommendations(int userId, List<Ayat> ayat) async {
    final ayahIds =
        ayat.where((item) => item.id != null).map((item) => item.id!).toList();
    if (ayahIds.isEmpty) {
      return true;
    }

    final cachedRecommendations =
        await _teacherRecommendationsService.getCachedStudentRecommendations(
      userId,
      ayahIds: ayahIds,
    );
    if (cachedRecommendations != null) {
      _applyTeacherRecommendations(ayat, cachedRecommendations);
      unawaited(
        _teacherRecommendationsService
            .refreshStudentRecommendationsInBackground(
          userId,
          ayahIds: ayahIds,
          onUpdated: (freshRecommendations) {
            if (!mounted) {
              return;
            }

            setState(() {
              _applyTeacherRecommendations(ayat, freshRecommendations);
            });
          },
        ),
      );
      return true;
    }

    try {
      final recommendations =
          await _teacherRecommendationsService.getStudentRecommendations(
        userId,
        ayahIds: ayahIds,
      );
      _applyTeacherRecommendations(ayat, recommendations);
      return true;
    } catch (_) {
      for (final item in ayat) {
        item.teacherRecommendations = [];
      }
      return false;
    }
  }

  void _applyTeacherRecommendations(
    List<Ayat> ayat,
    List<TeacherRecommendation> recommendations,
  ) {
    final recommendationsByAyah = <int, List<TeacherRecommendation>>{};
    for (final recommendation in recommendations) {
      recommendationsByAyah
          .putIfAbsent(recommendation.ayahId, () => <TeacherRecommendation>[])
          .add(recommendation);
    }

    for (final item in ayat) {
      item.teacherRecommendations =
          recommendationsByAyah[item.id] ?? <TeacherRecommendation>[];
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setWakelockEnabled(true);
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    for (final recognizer in _ayahTapRecognizers.values) {
      recognizer.dispose();
    }
    _ayahTapRecognizers.clear();
    _removeMenu();
    _setWakelockEnabled(false);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _activeSurah = widget.surah;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setWakelockEnabled(true);
      final usersProvider = context.read<UsersProvider>();
      final evaluationsProvider = context.read<EvaluationsProvider>();

      () async {
        await _ensureViewerUserLoaded();
        await _loadReadingDisplayPreferences(usersProvider);
        if (!mounted || usersProvider.selectedUser == null) {
          return;
        }

        await _loadAyat(usersProvider.selectedUser!.id, evaluationsProvider);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final evaluationProvider = Provider.of<EvaluationsProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final usersProvider = Provider.of<UsersProvider>(context);
    final ayahTapTooltip = _isAyahSelectionMode
      ? 'quran_reading_multi_select_mode_tooltip'.tr
      : 'quran_reading_assessment_tap_tooltip'.tr;

    if (evaluationProvider.isLoading && _ayat.isEmpty) {
      return const NoPopScope(
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_isConnectivityResolved && _ayat.isEmpty) {
      return const NoPopScope(
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Consumer<GeneralProvider>(
      builder: (context, generalProvider, _) {
        final isDarkMode = generalProvider.themeMode == ThemeMode.dark;
      final isLandscapeReader =
        MediaQuery.orientationOf(context) == Orientation.landscape;
      final readerBodyPadding = isLandscapeReader
        ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
        : const EdgeInsets.fromLTRB(4, 0, 4, 3);
      final readerSurfacePadding = isLandscapeReader
        ? const EdgeInsets.symmetric(vertical: 5, horizontal: 4)
        : const EdgeInsets.symmetric(vertical: 2, horizontal: 2);
      final readerSurfaceTopMargin = isLandscapeReader ? 4.0 : 0.0;

        return Theme(
          data: isDarkMode
              ? ThemeData(
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
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF121212),
                    foregroundColor: Colors.white,
                  ),
                )
              : ThemeData(
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
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                  ),
                ),
          child: NoPopScope(
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) => _ReaderToolIcon(
                              icon: Icons.menu_rounded,
                              tooltip: _tr('quran_reading_menu_tooltip'),
                              isDarkMode: isDarkMode,
                              onTap: () {
                                if ((Get.locale?.languageCode ?? 'ar') ==
                                    'ar') {
                                  Scaffold.of(context).openDrawer();
                                } else {
                                  Scaffold.of(context).openEndDrawer();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          _ReaderToolIcon(
                            icon: Icons.chevron_left_rounded,
                            tooltip: _tr('quran_reading_exit_tooltip'),
                            isDarkMode: isDarkMode,
                            onTap: _handleExitReading,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _ReaderSurahPill(
                              surahName: (_activeSurah ?? widget.surah)
                                  .displayName(
                                    localeCode: languageProvider.langCode,
                                  ),
                              isDarkMode: isDarkMode,
                              tooltip: _tr('quran_reading_surah_picker_tooltip'),
                              onTap: _openSurahPicker,
                            ),
                          ),
                          const SizedBox(width: 8),
                          QuranFilterTrigger.icon(
                            tooltip: _tr('quran_reading_filters_tooltip'),
                            isDarkMode: isDarkMode,
                            activeCount: _currentReaderFilterSelection()
                                .activeDimensionCount,
                            onTap: _openDisplayFilter,
                          ),
                          const Spacer(),
                          _ReaderToolCluster(
                            isDarkMode: isDarkMode,
                            children: [
                              _ReaderToolIcon(
                                icon: Icons.color_lens_rounded,
                                tooltip: _tr(
                                  'quran_reading_show_memorization_colors',
                                ),
                                isDarkMode: isDarkMode,
                                isActive: _showMemorizationColors,
                                flat: true,
                                onTap: () => _updateReadingDisplayPreferences(
                                  showMemorizationColors:
                                      !_showMemorizationColors,
                                ),
                              ),
                              _ReaderToolIcon(
                                icon: Icons.format_underlined_rounded,
                                tooltip: _tr(
                                  'quran_reading_show_comprehension_underline',
                                ),
                                isDarkMode: isDarkMode,
                                isActive: _showComprehensionUnderline,
                                flat: true,
                                onTap: () => _updateReadingDisplayPreferences(
                                  showComprehensionUnderline:
                                      !_showComprehensionUnderline,
                                ),
                              ),
                              _ReaderToolIcon(
                                icon: Icons.touch_app_rounded,
                                tooltip: ayahTapTooltip,
                                isDarkMode: isDarkMode,
                                isActive: _isAyahSelectionMode,
                                flat: true,
                                onTap: _canTapAyah(usersProvider)
                                    ? _toggleAyahSelectionMode
                                    : null,
                              ),
                              if (_readingNotice != null)
                                _ReaderToolIcon(
                                  icon: Icons.info_outline_rounded,
                                  tooltip: _readingNotice!,
                                  isDarkMode: isDarkMode,
                                  flat: true,
                                  onTap: _showReadingNoticeDialog,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              drawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? const GlobalDrawer()
                  : null,
              endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? null
                  : const GlobalDrawer(),
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: readerBodyPadding,
                  child: Column(
                    children: [
                      const PendingSyncBanner(bottomPadding: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(top: readerSurfaceTopMargin),
                          decoration: BoxDecoration(
                            color: _readingSurfaceColor(isDarkMode),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: readerSurfacePadding,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: PageView.builder(
                                      controller: _pageController,
                                      onPageChanged: (index) {
                                        if (index < 0 ||
                                            index >= _pageSequence.length) {
                                          return;
                                        }
                                        final page = _pageSequence[index];
                                        if (page == _currentPage) return;
                                        setState(() {
                                          _updateActivePageState(page);
                                        });
                                        final selectedUser = context
                                            .read<UsersProvider>()
                                            .selectedUser;
                                        if (selectedUser != null) {
                                          unawaited(
                                            _ensureVisiblePageDataLoaded(
                                              selectedUser.id,
                                              evaluationProvider,
                                              pages: _pagesAroundIndex(index),
                                            ),
                                          );
                                        }
                                        unawaited(_persistReadingSession());
                                      },
                                      itemCount: _pageSequence.length,
                                      itemBuilder: (context, index) {
                                        final page = _pageSequence[index];
                                        final pageAyat = _ayatForPage(page);
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            return _buildReaderPageViewport(
                                              context: context,
                                              constraints: constraints,
                                              page: page,
                                              pageAyat: pageAyat,
                                              languageProvider:
                                                  languageProvider,
                                              evaluationProvider:
                                                  evaluationProvider,
                                              isDarkMode: isDarkMode,
                                              isLandscapeReader:
                                                  isLandscapeReader,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                if (_isAyahSelectionMode && _hasSelectedAyahs)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 2,
                                    ),
                                    child: Center(
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            _openBulkAssessmentForSelectedAyahs(
                                          evaluationProvider,
                                          languageProvider,
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons
                                              .keyboard_double_arrow_up_rounded,
                                        ),
                                        label: Text(
                                          'quran_reading_bulk_apply_selected'
                                              .trParams({
                                            'count': _selectedAyahKeys.length
                                                .toString(),
                                          }),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_hasNavigationControls)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 4,
                                    ),
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _ReaderBottomChip(
                                            isDarkMode: isDarkMode,
                                            onTap: _openJuzPicker,
                                            tooltip: _tr(
                                              'quran_reading_juz_picker_tooltip',
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.auto_stories_rounded,
                                                  size: 22,
                                                  color: isDarkMode
                                                      ? const Color(
                                                          0xFFE6DFD0,
                                                        )
                                                      : AppColors.primaryPurple,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _currentNavigationJuz != null
                                                      ? _trParams(
                                                          'quran_reading_juz_indicator',
                                                          {
                                                            'juz':
                                                                _currentNavigationJuz
                                                                    .toString(),
                                                          },
                                                        )
                                                      : widget.surah.displayName(
                                                          localeCode:
                                                              languageProvider
                                                                  .langCode,
                                                        ),
                                                  style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : AppColors.primaryPurple,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 22,
                                                  color: isDarkMode
                                                      ? const Color(
                                                          0xFFE6DFD0,
                                                        )
                                                      : AppColors.primaryPurple,
                                                ),
                                              ],
                                            ),
                                          ),
                                          _ReaderBottomChip(
                                            isDarkMode: isDarkMode,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _ReaderInlineChevron(
                                                  icon: Icons
                                                      .chevron_left_rounded,
                                                  isDarkMode: isDarkMode,
                                                  onTap:
                                                      _canTapNavigationControls
                                                          ? () =>
                                                              _loadAdjacentChunk(
                                                                forward: false,
                                                              )
                                                          : null,
                                                ),
                                                const SizedBox(width: 4),
                                                _ReaderProgressLabel(
                                                  label:
                                                      _navigationProgressLabel,
                                                  isDarkMode: isDarkMode,
                                                  tooltip: _isPageNavigation
                                                      ? _tr(
                                                          'quran_reading_page_picker_tooltip',
                                                        )
                                                      : null,
                                                  onTap: _isPageNavigation
                                                      ? _openPagePicker
                                                      : null,
                                                ),
                                                const SizedBox(width: 4),
                                                _ReaderInlineChevron(
                                                  icon: Icons
                                                      .chevron_right_rounded,
                                                  isDarkMode: isDarkMode,
                                                  onTap:
                                                      _canTapNavigationControls
                                                          ? () =>
                                                              _loadAdjacentChunk(
                                                                forward: true,
                                                              )
                                                          : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _mushafAyahKey(int surahId, int ayahNo) => '$surahId:$ayahNo';

  _AyahPresentation _resolveAyahPresentation(
    Ayat ayah,
    LanguageProvider languageProvider,
    EvaluationsProvider evaluationProvider,
    bool isDarkMode,
  ) {
    final userEvaluation =
        ayah.userEvaluation ?? evaluationProvider.getUserEvaluationForAyah(ayah.id);
    final isSelected = _selectedAyahKeys.contains(_ayahSelectionKey(ayah));

    final defaultColor =
        isDarkMode ? Colors.white : AppColors.blackFontColor;
    final fadedColor =
        isDarkMode ? const Color(0xFF4A4A4A) : const Color(0xFFCFCFCF);
    final isFiltered = _hasAnyActiveReaderFilter &&
        !_ayahMatchesActiveReaderSelection(ayah, evaluationProvider);

    final memoEvaluation = userEvaluation?.memoEvaluation ??
        evaluationProvider.findEvaluationById(userEvaluation?.memoId);
    final compreEvaluation = userEvaluation?.compreEvaluation ??
        evaluationProvider.findEvaluationById(userEvaluation?.compreId);

    final hasMemorizationAccent =
        !isFiltered && _showMemorizationColors && memoEvaluation != null;
    final accentColor = hasMemorizationAccent
        ? _resolveReadableVerseColor(
            preferredColor:
                EvaluationsController().getColorForEvaluationModel(memoEvaluation),
            fallbackColor:
                isDarkMode ? const Color(0xFFE6DFD0) : AppColors.buttonColor,
            isDarkMode: isDarkMode,
          )
        : (isFiltered ? fadedColor : defaultColor);
    final verseColor = isFiltered
        ? fadedColor
        : (hasMemorizationAccent ? accentColor : defaultColor);
    final selectedBackgroundColor =
        isSelected ? accentColor.withValues(alpha: isDarkMode ? 0.22 : 0.12) : null;
    final selectedBadgeTextColor = isSelected
        ? (ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? Colors.white
            : Colors.black)
        : accentColor;

    final showUnderline = !isFiltered &&
        _showComprehensionUnderline &&
        EvaluationsController().isPositiveComprehension(compreEvaluation);

    return _AyahPresentation(
      isFiltered: isFiltered,
      badgeTextColor: selectedBadgeTextColor,
      tapRecognizer: _getAyahTapRecognizer(
        ayah,
        evaluationProvider,
        languageProvider,
      ),
      verseTextStyle: TextStyle(
        fontSize: 21,
        height: 1.8,
        color: verseColor,
        backgroundColor: selectedBackgroundColor,
        fontFamily: AppFonts.versesFont,
        decoration:
            showUnderline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: showUnderline ? accentColor : null,
        decorationThickness: showUnderline ? 1.8 : null,
      ),
    );
  }

  Widget _buildMushafLineSlot({
    required Widget child,
    double? height,
    Alignment alignment = Alignment.center,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height ?? _mushafLineHeight,
      child: Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: IntrinsicWidth(child: child),
        ),
      ),
    );
  }

  Color _mushafFrameColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF8B6914) : const Color(0xFFB7852A);
  }

  Color _mushafHeaderFillColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF2A2414) : const Color(0xFFF4E8C8);
  }

  Color _mushafHeaderTextColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFFE8C97E) : const Color(0xFF5C3A00);
  }

  Widget _buildMushafHeaderOrnament(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 1.2, color: color.withValues(alpha: 0.72)),
        const SizedBox(width: 4),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Container(width: 14, height: 1.2, color: color.withValues(alpha: 0.72)),
      ],
    );
  }

  Widget _buildMushafHeaderRail(Color color, {required bool alignStart}) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        if (!alignStart) _buildMushafHeaderOrnament(color),
        Expanded(
          child: Container(
            height: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: color.withValues(alpha: 0.42),
          ),
        ),
        if (alignStart) _buildMushafHeaderOrnament(color),
      ],
    );
  }

  String _toArabicIndicDigits(int value) {
    const digits = <String>['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((digit) => digits[int.parse(digit)])
        .join();
  }

  double _resolveMushafWordFontSize({
    required bool isLandscapeReader,
    required _MushafLineFineTune fineTune,
  }) {
    final baseSize =
        isLandscapeReader ? _mushafLandscapeWordFontSize : _mushafWordFontSize;
    return baseSize * fineTune.fontScale;
  }

  double _resolveMushafLineHeight({
    required bool isLandscapeReader,
    required _MushafLineFineTune fineTune,
  }) {
    final baseHeight =
        isLandscapeReader ? _mushafLandscapeLineHeight : _mushafLineHeight;
    return baseHeight * fineTune.lineHeightScale;
  }

  double _resolveLandscapeGapWidth(
    int gapFlex,
    _MushafLineFineTune fineTune,
  ) {
    final baseWidth = 5.5 + (gapFlex * 2.1);
    return math.max(5.0, baseWidth * fineTune.gapScale).toDouble();
  }

  _MushafLineFineTune _resolveMushafLineFineTune({
    required int pageNumber,
    required MushafRenderableLine line,
    required _MushafLinePattern pattern,
    required bool isLandscapeReader,
  }) {
    final manualOverride =
        _mushafLineFineTuneOverrides[pageNumber]?[line.lineNumber];
    if (manualOverride != null) {
      return manualOverride;
    }

    final tokenLengths = line.words
        .map(_mushafVisualTokenLength)
        .toList(growable: false);
    if (tokenLengths.isEmpty) {
      return const _MushafLineFineTune();
    }

    final tokenCount = tokenLengths.length;
    final totalChars = tokenLengths.fold<int>(0, (sum, value) => sum + value);
    final longestToken = tokenLengths.reduce(math.max);
    final shortestToken = tokenLengths.reduce(math.min);

    if (isLandscapeReader) {
      if (pattern.isCentered || tokenCount <= 4 || totalChars <= 12) {
        return const _MushafLineFineTune(
          forceCentered: true,
          gapScale: 0.68,
          fontScale: 1.24,
          lineHeightScale: 1.0,
          horizontalInset: 34,
        );
      }
      if (tokenCount <= 6 && totalChars <= 20) {
        return const _MushafLineFineTune(
          forceCentered: true,
          gapScale: 0.74,
          fontScale: 1.18,
          lineHeightScale: 1.0,
          horizontalInset: 24,
        );
      }
      if (tokenCount >= 7 || totalChars >= 28) {
        return const _MushafLineFineTune(
          forceCentered: true,
          gapScale: 0.78,
          fontScale: 1.1,
          lineHeightScale: 1.0,
          horizontalInset: 10,
        );
      }
      return const _MushafLineFineTune(
        forceCentered: true,
        gapScale: 0.76,
        fontScale: 1.14,
        lineHeightScale: 1.0,
        horizontalInset: 18,
      );
    }

    if (!pattern.isCentered && tokenCount >= 5 && tokenCount <= 6 && totalChars <= 16) {
      return const _MushafLineFineTune(
        forceCentered: true,
        gapScale: 0.92,
        fontScale: 1.02,
      );
    }

    if (!pattern.isCentered && tokenCount >= 10 && totalChars >= 40) {
      return const _MushafLineFineTune(
        gapScale: 0.9,
        fontScale: 0.96,
      );
    }

    if (!pattern.isCentered && tokenCount >= 8 && totalChars >= 34) {
      return const _MushafLineFineTune(
        gapScale: 0.94,
        fontScale: 0.98,
      );
    }

    if (!pattern.isCentered && tokenCount >= 7 && totalChars >= 34) {
      return const _MushafLineFineTune(
        fontScale: 0.98,
      );
    }

    if (!pattern.isCentered && longestToken - shortestToken >= 5 && tokenCount <= 5) {
      return const _MushafLineFineTune();
    }

    return const _MushafLineFineTune();
  }

  Widget _buildMushafAyahMarker({
    required int ayahNo,
    required TextStyle textStyle,
    required bool isDarkMode,
    required bool isLandscapeReader,
    VoidCallback? onTap,
    Color? accentColor,
  }) {
    final frameColor = _mushafFrameColor(isDarkMode);
    final markerTextColor = accentColor == null || accentColor == textStyle.color
        ? frameColor
        : accentColor;
    final markerNumberSize = math
        .max(
          11.0,
          (textStyle.fontSize ?? _mushafWordFontSize) -
              (isLandscapeReader ? 5 : 6),
        )
        .toDouble();
    final ornamentSize = markerNumberSize + (isLandscapeReader ? 12 : 10);

    Widget markerBody = SizedBox(
      width: isLandscapeReader ? 30 : 24,
      height: isLandscapeReader ? 30 : 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '۝',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: ornamentSize,
              height: 1,
              color: frameColor.withValues(alpha: isDarkMode ? 0.92 : 0.88),
              fontFamily: AppFonts.versesFont,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -0.5),
            child: Text(
              _toArabicIndicDigits(ayahNo),
              textDirection: TextDirection.rtl,
              style: textStyle.copyWith(
                fontSize: markerNumberSize,
                height: 1,
                fontWeight: FontWeight.w800,
                color: markerTextColor,
                decoration: TextDecoration.none,
                decorationColor: null,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      markerBody = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: markerBody,
      );
    }

    return markerBody;
  }

  Widget _buildMushafSurahHeaderLine(
    int surahId,
    bool isDarkMode,
    bool isLandscapeReader,
  ) {
    final frameColor = _mushafFrameColor(isDarkMode);
    final lineHeight = _resolveMushafLineHeight(
      isLandscapeReader: isLandscapeReader,
      fineTune: const _MushafLineFineTune(lineHeightScale: 1.0),
    ) + 1;

    return SizedBox(
      width: double.infinity,
      height: lineHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _mushafHeaderFillColor(isDarkMode),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: frameColor, width: 1.4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: frameColor.withValues(alpha: 0.45),
                  width: 0.9,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: _buildMushafHeaderRail(
                              frameColor,
                              alignStart: true,
                            ),
                          ),
                          SizedBox(width: isLandscapeReader ? 190 : 150),
                          Expanded(
                            child: _buildMushafHeaderRail(
                              frameColor,
                              alignStart: false,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        color: _mushafHeaderFillColor(isDarkMode),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Transform.translate(
                          offset: const Offset(0, -0.6),
                          child: Text(
                            'سورة ${localizedSurahNameById(surahId, localeCode: 'ar')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: isLandscapeReader ? 21 : 19,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: _mushafHeaderTextColor(isDarkMode),
                              fontFamily: AppFonts.primaryFont,
                              fontFamilyFallback: const <String>[
                                AppFonts.versesFont,
                              ],
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMushafBasmalaLine(bool isDarkMode, bool isLandscapeReader) {
    return _buildMushafLineSlot(
      height: _resolveMushafLineHeight(
        isLandscapeReader: isLandscapeReader,
        fineTune: const _MushafLineFineTune(),
      ),
      alignment: Alignment.center,
      child: Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: isLandscapeReader ? 22 : 20,
          height: 1,
          color: _mushafHeaderTextColor(isDarkMode),
          fontFamily: AppFonts.versesFont,
        ),
      ),
    );
  }

  int _mushafVisualTokenLength(MushafWordLayout word) {
    final normalized = word.text.replaceAll(_mushafVisualMarksPattern, '');
    return math.max(1, normalized.runes.length);
  }

  _MushafLinePattern _resolveMushafLinePattern(MushafRenderableLine line) {
    final tokenCount = line.words.length;
    if (tokenCount <= 1) {
      return const _MushafLinePattern.centered(tokenSpacing: 0);
    }

    final tokenLengths = line.words
        .map(_mushafVisualTokenLength)
        .toList(growable: false);
    final totalChars = tokenLengths.fold<int>(0, (sum, value) => sum + value);
    final averageChars = totalChars / tokenCount;
    final isSparseLine =
        totalChars <= 12 || (tokenCount <= 3 && averageChars >= 4.5);
    if (isSparseLine) {
      return _MushafLinePattern.centered(
        tokenSpacing: totalChars <= 8 ? 14 : 10,
      );
    }

    final isDenseLine = totalChars >= 28 || tokenCount >= 7;
    final isVeryDenseLine = totalChars >= 40 || tokenCount >= 10;
    final outerFlex = isDenseLine ? 0 : 1;
    final gapFlexes = <int>[];
    for (var index = 0; index < tokenLengths.length - 1; index += 1) {
      final leftLength = tokenLengths[index];
      final rightLength = tokenLengths[index + 1];
      final combinedLength = leftLength + rightLength;

      var gapFlex = combinedLength <= 5
          ? 3
          : combinedLength <= 8
              ? 2
              : 1;

      if (leftLength >= 6 || rightLength >= 6) {
        gapFlex -= 1;
      }
      if (isVeryDenseLine) {
        gapFlex -= 1;
      }
      if (line.words[index].isVerseEnd || line.words[index + 1].isVerseEnd) {
        gapFlex = math.max(gapFlex, 2);
      }
      gapFlexes.add(math.max(1, gapFlex));
    }

    return _MushafLinePattern.distributed(
      outerFlex: outerFlex,
      gapFlexes: gapFlexes,
    );
  }

  Widget _buildMushafLineToken({
    required Widget child,
    VoidCallback? onTap,
    double horizontalPadding = 1.5,
  }) {
    final padded = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: child,
    );

    if (onTap == null) {
      return padded;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: padded,
    );
  }

  Widget _buildSegmentedUnderlinedWord({
    required String text,
    required TextStyle textStyle,
    required Color underlineColor,
    required double underlineThickness,
  }) {
    final cleanTextStyle = textStyle.copyWith(
      decoration: TextDecoration.none,
      decorationColor: null,
      decorationThickness: null,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: underlineThickness <= 1.8 ? 0.4 : 0.7),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: underlineThickness + 1.4),
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              style: cleanTextStyle,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: underlineColor,
              ),
              child: SizedBox(height: underlineThickness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderlinedAyahConnector({
    required Color underlineColor,
    required double underlineThickness,
    required double fontSize,
    double? width,
  }) {
    final bottomInset = underlineThickness <= 1.8 ? 0.4 : 0.7;

    Widget connector = Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: underlineThickness + 1.4),
            child: SizedBox(
              width: width,
              height: fontSize,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: underlineColor,
              ),
              child: SizedBox(height: underlineThickness),
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      connector = SizedBox(width: width, child: connector);
    }

    return IgnorePointer(child: connector);
  }

  double _measureMushafTextWidth({
    required String text,
    required TextStyle textStyle,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _estimateMushafLineWidthForFit({
    required MushafRenderableLine line,
    required Map<String, Ayat> ayahByKey,
    required TextStyle textStyle,
    required _MushafLinePattern pattern,
    required _MushafLineFineTune fineTune,
    required bool isLandscapeReader,
    required bool isCenteredLine,
  }) {
    const tokenPaddingWidth = 3.0;
    final markerWidth = isLandscapeReader ? 30.0 : 24.0;
    final recommendationBadgeWidth = isLandscapeReader ? 28.0 : 24.0;
    var totalWidth = 0.0;

    for (var index = 0; index < line.words.length; index += 1) {
      final word = line.words[index];
      if (word.isVerseEnd) {
        totalWidth += markerWidth + tokenPaddingWidth;
        final ayah = ayahByKey[_mushafAyahKey(word.surahId, word.ayahNo)];
        if (ayah != null && ayah.teacherRecommendations.isNotEmpty) {
          totalWidth += 4 + recommendationBadgeWidth;
        }
      } else {
        totalWidth +=
            _measureMushafTextWidth(text: word.text, textStyle: textStyle) +
            tokenPaddingWidth;
      }

      if (!isCenteredLine || index >= line.words.length - 1) {
        continue;
      }

      if (pattern.isCentered) {
        totalWidth += math
            .max(
              6.0,
              (pattern.tokenSpacing == 0 ? 8.0 : pattern.tokenSpacing) *
                  fineTune.gapScale,
            )
            .toDouble();
        continue;
      }

      if (index < pattern.gapFlexes.length) {
        totalWidth += _resolveLandscapeGapWidth(
          pattern.gapFlexes[index],
          fineTune,
        );
      }
    }

    return totalWidth;
  }

  Widget _buildMushafWordLine(
    int pageNumber,
    MushafRenderableLine line,
    Map<String, Ayat> ayahByKey,
    LanguageProvider languageProvider,
    EvaluationsProvider evaluationProvider,
    bool isDarkMode,
    bool isLandscapeReader,
  ) {
    final pattern = _resolveMushafLinePattern(line);
    final fineTune = _resolveMushafLineFineTune(
      pageNumber: pageNumber,
      line: line,
      pattern: pattern,
      isLandscapeReader: isLandscapeReader,
    );
    final resolvedFontSize = _resolveMushafWordFontSize(
      isLandscapeReader: isLandscapeReader,
      fineTune: fineTune,
    );
    final resolvedLineHeight = _resolveMushafLineHeight(
      isLandscapeReader: isLandscapeReader,
      fineTune: fineTune,
    );
    final measureStyle = TextStyle(
      fontSize: resolvedFontSize,
      height: 1,
      color: isDarkMode ? Colors.white : AppColors.blackFontColor,
      fontFamily: AppFonts.versesFont,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCenteredLine =
            (fineTune.forceCentered || pattern.isCentered) && !isLandscapeReader;
        final horizontalInset =
            (isCenteredLine || isLandscapeReader) ? fineTune.horizontalInset : 0.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? math.max(0.0, constraints.maxWidth - (horizontalInset * 2))
            : double.infinity;

        var fitScale = 1.0;
        if (!isLandscapeReader && availableWidth.isFinite && availableWidth > 0) {
          final estimatedWidth = _estimateMushafLineWidthForFit(
            line: line,
            ayahByKey: ayahByKey,
            textStyle: measureStyle,
            pattern: pattern,
            fineTune: fineTune,
            isLandscapeReader: isLandscapeReader,
            isCenteredLine: isCenteredLine,
          );
          if (estimatedWidth > availableWidth) {
            fitScale = math.min(1.0, (availableWidth / estimatedWidth) * 0.985);
          }
        }

        final effectiveFontSize = resolvedFontSize * fitScale;
        final effectiveGapScale = fineTune.gapScale * fitScale;
        final effectiveGapFineTune = _MushafLineFineTune(
          forceCentered: fineTune.forceCentered,
          gapScale: effectiveGapScale,
          fontScale: fineTune.fontScale,
          lineHeightScale: fineTune.lineHeightScale,
          horizontalInset: fineTune.horizontalInset,
        );
        final defaultStyle = TextStyle(
          fontSize: effectiveFontSize,
          height: 1,
          color: isDarkMode ? Colors.white : AppColors.blackFontColor,
          fontFamily: AppFonts.versesFont,
        );
        final tokens = <_MushafLineTokenData>[];
        final tokenWidths = <double>[];
        for (var index = 0; index < line.words.length; index += 1) {
          final word = line.words[index];
          final ayahKey = _mushafAyahKey(word.surahId, word.ayahNo);
          final ayah = ayahByKey[ayahKey];
          final presentation = ayah == null
              ? null
              : _resolveAyahPresentation(
                  ayah,
                  languageProvider,
                  evaluationProvider,
                  isDarkMode,
                );
          final baseWordStyle =
              (presentation?.verseTextStyle ?? defaultStyle).copyWith(
            fontSize: effectiveFontSize,
            height: 1,
          );
          final showAyahUnderline =
              presentation?.verseTextStyle.decoration == TextDecoration.underline;
          final underlineColor = presentation?.verseTextStyle.decorationColor ??
              presentation?.badgeTextColor ??
              (baseWordStyle.color ?? defaultStyle.color!);
          final underlineThickness = isLandscapeReader ? 2.0 : 1.8;
          final plainWordStyle = baseWordStyle.copyWith(
            decoration: TextDecoration.none,
            decorationColor: null,
            decorationThickness: null,
          );
          final onTap = presentation?.tapRecognizer.onTap;

          if (showAyahUnderline && !word.isVerseEnd) {
            tokenWidths.add(
              _measureMushafTextWidth(
                text: word.text,
                textStyle: plainWordStyle,
              ),
            );
            tokens.add(
              _MushafLineTokenData(
                child: _buildMushafLineToken(
                  child: _buildSegmentedUnderlinedWord(
                    text: word.text,
                    textStyle: plainWordStyle,
                    underlineColor: underlineColor,
                    underlineThickness: underlineThickness,
                  ),
                  onTap: onTap,
                  horizontalPadding: 0,
                ),
                underlineAyahKey: ayahKey,
                underlineColor: underlineColor,
                underlineThickness: underlineThickness,
              ),
            );
            continue;
          }

          if (word.isVerseEnd) {
            var markerTokenWidth = isLandscapeReader ? 30.0 : 24.0;
            final marker = _buildMushafAyahMarker(
              ayahNo: word.ayahNo,
              textStyle: plainWordStyle,
              isDarkMode: isDarkMode,
              isLandscapeReader: isLandscapeReader,
              onTap: onTap,
              accentColor: presentation?.badgeTextColor,
            );

            Widget markerToken = marker;
            if (ayah != null &&
                presentation != null &&
                !presentation.isFiltered &&
                ayah.teacherRecommendations.isNotEmpty) {
              markerTokenWidth += (isLandscapeReader ? 30.0 : 24.0) + 4;
              markerToken = Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  marker,
                  const SizedBox(width: 4),
                  TeacherRecommendationBadge(
                    recommendations: ayah.teacherRecommendations,
                    compact: true,
                  ),
                ],
              );
            }

            tokenWidths.add(markerTokenWidth + 3);

            tokens.add(
              _MushafLineTokenData(
                child: _buildMushafLineToken(
                  child: markerToken,
                ),
              ),
            );
            continue;
          }

          tokenWidths.add(
            _measureMushafTextWidth(
                  text: word.text,
                  textStyle: plainWordStyle,
                ) +
                3,
          );
          tokens.add(
            _MushafLineTokenData(
              child: _buildMushafLineToken(
                child: Text(
                  word.text,
                  textDirection: TextDirection.rtl,
                  style: plainWordStyle,
                ),
                onTap: onTap,
              ),
            ),
          );
        }

        bool shouldBridgeUnderline(
          _MushafLineTokenData left,
          _MushafLineTokenData right,
        ) {
          return left.underlineAyahKey != null &&
              left.underlineAyahKey == right.underlineAyahKey &&
              left.underlineColor != null &&
              left.underlineThickness != null;
        }

        final intrinsicTokenWidth = tokenWidths.fold<double>(
          0,
          (sum, value) => sum + value,
        );
        final visualLineScale = !isLandscapeReader &&
                availableWidth.isFinite &&
                availableWidth > 0 &&
                intrinsicTokenWidth > availableWidth
            ? math.min(1.0, (availableWidth / intrinsicTokenWidth) * 0.985)
            : 1.0;

        if (isCenteredLine) {
          final gapWidths = pattern.isCentered
              ? List<double>.filled(
                  math.max(0, tokens.length - 1),
                  math
                      .max(
                        6.0,
                        (pattern.tokenSpacing == 0 ? 8.0 : pattern.tokenSpacing) *
                            effectiveGapScale,
                      )
                      .toDouble(),
                  growable: false,
                )
              : List<double>.generate(
                  math.max(0, tokens.length - 1),
                  (index) => _resolveLandscapeGapWidth(
                    pattern.gapFlexes[index],
                    effectiveGapFineTune,
                  ),
                  growable: false,
                );

          final centeredChildren = <Widget>[];
          for (var index = 0; index < tokens.length; index += 1) {
            centeredChildren.add(tokens[index].child);
            if (index < gapWidths.length) {
              final leftToken = tokens[index];
              final rightToken = tokens[index + 1];
              if (shouldBridgeUnderline(leftToken, rightToken)) {
                centeredChildren.add(
                  _buildUnderlinedAyahConnector(
                    width: gapWidths[index],
                    underlineColor: leftToken.underlineColor!,
                    underlineThickness: leftToken.underlineThickness!,
                    fontSize: effectiveFontSize,
                  ),
                );
              } else {
                centeredChildren.add(SizedBox(width: gapWidths[index]));
              }
            }
          }

          Widget lineChild = Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: centeredChildren,
          );
          if (visualLineScale < 1.0 || availableWidth.isFinite) {
            lineChild = FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: lineChild,
            );
          }

          return SizedBox(
            width: double.infinity,
            height: resolvedLineHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: fineTune.horizontalInset),
              child: Center(child: lineChild),
            ),
          );
        }

        final distributedChildren = <Widget>[];
        final outerFlex = isLandscapeReader
            ? 0
            : (pattern.outerFlex <= 0
                ? 0
                : math.max(
                    1,
                    (pattern.outerFlex * effectiveGapScale).round(),
                  ));
        final gapFlexes = List<int>.generate(
          pattern.gapFlexes.length,
          (index) => math.max(
            1,
            (pattern.gapFlexes[index] * effectiveGapScale).round(),
          ),
          growable: false,
        );
        final totalGapUnits = (outerFlex * 2) +
            gapFlexes.fold<int>(0, (sum, value) => sum + value);
        final horizontalPadding = isLandscapeReader ? fineTune.horizontalInset * 2 : 0.0;
        final distributedAvailableWidth = constraints.maxWidth.isFinite
            ? math.max(0.0, constraints.maxWidth - horizontalPadding)
            : double.infinity;
        final remainingGapWidth = distributedAvailableWidth.isFinite
            ? math.max(0.0, distributedAvailableWidth - intrinsicTokenWidth)
            : 0.0;
        final gapUnitWidth = totalGapUnits > 0
            ? remainingGapWidth / totalGapUnits
            : 0.0;
        final outerGapWidth = gapUnitWidth * outerFlex;

        if (outerGapWidth > 0) {
          distributedChildren.add(SizedBox(width: outerGapWidth));
        }
        for (var index = 0; index < tokens.length; index += 1) {
          distributedChildren.add(tokens[index].child);
          if (index < gapFlexes.length) {
            final gapWidth = gapUnitWidth * gapFlexes[index];
            final leftToken = tokens[index];
            final rightToken = tokens[index + 1];
            if (shouldBridgeUnderline(leftToken, rightToken)) {
              distributedChildren.add(
                _buildUnderlinedAyahConnector(
                  width: gapWidth,
                  underlineColor: leftToken.underlineColor!,
                  underlineThickness: leftToken.underlineThickness!,
                  fontSize: effectiveFontSize,
                ),
              );
            } else {
              distributedChildren.add(SizedBox(width: gapWidth));
            }
          }
        }
        if (outerGapWidth > 0) {
          distributedChildren.add(SizedBox(width: outerGapWidth));
        }

        Widget lineChild = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: distributedChildren,
        );
        if (visualLineScale < 1.0 || distributedAvailableWidth.isFinite) {
          lineChild = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: lineChild,
          );
        }

        return SizedBox(
          width: double.infinity,
          height: resolvedLineHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscapeReader ? fineTune.horizontalInset : 0,
            ),
            child: Center(child: lineChild),
          ),
        );
      },
    );
  }

  Widget _buildReaderPageViewport({
    required BuildContext context,
    required BoxConstraints constraints,
    required int page,
    required List<Ayat> pageAyat,
    required LanguageProvider languageProvider,
    required EvaluationsProvider evaluationProvider,
    required bool isDarkMode,
    required bool isLandscapeReader,
  }) {
    final isIntroPage = page == 1 || page == 2;
    final pageWidget = _ReaderRenderedPage(
      pageNumber: page,
      isDarkMode: isDarkMode,
      margin: EdgeInsets.symmetric(vertical: isLandscapeReader ? 4 : 0),
      contentPadding: isLandscapeReader
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildAyatWidgets(
          page,
          pageAyat,
          languageProvider,
          evaluationProvider,
          _hasConnection,
          isDarkMode,
          isLandscapeReader,
        ),
      ),
    );

    if (isLandscapeReader) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: SizedBox(
          width: constraints.maxWidth,
          height: isIntroPage ? constraints.maxHeight : null,
          child: pageWidget,
        ),
      );
    }

    if (isIntroPage) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: pageWidget,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth,
              height: isIntroPage ? constraints.maxHeight : null,
              child: pageWidget,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMushafLayoutWidgets(
    MushafPageLayout layout,
    List<Ayat> ayat,
    LanguageProvider languageProvider,
    EvaluationsProvider evaluationProvider,
    bool isDarkMode,
    bool isLandscapeReader,
  ) {
    if (layout.lines.isEmpty) {
      return const <Widget>[];
    }

    final ayahByKey = <String, Ayat>{
      for (final ayah in ayat) _mushafAyahKey(ayah.surah.id, ayah.ayahNo): ayah,
    };
    final widgets = <Widget>[];

    for (final line in layout.buildRenderableLines()) {
      switch (line.kind) {
        case MushafPageLineKind.words:
          widgets.add(
            _buildMushafWordLine(
              layout.pageNumber,
              line,
              ayahByKey,
              languageProvider,
              evaluationProvider,
              isDarkMode,
              isLandscapeReader,
            ),
          );
          break;

        case MushafPageLineKind.surahHeader:
          final surahId = line.surahId;
          if (surahId != null) {
            widgets.add(
              _buildMushafSurahHeaderLine(
                surahId,
                isDarkMode,
                isLandscapeReader,
              ),
            );
          }
          break;

        case MushafPageLineKind.basmala:
          widgets.add(
            _buildMushafBasmalaLine(isDarkMode, isLandscapeReader),
          );
          break;

        case MushafPageLineKind.blank:
          widgets.add(
            SizedBox(
              width: double.infinity,
              height: _resolveMushafLineHeight(
                isLandscapeReader: isLandscapeReader,
                fineTune: const _MushafLineFineTune(),
              ),
            ),
          );
          break;
      }
    }

    widgets.add(const SizedBox(height: 4));
    return widgets;
  }

  List<Widget> _buildAyatWidgets(
    int pageNumber,
    List<Ayat> ayat,
    LanguageProvider languageProvider,
    EvaluationsProvider evaluationProvider,
    bool hasConnection,
    bool isDarkMode,
    bool isLandscapeReader,
  ) {
    final layout = _mushafLayoutsByPage[pageNumber];
    if (layout != null) {
      final lineAwareWidgets = _buildMushafLayoutWidgets(
        layout,
        ayat,
        languageProvider,
        evaluationProvider,
        isDarkMode,
        isLandscapeReader,
      );
      if (lineAwareWidgets.isNotEmpty) {
        return lineAwareWidgets;
      }
    }

    return _buildAyatWidgetsFallback(
      ayat,
      languageProvider,
      evaluationProvider,
      hasConnection,
      isDarkMode,
    );
  }

  List<Widget> _buildAyatWidgetsFallback(
    List<Ayat> ayat,
    LanguageProvider languageProvider,
    EvaluationsProvider evaluationProvider,
    bool hasConnection,
    bool isDarkMode,
  ) {
    final widgets = <Widget>[];
    if (ayat.isEmpty) {
      return widgets;
    }

    final groups = <List<Ayat>>[];
    var currentGroup = <Ayat>[];
    int? currentSurahId;

    for (final ayah in ayat) {
      if (currentSurahId != null && ayah.surah.id != currentSurahId) {
        groups.add(currentGroup);
        currentGroup = <Ayat>[];
      }
      currentGroup.add(ayah);
      currentSurahId = ayah.surah.id;
    }
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    for (final group in groups) {
      final firstAyah = group.first;
      final isAtStartOfSurah = firstAyah.ayahNo == 1;

      if (isAtStartOfSurah) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF2A2210)
                    : const Color(0xFFF5EDD5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF8B6914)
                      : const Color(0xFFB7852A),
                ),
              ),
              child: Text(
                firstAyah.surah.displayName(
                  localeCode: languageProvider.langCode,
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode
                      ? const Color(0xFFE8C97E)
                      : const Color(0xFF5C3A00),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        );

        if (firstAyah.ayahNo == 1 &&
            firstAyah.surah.id != 1 &&
            firstAyah.surah.id != 9) {
          widgets.add(
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.8,
                    color: isDarkMode
                        ? const Color(0xFFE8C97E)
                        : const Color(0xFF5C3A00),
                    fontFamily: AppFonts.versesFont,
                  ),
                ),
              ),
            ),
          );
        }
      }

      widgets.add(
        Text.rich(
          TextSpan(
            children: group.map((ayah) {
              final presentation = _resolveAyahPresentation(
                ayah,
                languageProvider,
                evaluationProvider,
                isDarkMode,
              );

              return TextSpan(
                children: [
                  TextSpan(
                    text: '${ayah.text} ',
                    recognizer: presentation.tapRecognizer,
                    style: presentation.verseTextStyle,
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 2,
                        end: 2,
                      ),
                      child: _buildMushafAyahMarker(
                        ayahNo: ayah.ayahNo,
                        textStyle: presentation.verseTextStyle,
                        isDarkMode: isDarkMode,
                        isLandscapeReader: false,
                        onTap: presentation.tapRecognizer.onTap,
                        accentColor: presentation.badgeTextColor,
                      ),
                    ),
                  ),
                  if (!presentation.isFiltered &&
                      ayah.teacherRecommendations.isNotEmpty)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 6,
                          end: 6,
                        ),
                        child: TeacherRecommendationBadge(
                          recommendations: ayah.teacherRecommendations,
                          compact: true,
                        ),
                      ),
                    ),
                  const TextSpan(text: ' '),
                ],
              );
            }).toList(growable: false),
          ),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          textWidthBasis: TextWidthBasis.parent,
        ),
      );

      widgets.add(const SizedBox(height: 4));
    }

    return widgets;
  }
}

class _AyahPresentation {
  const _AyahPresentation({
    required this.isFiltered,
    required this.badgeTextColor,
    required this.tapRecognizer,
    required this.verseTextStyle,
  });

  final bool isFiltered;
  final Color badgeTextColor;
  final TapGestureRecognizer tapRecognizer;
  final TextStyle verseTextStyle;
}

class _ReaderToolIcon extends StatelessWidget {
  const _ReaderToolIcon({
    required this.icon,
    required this.tooltip,
    required this.isDarkMode,
    required this.onTap,
    this.isActive = false,
    this.flat = false,
  });

  final IconData icon;
  final String tooltip;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final bool isActive;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = isDarkMode
        ? (disabled ? const Color(0xFF6B7280) : Colors.white)
      : (disabled ? AppColors.mutedText : AppColors.primaryPurple);
    final background = flat
        ? Colors.transparent
        : (isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0));

    final activeOverlay = isActive
        ? (isDarkMode
            ? Colors.white.withValues(alpha: 0.10)
        : AppColors.primaryPurple.withValues(alpha: 0.10))
        : null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: activeOverlay ?? background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _ReaderToolCluster extends StatelessWidget {
  const _ReaderToolCluster({
    required this.isDarkMode,
    required this.children,
  });

  final bool isDarkMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _ReaderSurahPill extends StatelessWidget {
  const _ReaderSurahPill({
    required this.surahName,
    required this.isDarkMode,
    required this.onTap,
    this.tooltip,
  });

  final String surahName;
  final bool isDarkMode;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = isDarkMode ? Colors.white : AppColors.primaryPurple;
    final pill = Material(
      color: isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            surahName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: foreground,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: AppFonts.primaryFont,
              fontFamilyFallback: const <String>[AppFonts.versesFont],
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return pill;
    }
    return Tooltip(message: tooltip!, child: pill);
  }
}

class _ReaderProgressLabel extends StatelessWidget {
  const _ReaderProgressLabel({
    required this.label,
    required this.isDarkMode,
    this.onTap,
    this.tooltip,
  });

  final String label;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        color: isDarkMode ? Colors.white : AppColors.primaryPurple,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: onTap != null ? TextDecoration.underline : null,
        decorationStyle:
            onTap != null ? TextDecorationStyle.dotted : null,
      ),
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: text,
      );
    }

    final tappable = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: text,
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return tappable;
    }
    return Tooltip(message: tooltip!, child: tappable);
  }
}

class _ReaderBottomChip extends StatelessWidget {
  const _ReaderBottomChip({
    required this.isDarkMode,
    required this.child,
    this.onTap,
    this.tooltip,
  });

  final bool isDarkMode;
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final background =
        isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0);
    Widget body;
    if (onTap != null) {
      body = Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: child,
          ),
        ),
      );
    } else {
      body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
    }

    if (tooltip == null || tooltip!.isEmpty) {
      return body;
    }
    return Tooltip(message: tooltip!, child: body);
  }
}

class _ReaderRenderedPage extends StatelessWidget {
  const _ReaderRenderedPage({
    required this.pageNumber,
    required this.isDarkMode,
    required this.child,
    this.margin = const EdgeInsets.symmetric(vertical: 4),
    this.contentPadding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  final int pageNumber;
  final bool isDarkMode;
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry contentPadding;

  bool get _isIntroPage => pageNumber == 1 || pageNumber == 2;

  double _resolveIntroPageAspectRatio(bool isLandscapeReader) {
    if (isLandscapeReader) {
      return pageNumber == 1 ? 1.02 : 1.06;
    }
    return pageNumber == 1 ? 0.74 : 0.78;
  }

  Widget _buildRecitationDivider(Color color) {
    final primaryColor = Color.lerp(color, Colors.black, 0.32) ?? color;
    final secondaryColor = Color.lerp(color, Colors.black, 0.12) ?? color;
    return IgnorePointer(
      child: SizedBox(
        width: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2.2,
              decoration: BoxDecoration(
                color: secondaryColor,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: secondaryColor.withValues(alpha: 0.22),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 4.2,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.26),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroOrnamentBand({
    required Color borderColor,
    required Color fillColor,
    required bool isLandscapeReader,
  }) {
    return Container(
      height: isLandscapeReader ? 24 : 28,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1.2,
                color: borderColor.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent({
    required Color borderColor,
    required Color bgColor,
    required bool isLandscapeReader,
  }) {
    final baseContent = Padding(
      padding: contentPadding,
      child: child,
    );

    if (!_isIntroPage) {
      return baseContent;
    }

    final fillColor = isDarkMode ? const Color(0xFF201C12) : const Color(0xFFF7F3E4);
    final widthFactor = pageNumber == 1
      ? (isLandscapeReader ? 0.70 : 0.76)
        : (isLandscapeReader ? 0.76 : 0.82);
    final mainFrame = SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.25),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.42),
                width: 0.9,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                pageNumber == 1 ? 12 : 16,
                pageNumber == 1 ? 10 : 12,
                pageNumber == 1 ? 12 : 16,
                pageNumber == 1 ? 10 : 12,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: pageNumber == 1
              ? const Alignment(0, -0.24)
              : const Alignment(0, -0.04),
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIntroOrnamentBand(
                  borderColor: borderColor,
                  fillColor: fillColor,
                  isLandscapeReader: isLandscapeReader,
                ),
                const SizedBox(height: 8),
                mainFrame,
                const SizedBox(height: 8),
                _buildIntroOrnamentBand(
                  borderColor: borderColor,
                  fillColor: fillColor,
                  isLandscapeReader: isLandscapeReader,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscapeReader =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final borderColor =
        isDarkMode ? const Color(0xFF8B6914) : const Color(0xFFB7852A);
    final bgColor =
        isDarkMode ? const Color(0xFF1C1A15) : const Color(0xFFFDFAF3);

    final pagePanel = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.30 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildPageContent(
        borderColor: borderColor,
        bgColor: bgColor,
        isLandscapeReader: isLandscapeReader,
      ),
    );

    final dividerOnLeft = pageNumber.isOdd;
    Widget composedPage;

    if (_isIntroPage) {
      composedPage = AspectRatio(
        aspectRatio: _resolveIntroPageAspectRatio(isLandscapeReader),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  left: dividerOnLeft ? 18 : 6,
                  right: dividerOnLeft ? 6 : 18,
                ),
                child: pagePanel,
              ),
            ),
            Positioned(
              top: 2,
              bottom: 2,
              left: dividerOnLeft ? 11 : null,
              right: dividerOnLeft ? null : 11,
              child: _buildRecitationDivider(borderColor),
            ),
          ],
        ),
      );
    } else {
      composedPage = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: dividerOnLeft ? 18 : 6,
              right: dividerOnLeft ? 6 : 18,
            ),
            child: pagePanel,
          ),
          Positioned(
            top: 2,
            bottom: 2,
            left: dividerOnLeft ? 11 : null,
            right: dividerOnLeft ? null : 11,
            child: _buildRecitationDivider(borderColor),
          ),
        ],
      );
    }

    return Container(
      margin: margin,
      child: composedPage,
    );
  }
}

class _MushafLinePattern {
  const _MushafLinePattern._({
    required this.isCentered,
    required this.outerFlex,
    required this.gapFlexes,
    required this.tokenSpacing,
  });

  const _MushafLinePattern.centered({required double tokenSpacing})
      : this._(
          isCentered: true,
          outerFlex: 0,
          gapFlexes: const <int>[],
          tokenSpacing: tokenSpacing,
        );

  const _MushafLinePattern.distributed({
    required int outerFlex,
    required List<int> gapFlexes,
  }) : this._(
          isCentered: false,
          outerFlex: outerFlex,
          gapFlexes: gapFlexes,
          tokenSpacing: 0,
        );

  final bool isCentered;
  final int outerFlex;
  final List<int> gapFlexes;
  final double tokenSpacing;
}

class _MushafLineFineTune {
  const _MushafLineFineTune({
    this.forceCentered = false,
    this.gapScale = 1,
    this.fontScale = 1,
    this.lineHeightScale = 1,
    this.horizontalInset = 0,
  });

  final bool forceCentered;
  final double gapScale;
  final double fontScale;
  final double lineHeightScale;
  final double horizontalInset;
}

class _MushafLineTokenData {
  const _MushafLineTokenData({
    required this.child,
    this.underlineAyahKey,
    this.underlineColor,
    this.underlineThickness,
  });

  final Widget child;
  final String? underlineAyahKey;
  final Color? underlineColor;
  final double? underlineThickness;
}


class _ReaderInlineChevron extends StatelessWidget {
  const _ReaderInlineChevron({
    required this.icon,
    required this.isDarkMode,
    required this.onTap,
  });

  final IconData icon;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = isDarkMode
        ? (disabled ? const Color(0xFF5B6271) : Colors.white)
      : (disabled ? AppColors.mutedText : AppColors.primaryPurple);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 30, color: foreground),
      ),
    );
  }
}

class _ReaderJuzPicker extends StatefulWidget {
  const _ReaderJuzPicker({this.currentJuz});

  final int? currentJuz;

  @override
  State<_ReaderJuzPicker> createState() => _ReaderJuzPickerState();
}

class _ReaderJuzPickerState extends State<_ReaderJuzPicker> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initial = (widget.currentJuz ?? 1) - 1;
    _controller = ScrollController(
      initialScrollOffset: (initial * 60.0).clamp(0, double.infinity),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tr(String key) => key.tr;

  String _trParams(String key, Map<String, String> params) =>
      key.trParams(params);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              width: 44,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              _tr('quran_reading_juz_picker_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: ListView.separated(
                controller: _controller,
                itemCount: 30,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final juz = index + 1;
                  final isCurrent = juz == widget.currentJuz;
                  return ListTile(
                    selected: isCurrent,
                    title: Text(
                      _trParams('quran_reading_juz_picker_item', {
                        'juz': juz.toString(),
                      }),
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(juz),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderSurahPicker extends StatefulWidget {
  const _ReaderSurahPicker({required this.currentSurahId});

  final int currentSurahId;

  @override
  State<_ReaderSurahPicker> createState() => _ReaderSurahPickerState();
}

class _ReaderSurahPickerState extends State<_ReaderSurahPicker> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initial = (widget.currentSurahId - 1).clamp(0, 113);
    _controller = ScrollController(
      initialScrollOffset:
          (initial * 56.0 - 200).clamp(0, double.infinity).toDouble(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tr(String key) => key.tr;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              width: 44,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              _tr('quran_reading_surah_picker_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: ListView.separated(
                controller: _controller,
                itemCount: quran.totalSurahCount,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final surahNumber = index + 1;
                  final isCurrent = surahNumber == widget.currentSurahId;
                  return ListTile(
                    selected: isCurrent,
                    leading: Text(
                      surahNumber.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    title: Text(
                      localizedSurahNameById(
                        surahNumber,
                        localeCode: Get.locale?.languageCode,
                      ),
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w600,
                        fontFamily: AppFonts.versesFont,
                        fontSize: 18,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(surahNumber),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPagePicker extends StatefulWidget {
  const _ReaderPagePicker({
    required this.currentPage,
    required this.availablePages,
  });

  final int currentPage;
  final List<int> availablePages;

  @override
  State<_ReaderPagePicker> createState() => _ReaderPagePickerState();
}

class _ReaderPagePickerState extends State<_ReaderPagePicker> {
  late final TextEditingController _input;
  late final ScrollController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.currentPage.toString());
    final availableIndex = widget.availablePages.indexOf(widget.currentPage);
    final initialIndex = (availableIndex == -1 ? 0 : availableIndex)
        .clamp(0, math.max(0, widget.availablePages.length - 1));
    _controller = ScrollController(
      initialScrollOffset:
          (initialIndex * 48.0 - 160).clamp(0, double.infinity).toDouble(),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _tr(String key) => key.tr;

  String _trParams(String key, Map<String, String> params) =>
      key.trParams(params);

  void _submit() {
    final raw = _input.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null ||
        parsed < 1 ||
        parsed > 604 ||
        !widget.availablePages.contains(parsed)) {
      setState(() {
        _errorText = _tr('quran_reading_page_picker_invalid');
      });
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              width: 44,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              _tr('quran_reading_page_picker_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: _tr('quran_reading_page_picker_input_label'),
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(_tr('quran_reading_page_picker_jump')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: ListView.builder(
                controller: _controller,
                itemCount: widget.availablePages.length,
                itemExtent: 48,
                itemBuilder: (context, index) {
                  final page = widget.availablePages[index];
                  final isCurrent = page == widget.currentPage;
                  return ListTile(
                    dense: true,
                    selected: isCurrent,
                    title: Text(
                      _trParams(
                        'quran_reading_page_picker_item',
                        {'page': page.toString()},
                      ),
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(page),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
