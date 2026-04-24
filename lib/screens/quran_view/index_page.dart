import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sahifaty/controllers/ayat_controller.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/services/teacher_recommendations_service.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import '../../controllers/general_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../core/reading/reading_session.dart';
import '../../core/utils/size_config.dart';
import '../../models/surah.dart';
import '../../providers/general_provider.dart';
import '../widgets/global_drawer.dart';
import '../widgets/assessment_input_dialog.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/pending_sync_banner.dart';
import '../widgets/teacher_recommendation_badge.dart';

enum _ReadingNavigationMode { page, hizbQuarter }

class IndexPage extends StatefulWidget {
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

  String _tr(String key) => key.tr;

  String _trParams(String key, Map<String, String> params) =>
      key.trParams(params);

  bool get _isPageNavigation =>
      _navigationMode == _ReadingNavigationMode.page &&
      _pageSequence.isNotEmpty &&
      _currentPage != null;

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
    if (widget.page != null) {
      return (await AyatController().loadAyatBySurah(widget.surah.id))
          .where((ayah) => ayah.page == widget.page)
          .toList();
    }

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
    final hasCompletePageData =
        pageSequence.isNotEmpty && _navigationScopeAyat.every((ayah) => ayah.page != null);

    if (hasCompletePageData) {
      _navigationMode = _ReadingNavigationMode.page;
      _pageSequence = pageSequence;

      final preferredPage = widget.restoredPage ??
          widget.page ??
          _firstValueForSelectedSurah(
            _navigationScopeAyat,
            (ayah) => ayah.page,
          );

      _currentPage = _resolveClosestAvailableValue(_pageSequence, preferredPage);
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
      return _navigationScopeAyat
          .where((ayah) => ayah.page == _currentPage)
          .toList();
    }

    if (_currentHizbQuarter != null) {
      return _navigationScopeAyat
          .where((ayah) => ayah.hizbQuarter == _currentHizbQuarter)
          .toList();
    }

