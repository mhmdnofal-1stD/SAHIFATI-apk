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
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/school.dart';
import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/services/school_services.dart';
import 'package:sahifaty/services/teacher_recommendations_service.dart';
import 'package:sahifaty/services/subjects_lookup_service.dart';
import 'package:sahifaty/services/users_services.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import '../../controllers/general_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../core/reading/reading_session.dart';
import '../../models/surah.dart';
import '../../providers/general_provider.dart';
import '../widgets/global_drawer.dart';
import '../widgets/assessment_input_dialog.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/pending_sync_banner.dart';
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
  bool _hasLoadedAllEvaluationCoverage = false;
  String? _readingNotice;
  final Map<int, TapGestureRecognizer> _ayahTapRecognizers =
      <int, TapGestureRecognizer>{};
  final TeacherRecommendationsService _teacherRecommendationsService =
      TeacherRecommendationsService();
  final UsersServices _usersService = UsersServices();
  User? _viewerUser;
  Surah? _activeSurah;

  // Reading display filter (fades non-matching ayahs in the rendered text).
  final Set<String> _filterAyahTypes = <String>{};
  final Set<String> _filterSubjectKeys = <String>{};
  final Set<String> _filterSchoolLevelIds = <String>{};
  final Set<int> _filterMemoEvaluationIds = <int>{};
  final Set<int> _filterCompreEvaluationIds = <int>{};

  // Hierarchical reader scope (Thirds -> Juz -> Surahs). When narrower
  // children are picked they replace their parent (per product spec):
  //   surahIds win over juzs, juzs win over thirds.
  // Empty == no scope == full mushaf.
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

  bool _ayahMatchesScopeFilter(Ayat ayah) {
    if (_filterSurahIds.isNotEmpty) {
      return _filterSurahIds.contains(ayah.surah.id);
    }

    if (_filterJuzs.isNotEmpty) {
      final juz = ayah.juz;
      return _filterJuzs.contains(juz);
    }

    if (_filterThirds.isNotEmpty) {
      final juz = ayah.juz;
      return _filterThirds.contains(_ReaderScopeData.thirdOfJuz(juz));
    }

    return true;
  }

  bool _ayahMatchesActiveReaderSelection(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
  ) {
    if (!_ayahMatchesScopeFilter(ayah)) {
      return false;
    }

    if (!_hasActiveDisplayFilter) {
      return true;
    }

    return _ayahMatchesDisplayFilter(ayah, evaluationsProvider);
  }

  bool _ayahMatchesDisplayFilter(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
  ) {
    if (!_hasActiveDisplayFilter) {
      return true;
    }

    if (_filterAyahTypes.isNotEmpty) {
      final type = ayah.ayahType?.trim().toLowerCase();
      if (type == null || !_filterAyahTypes.contains(type)) {
        return false;
      }
    }

    if (_filterSubjectKeys.isNotEmpty) {
      final subjects = ayah.subjects ?? const <String>[];
      final hasMatch =
          subjects.any((subject) => _filterSubjectKeys.contains(subject));
      if (!hasMatch) {
        return false;
      }
    }

    if (_filterSchoolLevelIds.isNotEmpty) {
      final levels = ayah.schoolLevels ?? const <SchoolLevel>[];
      final hasMatch = levels.any((level) {
        final schoolId = level.schoolId;
        final levelNumber = level.level;
        if (schoolId == null || levelNumber == null) {
          return false;
        }
        return _filterSchoolLevelIds.contains(
          _schoolLevelFilterKey(schoolId, levelNumber),
        );
      });
      if (!hasMatch) {
        return false;
      }
    }

    if (_filterMemoEvaluationIds.isNotEmpty ||
        _filterCompreEvaluationIds.isNotEmpty) {
      final userEvaluation = ayah.userEvaluation ??
          evaluationsProvider.getUserEvaluationForAyah(ayah.id);

      if (_filterMemoEvaluationIds.isNotEmpty) {
        final memoId = userEvaluation?.memoId;
        if (memoId == null || !_filterMemoEvaluationIds.contains(memoId)) {
          return false;
        }
      }

      if (_filterCompreEvaluationIds.isNotEmpty) {
        final compreId = userEvaluation?.compreId;
        if (compreId == null ||
            !_filterCompreEvaluationIds.contains(compreId)) {
          return false;
        }
      }
    }

    return true;
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

  String _schoolLevelFilterKey(int schoolId, int level) => '$schoolId:$level';

  String _resolveLocalizedMapValue(Map<String, dynamic> raw) {
    final locale = Get.locale?.languageCode ?? 'ar';
    final localized = raw[locale] ?? raw['ar'] ?? raw['en'];
    if (localized is String && localized.trim().isNotEmpty) {
      return localized.trim();
    }
    for (final value in raw.values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _resolveSchoolName(SchoolLevel level, Map<int, School> schoolsById) {
    final schoolId = level.schoolId;
    if (schoolId != null) {
      final school = schoolsById[schoolId];
      if (school != null) {
        final localized = _resolveLocalizedMapValue(school.schoolName);
        if (localized.isNotEmpty) {
          return localized;
        }
      }
    }

    final embedded = level.schoolName?.trim();
    if (embedded != null && embedded.isNotEmpty) {
      return embedded;
    }

    return schoolId?.toString() ?? '';
  }

  String _resolveSchoolFilterLevelName(
    SchoolLevel level,
    Map<int, School> schoolsById,
  ) {
    final schoolId = level.schoolId;
    final levelNumber = level.level;

    if (schoolId != null && levelNumber != null) {
      final school = schoolsById[schoolId];
      if (school != null &&
          levelNumber >= 1 &&
          levelNumber <= school.levels.length) {
        final localized = _resolveSchoolLevelName(
          school.levels[levelNumber - 1],
        );
        if (localized.isNotEmpty) {
          return localized;
        }
      }
    }

    final direct = _resolveSchoolLevelName(level);
    if (direct.isNotEmpty && direct != (level.id ?? '')) {
      return direct;
    }

    if (levelNumber != null) {
      final fallbackKey = 'level_$levelNumber';
      final translated = fallbackKey.tr;
      return translated == fallbackKey ? levelNumber.toString() : translated;
    }

    return level.id ?? '';
  }

  Future<Map<String, String>> _resolveSubjectDisplayLabels(
    Set<String> subjectKeys,
  ) async {
    final labels = <String, String>{
      for (final key in subjectKeys) key: key,
    };
    if (subjectKeys.isEmpty) {
      return labels;
    }

    try {
      final hierarchy = await SubjectsLookupService.instance.loadHierarchy();
      final locale = Get.locale?.languageCode ?? 'ar';
      final byKey = <String, SubjectHierarchyItem>{
        for (final item in hierarchy) item.key: item,
      };
      for (final key in subjectKeys) {
        final subject = byKey[key];
        if (subject == null) {
          continue;
        }
        final displayName = subject.displayName(locale).trim();
        if (displayName.isNotEmpty) {
          labels[key] = displayName;
        }
      }
    } catch (_) {}

    return labels;
  }

  Future<List<UnifiedFilterSchoolGroup>> _resolveSchoolFilterGroups(
    Iterable<Ayat> sourceAyat,
  ) async {
    final schoolsById = <int, School>{};
    try {
      final schools = await SchoolServices().getAllSchools();
      for (final school in schools) {
        final schoolId = school.id;
        if (schoolId == null) {
          continue;
        }
        schoolsById[schoolId] = school;
      }
    } catch (_) {}

    final groupTitles = <int, String>{};
    final groupedLevels = <int, Map<String, UnifiedFilterSchoolLevel>>{};

    for (final ayah in sourceAyat) {
      final schoolLevels = ayah.schoolLevels ?? const <SchoolLevel>[];
      for (final level in schoolLevels) {
        final schoolId = level.schoolId;
        final levelNumber = level.level;
        if (schoolId == null || levelNumber == null) {
          continue;
        }

        groupTitles[schoolId] = _resolveSchoolName(level, schoolsById);
        final filterKey = _schoolLevelFilterKey(schoolId, levelNumber);
        groupedLevels
            .putIfAbsent(schoolId, () => <String, UnifiedFilterSchoolLevel>{})
            .putIfAbsent(
              filterKey,
              () => UnifiedFilterSchoolLevel(
                key: filterKey,
                label: _resolveSchoolFilterLevelName(level, schoolsById),
                level: levelNumber,
              ),
            );
      }
    }

    final groups = groupedLevels.entries
        .map((entry) {
          final levels = entry.value.values.toList()
            ..sort((left, right) => left.level.compareTo(right.level));
          return UnifiedFilterSchoolGroup(
            label: groupTitles[entry.key] ?? entry.key.toString(),
            levels: levels,
          );
        })
        .where((group) => group.levels.isNotEmpty)
        .toList()
      ..sort((left, right) => left.label.compareTo(right.label));

    return groups;
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

  /// Cached [first, last] mushaf page range derived from the active reader
  /// scope filter. Null when no scope is active (full mushaf).
  (int, int)? _scopePageRange;

  /// Resolve the scope-effective surah set per cascading rule:
  /// surahIds > juzs > thirds > none.
  Set<int> _resolveScopeSurahIds() {
    if (_filterSurahIds.isNotEmpty) {
      return Set<int>.from(_filterSurahIds);
    }
    if (_filterJuzs.isNotEmpty) {
      return _ReaderScopeData.surahsInJuzs(_filterJuzs);
    }
    if (_filterThirds.isNotEmpty) {
      final juzs = <int>{};
      for (final third in _filterThirds) {
        juzs.addAll(_ReaderScopeData.juzsInThird(third));
      }
      return _ReaderScopeData.surahsInJuzs(juzs);
    }
    return const <int>{};
  }

  void _recomputeScopePageRange() {
    final surahs = _resolveScopeSurahIds();
    if (surahs.isEmpty) {
      _scopePageRange = null;
      return;
    }
    var minPage = _mushafLastPage;
    var maxPage = _mushafFirstPage;
    for (final s in surahs) {
      final first = quran.getPageNumber(s, 1);
      final last = quran.getPageNumber(s, quran.getVerseCount(s));
      if (first < minPage) minPage = first;
      if (last > maxPage) maxPage = last;
    }
    _scopePageRange = (minPage, maxPage);
  }

  int get _scopeFirstPage {
    if (_scopePageRange != null) return _scopePageRange!.$1;
    return _mushafFirstPage;
  }

  int get _scopeLastPage {
    if (_scopePageRange != null) return _scopePageRange!.$2;
    return _mushafLastPage;
  }

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

  Future<List<Ayat>> _loadCurrentNavigationAyat() async {
    await _ensureNavigationInitialized();

    if (_isPageNavigation) {
      // Load every ayah on this mushaf page across all surahs so that a
      // single page that spans the end of one surah and the start of another
      // shows both surahs in place instead of being split across two pages.
      final pageAyat = await AyatController().loadAyatByPage(_currentPage!);
      pageAyat.sort(_compareAyatOrder);
      return pageAyat;
    }

    if (_currentHizbQuarter != null) {
      return _navigationScopeAyat
          .where((ayah) => ayah.hizbQuarter == _currentHizbQuarter)
          .toList();
    }

    return List<Ayat>.from(_navigationScopeAyat);
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
    final ayahKey = ayah.id ?? ((ayah.surah.id * 1000) + ayah.ayahNo);
    final recognizer = _ayahTapRecognizers.putIfAbsent(
      ayahKey,
      () => TapGestureRecognizer(),
    );

    recognizer.onTap = _canTapAyah(usersProvider)
        ? () => _openAssessmentDialogForAyah(
              ayah,
              evaluationsProvider,
              languageProvider,
            )
        : null;

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

    final role = viewer.userRoleId ?? 0;
    final isPrivileged = role == 1 || role == 2;
    return isPrivileged && viewer.id != selectedUser.id;
  }

  bool _canTapAyah(UsersProvider usersProvider) {
    return _hasConnection &&
        (_canOpenAssessment || _isSupervisorViewingStudent(usersProvider));
  }

  bool _isMasteredMemoEvaluation(Evaluation? evaluation) {
    if (evaluation == null || evaluation.type != 'memorization') {
      return false;
    }

    final code = evaluation.code.trim().toLowerCase();
    final nameAr = evaluation.name['ar']?.trim() ?? '';
    final nameEn = evaluation.name['en']?.trim().toLowerCase() ?? '';
    return code == 'g' || nameAr == 'متمكن' || nameEn == 'proficient';
  }

  bool _isAyahMasteredForRecommendation(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
  ) {
    final existingEvaluation = ayah.userEvaluation ??
        evaluationsProvider.getUserEvaluationForAyah(ayah.id);
    final memoEvaluation = existingEvaluation?.memoEvaluation ??
        evaluationsProvider.findEvaluationById(existingEvaluation?.memoId);
    return _isMasteredMemoEvaluation(memoEvaluation);
  }

  TeacherRecommendation _hydrateRecommendationWithViewer(
    TeacherRecommendation recommendation,
  ) {
    final viewer = _viewerUser;
    if (viewer == null || recommendation.teacher != null) {
      return recommendation;
    }

    return TeacherRecommendation(
      id: recommendation.id,
      teacherId: recommendation.teacherId,
      studentId: recommendation.studentId,
      ayahId: recommendation.ayahId,
      source: recommendation.source,
      status: recommendation.status,
      notified: recommendation.notified,
      createdAt: recommendation.createdAt,
      updatedAt: recommendation.updatedAt,
      teacher: TeacherRecommendationTeacher(
        id: viewer.id,
        username: viewer.username.isNotEmpty ? viewer.username : null,
        email: viewer.email,
      ),
    );
  }

  Future<void> _sendSupervisorRecommendationForAyah(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
  ) async {
    final usersProvider = context.read<UsersProvider>();
    final student = usersProvider.selectedUser;
    if (student == null || ayah.id == null) {
      return;
    }

    if (_isAyahMasteredForRecommendation(ayah, evaluationsProvider)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('quran_reading_recommendation_mastered_blocked'.tr),
        ),
      );
      return;
    }

    final studentLabel =
        student.username.isNotEmpty ? student.username : student.email;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'quran_reading_recommendation_dialog_title'.trParams({
            'ayah': ayah.ayahNo.toString(),
          }),
        ),
        content: Text(
          'quran_reading_recommendation_dialog_body'.trParams({
            'student': studentLabel,
            'ayah': ayah.ayahNo.toString(),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('quran_reading_recommendation_cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('quran_reading_recommendation_confirm'.tr),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final result = await _teacherRecommendationsService.createRecommendation(
        studentId: student.id,
        ayahId: ayah.id!,
      );
      if (!mounted) {
        return;
      }

      final hydratedRecommendation =
          _hydrateRecommendationWithViewer(result.recommendation);
      setState(() {
        ayah.teacherRecommendations = [
          ...ayah.teacherRecommendations.where(
            (item) => item.id != hydratedRecommendation.id,
          ),
          hydratedRecommendation,
        ];
      });

      unawaited(
        _teacherRecommendationsService
            .refreshStudentRecommendationsInBackground(
          student.id,
          ayahIds: [ayah.id!],
          onUpdated: (freshRecommendations) {
            if (!mounted) {
              return;
            }

            setState(() {
              ayah.teacherRecommendations = freshRecommendations
                  .where((item) => item.ayahId == ayah.id)
                  .toList();
            });
          },
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.operation == 'updated'
                ? 'quran_reading_recommendation_updated'.tr
                : 'quran_reading_recommendation_sent'.tr,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = '$error';
      final feedbackKey = message.contains('Cannot recommend mastered ayahs')
          ? 'quran_reading_recommendation_mastered_blocked'
          : 'quran_reading_recommendation_send_error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedbackKey.tr)),
      );
    }
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
    if (_isSupervisorViewingStudent(usersProvider)) {
      await _sendSupervisorRecommendationForAyah(ayah, evaluationsProvider);
      return;
    }

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
    await _ensureAllAyatIndexedByPage();

    // Snapshot the dimensions available across the loaded ayat so the picker
    // only offers values the user can actually act on right now.
    final availableSubjectKeys = <String>{};
    for (final ayah in _allAyat) {
      if (ayah.subjects != null) {
        availableSubjectKeys.addAll(ayah.subjects!);
      }
    }

    final availableSubjects = await _resolveSubjectDisplayLabels(
      availableSubjectKeys,
    );
    final availableSchoolGroups = await _resolveSchoolFilterGroups(_allAyat);
    if (!mounted) {
      return;
    }

    final initial = UnifiedFilterSelection(
      thirds: {..._filterThirds},
      juzs: {..._filterJuzs},
      surahIds: {..._filterSurahIds},
      ayahTypes: {..._filterAyahTypes},
      subjectKeys: {..._filterSubjectKeys},
      schoolLevelIds: {..._filterSchoolLevelIds},
      memoEvaluationIds: {..._filterMemoEvaluationIds},
      compreEvaluationIds: {..._filterCompreEvaluationIds},
    );

    final result = await showUnifiedQuranFilterSheet(
      context,
      initial: initial,
      available: UnifiedFilterAvailableData(
        subjects: availableSubjects,
        schoolGroups: availableSchoolGroups,
        memorizationEvaluations: evaluationsProvider.memorizationEvaluations,
        comprehensionEvaluations: evaluationsProvider.comprehensionEvaluations,
      ),
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
        _recomputeScopePageRange();
      });

      final selectedUser = context.read<UsersProvider>().selectedUser;
      if (selectedUser == null) {
        return;
      }

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

  String _resolveSchoolLevelName(SchoolLevel level) {
    final raw = level.name;
    if (raw == null) {
      final levelNumber = level.level;
      if (levelNumber != null) {
        final fallbackKey = 'level_$levelNumber';
        final translated = fallbackKey.tr;
        return translated == fallbackKey ? levelNumber.toString() : translated;
      }
      return level.id ?? '';
    }
    final localized = _resolveLocalizedMapValue(raw);
    if (localized.isNotEmpty) {
      return localized;
    }
    return level.id ?? '';
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
    var canOpenAssessment = _hasConnection;
    String? readingNotice = _hasConnection
        ? null
        : _tr(
            'quran_reading_connection_notice',
          );

    if (_hasConnection) {
      if (evaluationsProvider.evaluations.isEmpty) {
        try {
          await evaluationsProvider.getAllEvaluations();
        } catch (_) {
          canOpenAssessment = false;
          readingNotice ??= _tr(
            'quran_reading_assessment_options_error',
          );
        }
      }
    }

    await _ensureNavigationInitialized();
    await _ensureAllAyatIndexedByPage();

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
      if (_currentPage != null) {
        _ayat
          ..clear()
          ..addAll(_ayatForPage(_currentPage!));
      }
    });

    await _persistReadingSession();
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
    final isSupervisorRecommendationMode =
        _isSupervisorViewingStudent(usersProvider);
    final ayahTapTooltip = isSupervisorRecommendationMode
        ? 'quran_reading_recommendation_tap_tooltip'.tr
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
                          _ReaderSurahPill(
                            surahName: (_activeSurah ?? widget.surah).nameAr,
                            isDarkMode: isDarkMode,
                            tooltip: _tr('quran_reading_surah_picker_tooltip'),
                            onTap: _openSurahPicker,
                          ),
                          const SizedBox(width: 8),
                          _ReaderToolIcon(
                            icon: Icons.tune_rounded,
                            tooltip: _tr('quran_reading_filters_tooltip'),
                            isDarkMode: isDarkMode,
                            isActive: _hasAnyActiveReaderFilter,
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
                                isActive: _canTapAyah(usersProvider),
                                flat: true,
                                onTap: null,
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
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Column(
                    children: [
                      const PendingSyncBanner(bottomPadding: 8),
                      if (_readingNotice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 12),
                          child: _ReadingNoticeBanner(
                            message: _readingNotice!,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: _readingSurfaceColor(isDarkMode),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 4,
                              ),
                              child: Column(
                                children: [
                                  Expanded(
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
                                              pages:
                                                  _pagesAroundIndex(index),
                                            ),
                                          );
                                        }
                                        unawaited(_persistReadingSession());
                                      },
                                      itemCount: _pageSequence.length,
                                      itemBuilder: (context, index) {
                                        final page = _pageSequence[index];
                                        final pageAyat = _ayatForPage(page);
                                        return SingleChildScrollView(
                                          padding: const EdgeInsets.fromLTRB(
                                              4, 10, 4, 10),
                                          child: _ReaderRenderedPage(
                                            pageNumber: page,
                                            isDarkMode: isDarkMode,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: _buildAyatWidgets(
                                                pageAyat,
                                                languageProvider,
                                                evaluationProvider,
                                                _hasConnection,
                                                isDarkMode,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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
                                                        : const Color(
                                                            0xFF132A4A,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _currentNavigationJuz !=
                                                            null
                                                        ? _trParams(
                                                            'quran_reading_juz_indicator',
                                                            {
                                                              'juz':
                                                                  _currentNavigationJuz
                                                                      .toString(),
                                                            },
                                                          )
                                                        : widget.surah.nameAr,
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF132A4A,
                                                            ),
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                        : const Color(
                                                            0xFF132A4A,
                                                          ),
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
                                                                  forward:
                                                                      false,
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

  List<Widget> _buildAyatWidgets(
      List<Ayat> ayat,
      LanguageProvider languageProvider,
      EvaluationsProvider evaluationProvider,
      bool hasConnection,
      bool isDarkMode) {
    List<Widget> widgets = [];
    if (ayat.isEmpty) return widgets;

    List<List<Ayat>> groups = [];
    List<Ayat> currentGroup = [];
    int? currentSurahId;

    for (var ayah in ayat) {
      if (currentSurahId != null && ayah.surah.id != currentSurahId) {
        groups.add(currentGroup);
        currentGroup = [];
      }
      currentGroup.add(ayah);
      currentSurahId = ayah.surah.id;
    }
    if (currentGroup.isNotEmpty) groups.add(currentGroup);

    for (var group in groups) {
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
                firstAyah.surah.nameAr,
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
              final userEvaluation = ayah.userEvaluation ??
                  evaluationProvider.getUserEvaluationForAyah(ayah.id);

              final defaultColor =
                  isDarkMode ? Colors.white : AppColors.blackFontColor;
              final fadedColor = isDarkMode
                  ? const Color(0xFF4A4A4A)
                  : const Color(0xFFCFCFCF);
              final isFiltered = _hasAnyActiveReaderFilter &&
                  !_ayahMatchesActiveReaderSelection(ayah, evaluationProvider);

              final memoEvaluation = userEvaluation?.memoEvaluation ??
                  evaluationProvider.findEvaluationById(userEvaluation?.memoId);
              final compreEvaluation = userEvaluation?.compreEvaluation ??
                  evaluationProvider
                      .findEvaluationById(userEvaluation?.compreId);

              final hasMemorizationAccent = !isFiltered &&
                  _showMemorizationColors &&
                  memoEvaluation != null;
              final accentColor = hasMemorizationAccent
                  ? _resolveReadableVerseColor(
                      preferredColor: EvaluationsController()
                          .getColorForEvaluationModel(memoEvaluation),
                      fallbackColor: isDarkMode
                          ? const Color(0xFFE6DFD0)
                          : AppColors.buttonColor,
                      isDarkMode: isDarkMode,
                    )
                  : (isFiltered ? fadedColor : defaultColor);
              final verseColor = isFiltered
                  ? fadedColor
                  : (hasMemorizationAccent ? accentColor : defaultColor);

              final showUnderline = !isFiltered &&
                  _showComprehensionUnderline &&
                  EvaluationsController()
                      .isPositiveComprehension(compreEvaluation);
              final ayahTapRecognizer = _getAyahTapRecognizer(
                ayah,
                evaluationProvider,
                languageProvider,
              );

              return TextSpan(
                text: '${ayah.text} ',
                recognizer: ayahTapRecognizer,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.8,
                  color: verseColor,
                  fontFamily: AppFonts.versesFont,
                  decoration: showUnderline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: showUnderline ? accentColor : null,
                  decorationThickness: showUnderline ? 1.8 : null,
                ),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.only(start: 4, end: 4),
                      child: GestureDetector(
                        onTap: ayahTapRecognizer.onTap,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: accentColor, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              ayah.ayahNo.toString(),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.0,
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isFiltered && ayah.teacherRecommendations.isNotEmpty)
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
                ],
              );
            }).toList(),
          ),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          textWidthBasis: TextWidthBasis.parent,
        ),
      );

      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }
}

class _ReadingNoticeBanner extends StatelessWidget {
  const _ReadingNoticeBanner({
    required this.message,
    required this.isDarkMode,
  });

  final String message;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 980),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A211B) : const Color(0xFFFFF5E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF6E5130) : const Color(0xFFE0BC7A),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFAF7E22),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                height: 1.45,
                color: isDarkMode
                    ? const Color(0xFFF3E2C3)
                    : const Color(0xFF7A5B18),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
        : (disabled ? const Color(0xFF9AA3B2) : const Color(0xFF132A4A));
    final background = flat
        ? Colors.transparent
        : (isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0));

    final activeOverlay = isActive
        ? (isDarkMode
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFF132A4A).withValues(alpha: 0.10))
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
    final foreground = isDarkMode ? Colors.white : const Color(0xFF132A4A);
    final pill = Material(
      color: isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Text(
            surahName,
            style: TextStyle(
              color: foreground,
              fontSize: 16,
              fontWeight: FontWeight.w800,
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
  });

  final int pageNumber;
  final bool isDarkMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDarkMode
        ? const Color(0xFF8B6914)
        : const Color(0xFFB7852A);
    final bgColor = isDarkMode
        ? const Color(0xFF1C1A15)
        : const Color(0xFFFDFAF3);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ReaderPageRail extends StatelessWidget {
  const _ReaderPageRail({
    required this.isDarkMode,
    required this.currentIndex,
    required this.maxIndex,
    required this.currentPageLabel,
    required this.onChangeEnd,
  });

  final bool isDarkMode;
  final double currentIndex;
  final double maxIndex;
  final String currentPageLabel;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final clampedValue = currentIndex
        .clamp(0.0, math.max(0.0, maxIndex))
        .toDouble();

    return Container(
      width: 36,
      margin: const EdgeInsetsDirectional.only(end: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            currentPageLabel,
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF132A4A),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  min: 0,
                  max: math.max(1.0, maxIndex),
                  value: clampedValue,
                  onChanged: (_) {},
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        color: isDarkMode ? Colors.white : const Color(0xFF132A4A),
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: onTap != null ? TextDecoration.underline : null,
        decorationStyle: onTap != null ? TextDecorationStyle.dotted : null,
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
        : (disabled ? const Color(0xFFB9C0CC) : const Color(0xFF132A4A));
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

/// Static helpers + cached lookup tables for the reader's hierarchical
/// scope filter (Thirds -> Juz -> Surahs). Built lazily on first access
/// using the `quran` package metadata.
class _ReaderScopeData {
  static const int _juzsPerThird = 10;
  static Map<int, List<int>>? _juzToSurahs;

  static int thirdOfJuz(int juz) => ((juz - 1) ~/ _juzsPerThird) + 1;

  static Iterable<int> juzsInThird(int third) {
    final start = (third - 1) * _juzsPerThird + 1;
    final end = third * _juzsPerThird;
    return Iterable<int>.generate(end - start + 1, (i) => start + i);
  }

  static Map<int, List<int>> _ensureJuzToSurahs() {
    final cached = _juzToSurahs;
    if (cached != null) return cached;
    final map = <int, Set<int>>{};
    for (var s = 1; s <= quran.totalSurahCount; s++) {
      final firstJuz = quran.getJuzNumber(s, 1);
      final lastJuz = quran.getJuzNumber(s, quran.getVerseCount(s));
      for (var j = firstJuz; j <= lastJuz; j++) {
        (map[j] ??= <int>{}).add(s);
      }
    }
    final sorted = <int, List<int>>{
      for (final entry in map.entries)
        entry.key: (entry.value.toList()..sort()),
    };
    _juzToSurahs = sorted;
    return sorted;
  }

  static Set<int> surahsInJuzs(Iterable<int> juzs) {
    final out = <int>{};
    final table = _ensureJuzToSurahs();
    for (final j in juzs) {
      final list = table[j];
      if (list != null) out.addAll(list);
    }
    return out;
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
                      quran.getSurahNameArabic(surahNumber),
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
