import 'dart:async';

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
import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/services/teacher_recommendations_service.dart';
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
  _ReadingNavigationMode _navigationMode = _ReadingNavigationMode.hizbQuarter;
  List<int> _pageSequence = <int>[];
  int? _currentPage;
  int? _initialPage;
  int? _currentHizbQuarter;
  int? _minHizbQuarter;
  int? _maxHizbQuarter;
  int? _initialHizbQuarter;
  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: true);
  bool _isInitialLoad = true;
  bool _hasConnection = true;
  bool _isConnectivityResolved = false;
  bool _showMemorizationColors = true;
  bool _showComprehensionUnderline = true;
  bool _canOpenAssessment = true;
  String? _readingNotice;
  final Map<int, TapGestureRecognizer> _ayahTapRecognizers =
      <int, TapGestureRecognizer>{};
  final TeacherRecommendationsService _teacherRecommendationsService =
      TeacherRecommendationsService();
  final UsersServices _usersService = UsersServices();
  User? _viewerUser;

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
        final id = level.id;
        return id != null && _filterSchoolLevelIds.contains(id);
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

  bool get _canNavigateBackward {
    if (_isPageNavigation) {
      final currentPage = _currentPage;
      if (currentPage == null) {
        return false;
      }
      return currentPage > _scopeFirstPage;
    }

    final currentQuarter = _currentHizbQuarter;
    final firstQuarter = _initialHizbQuarter ?? _minHizbQuarter;
    if (currentQuarter == null || firstQuarter == null) {
      return false;
    }

    return currentQuarter > firstQuarter;
  }

  bool get _canNavigateForward {
    if (_isPageNavigation) {
      final currentPage = _currentPage;
      if (currentPage == null) {
        return false;
      }
      return currentPage < _scopeLastPage;
    }

    final currentQuarter = _currentHizbQuarter;
    final lastQuarter = _maxHizbQuarter;
    if (currentQuarter == null || lastQuarter == null) {
      return false;
    }

    return currentQuarter < lastQuarter;
  }

  String get _navigationProgressLabel {
    if (_isPageNavigation && _currentPage != null) {
      return '$_currentPage / 604';
    }

    return 'Q${_currentHizbQuarter ?? '-'}';
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
      final currentPage = _currentPage;
      if (currentPage == null) {
        return;
      }

      final nextPage = forward ? currentPage + 1 : currentPage - 1;
      if (nextPage < _scopeFirstPage || nextPage > _scopeLastPage) {
        return;
      }

      setState(() {
        _currentPage = nextPage;
        if (!_pageSequence.contains(nextPage)) {
          _pageSequence = <int>[..._pageSequence, nextPage]..sort();
        }
      });
      await _loadAyat(userId, evalProvider);
      _scheduleReadingScrollResetToTop();
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
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
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
        _scrollController.hasClients ? _scrollController.offset : 0.0;
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
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(savedScrollOffset);
      }
    });
  }

  Future<void> _persistReadingSession({bool shouldAutoResume = true}) async {
    final selectedUser = context.read<UsersProvider>().selectedUser;
    if (selectedUser == null) {
      return;
    }

    await _readingSessionStore.save(
      ReadingSession(
        userId: selectedUser.id,
        surah: widget.surah,
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

  void _replaceWithRoute({
    required Surah surah,
    required int filterTypeId,
    int? juz,
    int? page,
  }) {
    final parameters = IndexPage.routeParameters(
      surah: surah,
      filterTypeId: filterTypeId,
      juz: juz,
      page: page,
    );
    Get.offNamed(IndexPage.routeName, parameters: parameters);
  }

  void _navigateToJuz(int juz) {
    final firstSurahNumber = quran.getSurahAndVersesFromJuz(juz).keys.first;
    _replaceWithRoute(
      surah: Surah(
        id: firstSurahNumber,
        nameAr: quran.getSurahNameArabic(firstSurahNumber),
        ayahCount: quran.getVerseCount(firstSurahNumber),
      ),
      filterTypeId: FilterTypes.parts,
      juz: juz,
    );
  }

  void _navigateToSurah(int surahNumber) {
    _replaceWithRoute(
      surah: Surah(
        id: surahNumber,
        nameAr: quran.getSurahNameArabic(surahNumber),
        ayahCount: quran.getVerseCount(surahNumber),
      ),
      filterTypeId: FilterTypes.thirds,
    );
  }

  Future<void> _navigateToPage(int targetPage) async {
    if (targetPage < 1 || targetPage > 604) {
      return;
    }

    // Locate the first surah covered on this mushaf page so that the route
    // carries a sensible surah id, then load page-mode navigation around it.
    int? resolvedSurahId;
    try {
      final pageAyat = await AyatController().loadAyatByPage(targetPage);
      if (pageAyat.isNotEmpty) {
        pageAyat.sort(_compareAyatOrder);
        resolvedSurahId = pageAyat.first.surah.id;
      }
    } catch (_) {
      // Fall back to the current surah if the lookup fails.
    }

    final surahNumber = resolvedSurahId ?? widget.surah.id;
    _replaceWithRoute(
      surah: Surah(
        id: surahNumber,
        nameAr: quran.getSurahNameArabic(surahNumber),
        ayahCount: quran.getVerseCount(surahNumber),
      ),
      filterTypeId: widget.filterTypeId,
      page: targetPage,
    );
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
      _navigateToJuz(selected);
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
      _navigateToSurah(selected);
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
      ),
    );

    if (selected != null && mounted) {
      await _navigateToPage(selected);
    }
  }

  Future<void> _openDisplayFilter() async {
    final evaluationsProvider = context.read<EvaluationsProvider>();

    // Snapshot the dimensions available across the loaded ayat so the picker
    // only offers values the user can actually act on right now.
    final availableSubjects = <String>{};
    final availableSchoolLevels = <String, String>{}; // id -> display name
    for (final ayah in _ayat) {
      if (ayah.subjects != null) {
        availableSubjects.addAll(ayah.subjects!);
      }
      if (ayah.schoolLevels != null) {
        for (final level in ayah.schoolLevels!) {
          final id = level.id;
          if (id == null) continue;
          final localizedName = _resolveSchoolLevelName(level);
          availableSchoolLevels[id] = localizedName;
        }
      }
    }

    final result = await showModalBottomSheet<_ReadingDisplayFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ReaderDisplayFilterSheet(
        initialAyahTypes: _filterAyahTypes,
        initialSubjectKeys: _filterSubjectKeys,
        initialSchoolLevelIds: _filterSchoolLevelIds,
        initialMemoEvaluationIds: _filterMemoEvaluationIds,
        initialCompreEvaluationIds: _filterCompreEvaluationIds,
        initialThirds: _filterThirds,
        initialJuzs: _filterJuzs,
        initialSurahIds: _filterSurahIds,
        availableSubjects: availableSubjects,
        availableSchoolLevels: availableSchoolLevels,
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

      // If the active page falls outside the new scope, snap to scope start.
      final currentPage = _currentPage;
      final range = _scopePageRange;
      if (range != null &&
          currentPage != null &&
          (currentPage < range.$1 || currentPage > range.$2)) {
        await _navigateToPage(range.$1);
      }
    }
  }

  String _resolveSchoolLevelName(SchoolLevel level) {
    final raw = level.name;
    if (raw == null) {
      return level.id ?? '';
    }
    final locale = Get.locale?.languageCode ?? 'ar';
    final localized = raw[locale] ?? raw['ar'] ?? raw['en'];
    if (localized is String && localized.trim().isNotEmpty) {
      return localized.trim();
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

    List<Ayat> ayat = await _loadCurrentNavigationAyat();

    if (_isInitialLoad &&
        !_isPageNavigation &&
        (widget.filterTypeId == FilterTypes.parts ||
            widget.filterTypeId == FilterTypes.thirds)) {
      ayat = ayat.where((a) => a.surah.id >= widget.surah.id).toList();
    }
    _isInitialLoad = false;

    final ayatIds =
        ayat.where((ayah) => ayah.id != null).map((ayah) => ayah.id!).toList();
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

      if (canOpenAssessment) {
        try {
          await evaluationsProvider.getAllUserEvaluations(userId, ayatIds);
        } catch (_) {
          readingNotice ??= _tr(
            'quran_reading_previous_assessments_error',
          );
        }
      }

      for (final ayah in ayat) {
        ayah.userEvaluation =
            evaluationsProvider.getUserEvaluationForAyah(ayah.id);
      }

      final loadedRecommendations =
          await _loadTeacherRecommendations(userId, ayat);
      if (!loadedRecommendations) {
        readingNotice ??= _tr(
          'quran_reading_teacher_recommendations_error',
        );
      }
    } else {
      for (final ayah in ayat) {
        ayah.userEvaluation =
            evaluationsProvider.getUserEvaluationForAyah(ayah.id);
        ayah.teacherRecommendations = [];
      }
    }

    setState(() {
      _canOpenAssessment = canOpenAssessment;
      _readingNotice = readingNotice;
      _ayat
        ..clear()
        ..addAll(ayat);
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
                            surahName: widget.surah.nameAr,
                            isDarkMode: isDarkMode,
                            tooltip: _tr('quran_reading_surah_picker_tooltip'),
                            onTap: _openSurahPicker,
                          ),
                          const SizedBox(width: 8),
                          _ReaderToolIcon(
                            icon: Icons.tune_rounded,
                            tooltip: _tr('quran_reading_filters_tooltip'),
                            isDarkMode: isDarkMode,
                            isActive: _hasActiveDisplayFilter,
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity;
                              if (velocity == null || velocity.abs() < 250) {
                                return;
                              }

                              if (velocity > 0) {
                                _loadAdjacentChunk(forward: false);
                              } else {
                                _loadAdjacentChunk(forward: true);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 4,
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: _buildAyatWidgets(
                                          languageProvider,
                                          evaluationProvider,
                                          _hasConnection,
                                          isDarkMode,
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
                                                    size: 16,
                                                    color: isDarkMode
                                                        ? const Color(
                                                            0xFFE6DFD0,
                                                          )
                                                        : const Color(
                                                            0xFF132A4A,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    widget.juz != null
                                                        ? _trParams(
                                                            'quran_reading_juz_indicator',
                                                            {
                                                              'juz': widget.juz
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
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    size: 16,
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
                                                    onTap: _canNavigateBackward
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
                                                    onTap: _canNavigateForward
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
      LanguageProvider languageProvider,
      EvaluationsProvider evaluationProvider,
      bool hasConnection,
      bool isDarkMode) {
    List<Widget> widgets = [];
    if (_ayat.isEmpty) return widgets;

    List<List<Ayat>> groups = [];
    List<Ayat> currentGroup = [];
    int? currentSurahId;

    for (var ayah in _ayat) {
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _trParams(
                'quran_reading_surah_heading',
                {'surah': firstAyah.surah.nameAr},
              ),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
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
                    fontSize: 28,
                    height: 1.9,
                    color: isDarkMode ? Colors.white : AppColors.blackFontColor,
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
              final isFiltered = _hasActiveDisplayFilter &&
                  !_ayahMatchesDisplayFilter(ayah, evaluationProvider);

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
                  fontSize: 30,
                  height: 1.9,
                  color: verseColor,
                  fontFamily: AppFonts.versesFont,
                  decoration: showUnderline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: showUnderline ? accentColor : null,
                  decorationThickness: showUnderline ? 1.8 : null,
                ),
                children: [
                  TextSpan(
                    text: '${gc.ayahMarker(ayah.ayahNo)} ',
                    recognizer: ayahTapRecognizer,
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.9,
                      color: accentColor,
                      fontFamily: AppFonts.versesFont,
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
        fontSize: 13,
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
        child: Icon(icon, size: 22, color: foreground),
      ),
    );
  }
}

class _ReadingDisplayFilterResult {
  const _ReadingDisplayFilterResult({
    required this.ayahTypes,
    required this.subjectKeys,
    required this.schoolLevelIds,
    required this.memoEvaluationIds,
    required this.compreEvaluationIds,
    required this.thirds,
    required this.juzs,
    required this.surahIds,
  });

  final Set<String> ayahTypes;
  final Set<String> subjectKeys;
  final Set<String> schoolLevelIds;
  final Set<int> memoEvaluationIds;
  final Set<int> compreEvaluationIds;
  final Set<int> thirds;
  final Set<int> juzs;
  final Set<int> surahIds;
}

/// Static helpers + cached lookup tables for the reader's hierarchical
/// scope filter (Thirds -> Juz -> Surahs). Built lazily on first access
/// using the `quran` package metadata.
class _ReaderScopeData {
  static const int _juzsPerThird = 10;
  static Map<int, List<int>>? _juzToSurahs;

  static Iterable<int> juzsInThird(int third) {
    final start = (third - 1) * _juzsPerThird + 1;
    final end = third * _juzsPerThird;
    return Iterable<int>.generate(end - start + 1, (i) => start + i);
  }

  static int thirdOfJuz(int juz) => ((juz - 1) ~/ _juzsPerThird) + 1;

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
  const _ReaderPagePicker({required this.currentPage});

  final int currentPage;

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
    final initialIndex = (widget.currentPage - 1).clamp(0, 603);
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
    if (parsed == null || parsed < 1 || parsed > 604) {
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
                itemCount: 604,
                itemExtent: 48,
                itemBuilder: (context, index) {
                  final page = index + 1;
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

class _ReaderDisplayFilterSheet extends StatefulWidget {
  const _ReaderDisplayFilterSheet({
    required this.initialAyahTypes,
    required this.initialSubjectKeys,
    required this.initialSchoolLevelIds,
    required this.initialMemoEvaluationIds,
    required this.initialCompreEvaluationIds,
    required this.initialThirds,
    required this.initialJuzs,
    required this.initialSurahIds,
    required this.availableSubjects,
    required this.availableSchoolLevels,
    required this.memorizationEvaluations,
    required this.comprehensionEvaluations,
  });

  final Set<String> initialAyahTypes;
  final Set<String> initialSubjectKeys;
  final Set<String> initialSchoolLevelIds;
  final Set<int> initialMemoEvaluationIds;
  final Set<int> initialCompreEvaluationIds;
  final Set<int> initialThirds;
  final Set<int> initialJuzs;
  final Set<int> initialSurahIds;
  final Set<String> availableSubjects;
  final Map<String, String> availableSchoolLevels;
  final List<Evaluation> memorizationEvaluations;
  final List<Evaluation> comprehensionEvaluations;

  @override
  State<_ReaderDisplayFilterSheet> createState() =>
      _ReaderDisplayFilterSheetState();
}

class _ReaderDisplayFilterSheetState extends State<_ReaderDisplayFilterSheet> {
  late final Set<String> _ayahTypes;
  late final Set<String> _subjects;
  late final Set<String> _schoolLevels;
  late final Set<int> _memos;
  late final Set<int> _compres;
  late final Set<int> _thirds;
  late final Set<int> _juzs;
  late final Set<int> _surahIds;

  @override
  void initState() {
    super.initState();
    _ayahTypes = {...widget.initialAyahTypes};
    _subjects = {...widget.initialSubjectKeys};
    _schoolLevels = {...widget.initialSchoolLevelIds};
    _memos = {...widget.initialMemoEvaluationIds};
    _compres = {...widget.initialCompreEvaluationIds};
    _thirds = {...widget.initialThirds};
    _juzs = {...widget.initialJuzs};
    _surahIds = {...widget.initialSurahIds};
  }

  String _tr(String key) => key.tr;

  String _trParams(String key, Map<String, String> params) =>
      key.trParams(params);

  void _toggleString(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  void _toggleInt(Set<int> set, int value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  String _evaluationLabel(Evaluation evaluation) {
    final locale = Get.locale?.languageCode ?? 'ar';
    final raw = evaluation.name;
    final localized = raw[locale] ?? raw['ar'] ?? raw['en'];
    if (localized != null && localized.trim().isNotEmpty) {
      return localized.trim();
    }
    return evaluation.id?.toString() ?? '';
  }

  Widget _buildDimensionSection({
    required String title,
    required List<Widget> chips,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          if (chips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _tr('quran_reading_filter_empty_dimension'),
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
        ],
      ),
    );
  }

  FilterChip _filterChipString(
    String label,
    String value,
    Set<String> selectionSet,
  ) {
    final selected = selectionSet.contains(value);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _toggleString(selectionSet, value),
    );
  }

  FilterChip _filterChipInt(
    String label,
    int value,
    Set<int> selectionSet,
  ) {
    final selected = selectionSet.contains(value);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _toggleInt(selectionSet, value),
    );
  }

  /// Surahs the user is allowed to pick, narrowed by Thirds/Juz selection.
  /// "كلما قل خيار اثلاث/اجزاء قلت السور المتاحة"
  List<int> get _availableSurahIds {
    final allowedJuzs = <int>{};
    if (_juzs.isNotEmpty) {
      allowedJuzs.addAll(_juzs);
    } else if (_thirds.isNotEmpty) {
      for (final t in _thirds) {
        allowedJuzs.addAll(_ReaderScopeData.juzsInThird(t));
      }
    }
    if (allowedJuzs.isEmpty) {
      return List<int>.generate(quran.totalSurahCount, (i) => i + 1);
    }
    final scoped = _ReaderScopeData.surahsInJuzs(allowedJuzs).toList()..sort();
    return scoped;
  }

  int get _activeDimensionCount {
    var n = 0;
    if (_thirds.isNotEmpty || _juzs.isNotEmpty || _surahIds.isNotEmpty) n++;
    if (_ayahTypes.isNotEmpty) n++;
    if (_subjects.isNotEmpty) n++;
    if (_schoolLevels.isNotEmpty) n++;
    if (_memos.isNotEmpty) n++;
    if (_compres.isNotEmpty) n++;
    return n;
  }

  String _scopeBadgeText() {
    if (_surahIds.isNotEmpty) {
      return _trParams('quran_reading_filter_scope_surahs_count', {
        'count': _surahIds.length.toString(),
      });
    }
    if (_juzs.isNotEmpty) {
      return _trParams('quran_reading_filter_scope_juzs_count', {
        'count': _juzs.length.toString(),
      });
    }
    if (_thirds.isNotEmpty) {
      return _trParams('quran_reading_filter_scope_thirds_count', {
        'count': _thirds.length.toString(),
      });
    }
    return _tr('quran_reading_filter_scope_full_mushaf');
  }

  Widget _buildScopeTreeSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr('quran_reading_filter_scope_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      _scopeBadgeText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              ExpansionTile(
                title: Text(_tr('quran_reading_filter_dim_thirds')),
                tilePadding:
                    const EdgeInsetsDirectional.only(start: 12, end: 8),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var t = 1; t <= 3; t++)
                        _filterChipInt(
                          _tr('quran_reading_filter_third_$t'),
                          t,
                          _thirds,
                        ),
                    ],
                  ),
                ],
              ),
              ExpansionTile(
                title: Text(_tr('quran_reading_filter_dim_juzs')),
                tilePadding:
                    const EdgeInsetsDirectional.only(start: 12, end: 8),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var j = 1; j <= 30; j++)
                        if (_thirds.isEmpty ||
                            _thirds.contains(_ReaderScopeData.thirdOfJuz(j)))
                          _filterChipInt(
                            _trParams('quran_reading_filter_juz_n', {
                              'juz': j.toString(),
                            }),
                            j,
                            _juzs,
                          ),
                    ],
                  ),
                ],
              ),
              ExpansionTile(
                title: Text(_tr('quran_reading_filter_dim_surahs')),
                tilePadding:
                    const EdgeInsetsDirectional.only(start: 12, end: 8),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in _availableSurahIds)
                        _filterChipInt(
                          quran.getSurahNameArabic(s),
                          s,
                          _surahIds,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final revelationOptions = <MapEntry<String, String>>[
      MapEntry('makki', _tr('quran_reading_filter_revelation_makki')),
      MapEntry('madani', _tr('quran_reading_filter_revelation_madani')),
      MapEntry('debatable', _tr('quran_reading_filter_revelation_debatable')),
    ];

    final subjectsList = widget.availableSubjects.toList()..sort();
    final schoolEntries = widget.availableSchoolLevels.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
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
                  _tr('quran_reading_filter_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tr('quran_reading_filter_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildScopeTreeSection(),
                _buildDimensionSection(
                  title: _tr('quran_reading_filter_dim_revelation'),
                  chips: revelationOptions
                      .map((entry) => _filterChipString(
                            entry.value,
                            entry.key,
                            _ayahTypes,
                          ))
                      .toList(),
                ),
                _buildDimensionSection(
                  title: _tr('quran_reading_filter_dim_subject'),
                  chips: subjectsList
                      .map((subject) =>
                          _filterChipString(subject, subject, _subjects))
                      .toList(),
                ),
                _buildDimensionSection(
                  title: _tr('quran_reading_filter_dim_school'),
                  chips: schoolEntries
                      .map((entry) => _filterChipString(
                            entry.value,
                            entry.key,
                            _schoolLevels,
                          ))
                      .toList(),
                ),
                _buildDimensionSection(
                  title: _tr('quran_reading_filter_dim_memorization'),
                  chips: widget.memorizationEvaluations
                      .where((e) => e.id != null)
                      .map((e) => _filterChipInt(
                            _evaluationLabel(e),
                            e.id!,
                            _memos,
                          ))
                      .toList(),
                ),
                _buildDimensionSection(
                  title: _tr('quran_reading_filter_dim_comprehension'),
                  chips: widget.comprehensionEvaluations
                      .where((e) => e.id != null)
                      .map((e) => _filterChipInt(
                            _evaluationLabel(e),
                            e.id!,
                            _compres,
                          ))
                      .toList(),
                ),
                if (_activeDimensionCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _trParams(
                        'quran_reading_filter_active_summary',
                        {'count': _activeDimensionCount.toString()},
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _ayahTypes.clear();
                            _subjects.clear();
                            _schoolLevels.clear();
                            _memos.clear();
                            _compres.clear();
                            _thirds.clear();
                            _juzs.clear();
                            _surahIds.clear();
                          });
                        },
                        child: Text(_tr('quran_reading_filter_clear')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(
                          _ReadingDisplayFilterResult(
                            ayahTypes: _ayahTypes,
                            subjectKeys: _subjects,
                            schoolLevelIds: _schoolLevels,
                            memoEvaluationIds: _memos,
                            compreEvaluationIds: _compres,
                            thirds: _thirds,
                            juzs: _juzs,
                            surahIds: _surahIds,
                          ),
                        ),
                        child: Text(_tr('quran_reading_filter_apply')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
