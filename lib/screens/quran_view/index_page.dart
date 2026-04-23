import 'package:flutter/foundation.dart';
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
import '../widgets/teacher_recommendation_badge.dart';

class IndexPage extends StatefulWidget {
  const IndexPage(
      {super.key,
      required this.surah,
      required this.filterTypeId,
      this.hizb,
      this.hizbQuarter,
      this.juz,
      this.restoredHizbQuarter});

  factory IndexPage.fromReadingSession(ReadingSession session) {
    return IndexPage(
      surah: session.surah,
      filterTypeId: session.filterTypeId,
      juz: session.juz,
      hizb: session.hizb,
      restoredHizbQuarter: session.currentHizbQuarter,
    );
  }

  final Surah surah;
  final int filterTypeId;
  final int? hizb;
  final int? hizbQuarter;
  final int? juz;
  final int? restoredHizbQuarter;

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with WidgetsBindingObserver {
  final gc = GeneralController();
  final ReadingSessionStore _readingSessionStore = ReadingSessionStore();
  OverlayEntry? _menuEntry;
  final List<Ayat> _ayat = [];
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
  final TeacherRecommendationsService _teacherRecommendationsService =
      TeacherRecommendationsService();

  bool get _isArabic => (Get.locale?.languageCode ?? 'ar') == 'ar';

  String _copy(String arabic, String english) => _isArabic ? arabic : english;

  String _entryPathLabel() {
    switch (widget.filterTypeId) {
      case FilterTypes.parts:
        return _copy('الأجزاء', 'parts');
      case FilterTypes.hizbs:
        return _copy('الأحزاب', 'hizbs');
      default:
        return _copy('الأثلاث', 'thirds');
    }
  }

  String _entryPathBody() {
    switch (widget.filterTypeId) {
      case FilterTypes.parts:
        return _copy(
          'أنت داخل القراءة من مسار الأجزاء. النص هو المركز هنا، والتقييم يبقى فعلًا مساعدًا يظهر فقط عندما تحتاجه.',
          'You entered reading through the parts path. The text stays central here, while assessment remains a supporting action only when you need it.',
        );
      case FilterTypes.hizbs:
        return _copy(
          'أنت داخل القراءة من مسار الأحزاب. حافظنا على هدوء السطح، وأبقينا التقييم واضحًا من دون تحميله على النص نفسه.',
          'You entered reading through the hizbs path. The surface stays calm, and assessment remains clear without being loaded directly onto the text itself.',
        );
      default:
        return _copy(
          'أنت داخل القراءة من مسار الأثلاث. استخدم زر تقييم الآية عند الحاجة، ودع النص يبقى هو الفعل الأساسي في هذه الصفحة.',
          'You entered reading through the thirds path. Use the verse assessment action when needed, and let the text remain the primary action on this page.',
        );
    }
  }

  Future<void> _loadReadingDisplayPreferences(
      UsersProvider usersProvider) async {
    await usersProvider.ensureReadingDisplayPreferencesLoaded();
    if (!mounted) {
      return;
    }

    setState(() {
      _showMemorizationColors = usersProvider.showMemorizationColors;
      _showComprehensionUnderline =
          usersProvider.showComprehensionUnderline;
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
        _showComprehensionUnderline =
            usersProvider.showComprehensionUnderline;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _showMemorizationColors = usersProvider.showMemorizationColors;
        _showComprehensionUnderline =
            usersProvider.showComprehensionUnderline;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (Get.locale?.languageCode ?? 'ar') == 'ar'
                ? 'تعذر حفظ تفضيلات العرض حالياً.'
                : 'Unable to save reading display preferences right now.',
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
            _copy(
              'التقييم غير متاح الآن، لكن يمكنك متابعة القراءة والمحاولة لاحقًا.',
              'Assessment is not available right now, but you can keep reading and try again later.',
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
      title: ((Get.locale?.languageCode ?? 'ar') == 'ar')
          ? 'تقييم الآية ${ayah.ayahNo}'
          : 'Evaluate Ayah ${ayah.ayahNo}',
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

    if (_currentHizbQuarter == null ||
        _minHizbQuarter == null ||
        _maxHizbQuarter == null) {
      if (widget.hizbQuarter != null) {
        _currentHizbQuarter = widget.hizbQuarter;
        _minHizbQuarter = 1;
        _maxHizbQuarter = 240;
      } else if ((widget.filterTypeId == FilterTypes.parts ||
              widget.filterTypeId == FilterTypes.thirds) &&
          widget.juz != null) {
        // Start from the beginning of the Juz (Part)
        _minHizbQuarter = (widget.juz! - 1) * 8 + 1;
        _maxHizbQuarter = widget.juz! * 8;

        // Find surah's starting quarter within this Juz
        List<Ayat> surahAyat =
            await AyatController().loadAyatBySurah(widget.surah.id);
        if (surahAyat.isNotEmpty) {
          int surahStart = surahAyat.first.hizbQuarter!;
          _currentHizbQuarter = (widget.restoredHizbQuarter ?? surahStart)
              .clamp(_minHizbQuarter!, _maxHizbQuarter!);
        } else {
          _currentHizbQuarter = widget.restoredHizbQuarter != null
              ? widget.restoredHizbQuarter!.clamp(
                  _minHizbQuarter!,
                  _maxHizbQuarter!,
                )
              : _minHizbQuarter;
        }
      } else {
        List<Ayat> initialAyat;
        if (widget.filterTypeId == FilterTypes.parts ||
            widget.filterTypeId == FilterTypes.thirds) {
          initialAyat = await AyatController().loadAyatBySurah(widget.surah.id);
        } else {
          initialAyat = await AyatController().loadAyatByHizb(widget.hizb!);
        }

        if (initialAyat.isNotEmpty) {
          final quarters =
              initialAyat.map((e) => e.hizbQuarter).whereType<int>().toList();

          quarters.sort();
          _minHizbQuarter = quarters.first;
          _maxHizbQuarter = quarters.last;
          _currentHizbQuarter = widget.restoredHizbQuarter != null
              ? widget.restoredHizbQuarter!.clamp(
                  _minHizbQuarter!,
                  _maxHizbQuarter!,
                )
              : _minHizbQuarter;
        }
        _initialHizbQuarter = _currentHizbQuarter;
      }
    }

    List<Ayat> ayat =
        await AyatController().loadAyatByHizbQuarter(_currentHizbQuarter!);

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
        : _copy(
            'القراءة ما تزال متاحة، لكن التقييم والتوصيات يحتاجان إلى اتصال فعّال.',
            'Reading is still available, but assessment and recommendations need an active connection.',
          );

    if (_hasConnection) {
      if (evaluationsProvider.evaluations.isEmpty) {
        try {
          await evaluationsProvider.getAllEvaluations();
        } catch (_) {
          canOpenAssessment = false;
          readingNotice ??= _copy(
            'تعذر تجهيز خيارات التقييم الآن. يمكنك متابعة القراءة والمحاولة لاحقًا.',
            'Assessment options could not be prepared right now. You can keep reading and try again later.',
          );
        }
      }

      if (canOpenAssessment) {
        try {
          await evaluationsProvider.getAllUserEvaluations(userId, ayatIds);
        } catch (_) {
          readingNotice ??= _copy(
            'تعذر تحميل تقييماتك السابقة الآن. يمكنك متابعة القراءة وإضافة تقييم جديد عند الحاجة.',
            'We could not load your previous assessments right now. You can keep reading and submit a fresh assessment when needed.',
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
        readingNotice ??= _copy(
          'تعذر تحميل توصيات المعلم الآن، لذلك ستبقى القراءة متاحة من دون هذه الطبقة مؤقتًا.',
          'Teacher recommendations could not be loaded right now, so reading stays available without that layer for now.',
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

  Future<bool> _deleteRecommendation(
    Ayat ayah,
    TeacherRecommendation recommendation,
  ) async {
    try {
      final response = await _teacherRecommendationsService
          .deleteRecommendation(recommendation.id);

      if (response.statusCode != 200 && response.statusCode != 204) {
        return false;
      }

      if (!mounted) {
        return true;
      }

      setState(() {
        ayah.teacherRecommendations.removeWhere(
          (item) => item.id == recommendation.id,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (Get.locale?.languageCode ?? 'ar') == 'ar'
                ? 'تم حذف التوصية.'
                : 'Recommendation deleted.',
          ),
        ),
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? 'تعذر حذف التوصية حالياً.'
                  : 'Unable to delete the recommendation right now.',
            ),
          ),
        );
      }
      return false;
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
      EvaluationsProvider evaluationsProvider =
          context.read<EvaluationsProvider>();

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
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 980),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDarkMode
                                  ? const [Color(0xFF1F2430), Color(0xFF18202C)]
                                  : const [Color(0xFFF6F0E6), Color(0xFFE8F1E6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF2C3442)
                                  : const Color(0xFFD9E1D5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _copy('القراءة أولًا', 'Reading first'),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? const Color(0xFFE8E6E1)
                                      : AppColors.buttonColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _copy(
                                  'سورة ${widget.surah.nameAr}',
                                  'Surah ${widget.surah.nameAr}',
                                ),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _entryPathBody(),
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.55,
                                  color: isDarkMode
                                      ? const Color(0xFFD2D5DB)
                                      : const Color(0xFF43504A),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ReadingMetaChip(
                                    label: _copy('مسار الدخول', 'Entry path'),
                                    value: _entryPathLabel(),
                                    isDarkMode: isDarkMode,
                                  ),
                                  _ReadingMetaChip(
                                    label: _copy('التقييم', 'Assessment'),
                                    value: _copy(
                                      'زر واضح بعد رقم الآية',
                                      'Explicit action after each verse marker',
                                    ),
                                    isDarkMode: isDarkMode,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _copy('طبقة المراجعة', 'Reading display layer'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _copy(
                                  'يمكنك إظهار ألوان الحفظ أو خط الفهم، لكن النص نفسه يبقى هو المركز. استخدم زر تقييم الآية عندما تريد المراجعة أو التعديل.',
                                  'You can show memorization colors or the comprehension underline, while keeping the text itself central. Use the verse action only when you want to review or edit.',
                                ),
                                style: TextStyle(
                                  height: 1.5,
                                  color: isDarkMode
                                      ? const Color(0xFFD2D5DB)
                                      : const Color(0xFF566173),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: Text(
                                      _copy(
                                        'إظهار ألوان الحفظ',
                                        'Show memorization colors',
                                      ),
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
                                      _copy(
                                        'إظهار خط الفهم',
                                        'Show comprehension underline',
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
                        ..._buildAyatWidgets(languageProvider,
                            evaluationProvider, _hasConnection, isDarkMode),

                        // ORIGINAL PAGINATION BUTTONS (UNCHANGED)
                        if (_currentHizbQuarter != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_currentHizbQuarter! >
                                    (_initialHizbQuarter ?? _minHizbQuarter!))
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentHizbQuarter =
                                            _currentHizbQuarter! - 1;
                                      });
                                      final userId = context
                                          .read<UsersProvider>()
                                          .selectedUser!
                                          .id;
                                      final evalProvider =
                                          context.read<EvaluationsProvider>();
                                      _loadAyat(userId, evalProvider);
                                    },
                                    child: const Icon(Icons.arrow_back_ios_new,
                                        size: 20),
                                  )
                                else
                                  const SizedBox(width: 48),
                                if (_currentHizbQuarter! < _maxHizbQuarter!)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentHizbQuarter =
                                            _currentHizbQuarter! + 1;
                                      });
                                      final userId = context
                                          .read<UsersProvider>()
                                          .selectedUser!
                                          .id;
                                      final evalProvider =
                                          context.read<EvaluationsProvider>();
                                      _loadAyat(userId, evalProvider);
                                    },
                                    child: const Icon(Icons.arrow_forward_ios,
                                        size: 20),
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                          )
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
              'سورة ${firstAyah.surah.nameAr}',
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
                final hasAnyAssessment =
                  ayah.userEvaluation?.hasAnyAssessment == true;

              return TextSpan(
                text: '${ayah.text} ',
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
                    style: TextStyle(
                      fontSize: 24,
                      height: 2,
                      color: color,
                      fontFamily: AppFonts.versesFont,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 6,
                        end: 6,
                      ),
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _AyahActionPill(
                            label: hasAnyAssessment
                                ? _copy('عدّل التقييم', 'Edit assessment')
                                : _copy('قيّم الآية', 'Assess verse'),
                            tooltip: hasConnection
                                ? _copy(
                                    'افتح تقييم الآية ${ayah.ayahNo}',
                                    'Open assessment for verse ${ayah.ayahNo}',
                                  )
                                : _copy(
                                    'التقييم يحتاج اتصالاً فعّالاً',
                                    'Assessment needs an active connection',
                                  ),
                            enabled: hasConnection && _canOpenAssessment,
                            emphasized: hasAnyAssessment,
                            onTap: () => _openAssessmentDialogForAyah(
                              ayah,
                              evaluationProvider,
                              languageProvider,
                            ),
                          ),
                          if (ayah.teacherRecommendations.isNotEmpty)
                            TeacherRecommendationBadge(
                              recommendations: ayah.teacherRecommendations,
                              compact: true,
                              onDelete: (recommendation) =>
                                  _deleteRecommendation(
                                ayah,
                                recommendation,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
        ),
      );
    }

    return widgets;
  }
}

class _ReadingMetaChip extends StatelessWidget {
  const _ReadingMetaChip({
    required this.label,
    required this.value,
    required this.isDarkMode,
  });

  final String label;
  final String value;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF202734) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2F3847) : const Color(0xFFDDE3DA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode
                  ? const Color(0xFFB9C0CB)
                  : const Color(0xFF61706B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
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
                color: isDarkMode ? const Color(0xFFF3E2C3) : const Color(0xFF7A5B18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahActionPill extends StatelessWidget {
  const _AyahActionPill({
    required this.label,
    required this.tooltip,
    required this.enabled,
    required this.emphasized,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool enabled;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = !enabled
        ? const Color(0xFFF1F3F5)
        : emphasized
            ? AppColors.buttonColor
            : Colors.white;
    final foregroundColor = !enabled
        ? const Color(0xFF89919B)
        : emphasized
            ? Colors.white
            : AppColors.buttonColor;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: emphasized
                      ? AppColors.buttonColor
                      : const Color(0xFFD6DCE2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    emphasized
                        ? Icons.edit_outlined
                        : Icons.add_comment_outlined,
                    size: 14,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