    return List<Ayat>.from(_navigationScopeAyat);
  }

  Future<void> _loadAdjacentChunk({required bool forward}) async {
    final userId = context.read<UsersProvider>().selectedUser!.id;
    final evalProvider = context.read<EvaluationsProvider>();

    if (_isPageNavigation) {
      final currentIndex = _pageSequence.indexOf(_currentPage!);
      if (currentIndex == -1) {
        return;
      }

      final nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
      if (nextIndex < 0 || nextIndex >= _pageSequence.length) {
        return;
      }

      setState(() {
        _currentPage = _pageSequence[nextIndex];
      });
      await _loadAyat(userId, evalProvider);
      return;
    }

    if (_currentHizbQuarter == null) {
      return;
    }

    final nextQuarter = forward
        ? _currentHizbQuarter! + 1
        : _currentHizbQuarter! - 1;
    if ((_minHizbQuarter != null && nextQuarter < _minHizbQuarter!) ||
        (_maxHizbQuarter != null && nextQuarter > _maxHizbQuarter!)) {
      return;
    }

    setState(() {
      _currentHizbQuarter = nextQuarter;
    });
    await _loadAyat(userId, evalProvider);
  }

  TapGestureRecognizer _getAyahTapRecognizer(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
    LanguageProvider languageProvider,
  ) {
    final ayahKey = ayah.id ?? ((ayah.surah.id * 1000) + ayah.ayahNo);
    final recognizer = _ayahTapRecognizers.putIfAbsent(
      ayahKey,
      () => TapGestureRecognizer(),
    );

    recognizer.onTap = (_hasConnection && _canOpenAssessment)
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

  Future<void> _openAssessmentDialogForAyah(
    Ayat ayah,
    EvaluationsProvider evaluationsProvider,
    LanguageProvider languageProvider,
  ) async {
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

    final savedScrollOffset = _scrollController.offset;
    final selection = await showAssessmentInputDialog(
      context: context,
      evaluationsProvider: evaluationsProvider,
      languageProvider: languageProvider,
      initialMemoId: ayah.userEvaluation?.memoId,
      initialCompreId: ayah.userEvaluation?.compreId,
      title: _trParams(
        'quran_reading_evaluate_ayah_title',
        {'ayah': ayah.ayahNo.toString()},
      ),
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
      memoChanged: selection.memoChanged,
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
      memoChanged: selection.memoChanged,
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
    } catch (_) {
      // Keep web and unsupported environments quiet; reading can proceed without wake lock.
    }
  }

  Future<void> _loadAyat(
      int userId, EvaluationsProvider evaluationsProvider) async {
    await _refreshConnectivity();

    List<Ayat> ayat = await _loadCurrentNavigationAyat();

    // If navigating via Parts or Thirds filter, remove ayats from previous surahs in the same quarter
    // This ensures that if a quarter starts with Al-Fatihah but Al-Baqarah was selected, Al-Baqarah appears at the top.
    if (_isInitialLoad &&
        (widget.filterTypeId == FilterTypes.parts ||
            widget.filterTypeId == FilterTypes.thirds)) {
      ayat = ayat.where((a) => a.surah.id >= widget.surah.id).toList();
    }
    _isInitialLoad = false;

    // ---------------------------------------------
    // FILTER AYAT BY JUZ/THIRD RANGE
    // ---------------------------------------------
    if (widget.filterTypeId == FilterTypes.parts ||
        widget.filterTypeId == FilterTypes.thirds) {
      if (widget.juz != null || widget.filterTypeId == FilterTypes.thirds) {
        // We already set current/min/max hizb quarters above.
        // The ayat list 'ayat' from loadAyatByHizbQuarter is correct.
      }
    }
    // ---------------------------------------------

    final ayatIds = ayat.map((ayah) => ayah.id!).toList();
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
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: AppBar(
                    leading: CustomBackButton(
                      onPressed: _handleExitReading,
                    ),
                    actions: [
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            if ((Get.locale?.languageCode ?? 'ar') == 'ar') {
                              Scaffold.of(context).openDrawer();
                            } else {
                              Scaffold.of(context).openEndDrawer();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              drawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? const GlobalDrawer()
                  : null,
              endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? null
                  : const GlobalDrawer(),
              body: Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.blackFontColor,
                    width: 8.0,
                  ),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: SizeConfig.getProportionalHeight(5),
                    horizontal: SizeConfig.getProportionalWidth(10),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const PendingSyncBanner(bottomPadding: 12),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 980),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF171C24)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2C3442)
                                  : const Color(0xFFDDE3DA),
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: Text(
                                  _tr('quran_reading_show_memorization_colors'),
                                ),
                                selected: _showMemorizationColors,
                                onSelected: (value) async {
                                  await _updateReadingDisplayPreferences(
                                    showMemorizationColors: value,
                                  );
                                },
                              ),
                              FilterChip(
                                label: Text(
                                  _tr(
                                    'quran_reading_show_comprehension_underline',
                                  ),
                                ),
                                selected: _showComprehensionUnderline,
                                onSelected: (value) async {
                                  await _updateReadingDisplayPreferences(
                                    showComprehensionUnderline: value,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20, top: 12),
                          child: _readingNotice == null
                              ? const SizedBox.shrink()
                              : _ReadingNoticeBanner(
                                  message: _readingNotice!,
                                  isDarkMode: isDarkMode,
                                ),
                        ),
                        ..._buildAyatWidgets(
                          languageProvider,
                          evaluationProvider,
                          _hasConnection,
                          isDarkMode,
                        ),
                        if (_isPageNavigation || _currentHizbQuarter != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if ((_isPageNavigation &&
                                        _pageSequence.indexOf(_currentPage!) > 0) ||
                                    (!_isPageNavigation &&
                                        _currentHizbQuarter! >
                                            (_initialHizbQuarter ?? _minHizbQuarter!)))
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    onPressed: () =>
                                        _loadAdjacentChunk(forward: false),
                                    child: const Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 20,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 48),
                                if (_isPageNavigation)
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? const Color(0xFF1E1E1E)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: isDarkMode
                                                ? const Color(0xFF2C3442)
                                                : const Color(0xFFDDE3DA),
                                          ),
                                        ),
                                        child: Text(
                                          _trParams(
                                            'quran_reading_page_indicator',
                                            {'page': _currentPage!.toString()},
                                          ),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : AppColors.blackFontColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const Spacer(),
                                if ((_isPageNavigation &&
                                        _pageSequence.indexOf(_currentPage!) <
                                            _pageSequence.length - 1) ||
                                    (!_isPageNavigation &&
                                        _currentHizbQuarter! < _maxHizbQuarter!))
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    onPressed: () =>
                                        _loadAdjacentChunk(forward: true),
                                    child: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 20,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                          ),
                      ],
                    ),
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

      // Show surah title and Basmalah logic
      final isAtStartOfSurah = firstAyah.ayahNo == 1;

      if (isAtStartOfSurah) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _trParams(
                'quran_reading_surah_heading',
                {'surah': firstAyah.surah.nameAr},
              ),
              style: TextStyle(
                fontSize: 22,
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
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(
                    fontSize: 18,
                    height: 2,
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

              final memoEvaluation = userEvaluation?.memoEvaluation ??
                  evaluationProvider.findEvaluationById(userEvaluation?.memoId);
              final compreEvaluation = userEvaluation?.compreEvaluation ??
                  evaluationProvider
                      .findEvaluationById(userEvaluation?.compreId);

              final color = _showMemorizationColors
                  ? (memoEvaluation != null
                      ? EvaluationsController()
                          .getColorForEvaluationModel(memoEvaluation)
                      : defaultColor)
                  : defaultColor;

              final showUnderline = _showComprehensionUnderline &&
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
                  fontSize: 20,
                  height: 2,
                  color: color,
                  fontFamily: AppFonts.versesFont,
                  decoration: showUnderline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: color,
                ),
                children: [
                  TextSpan(
                    text: '${gc.ayahMarker(ayah.ayahNo)} ',
                    recognizer: ayahTapRecognizer,
                    style: TextStyle(
                      fontSize: 24,
                      height: 2,
                      color: color,
                      fontFamily: AppFonts.versesFont,
                    ),
                  ),
                  if (ayah.teacherRecommendations.isNotEmpty)
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
          textAlign: TextAlign.center,
        ),
      );

      widgets.add(const SizedBox(height: 24));
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
