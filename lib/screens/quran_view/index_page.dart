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
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import '../../controllers/general_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../core/utils/size_config.dart';
import '../../models/surah.dart';
import '../../providers/general_provider.dart';
import '../widgets/global_drawer.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/no_pop_scope.dart';

class IndexPage extends StatefulWidget {
  const IndexPage(
      {super.key,
      required this.surah,
      required this.filterTypeId,
      this.hizb,
      this.hizbQuarter,
      this.juz});

  final Surah surah;
  final int filterTypeId;
  final int? hizb;
  final int? hizbQuarter;
  final int? juz;

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with WidgetsBindingObserver {
  final gc = GeneralController();
  OverlayEntry? _menuEntry;
  final List<Ayat> _ayat = [];
  final Map<int, Color> _selectedColors = {};
  int? _currentHizbQuarter;
  int? _minHizbQuarter;
  int? _maxHizbQuarter;
  int? _initialHizbQuarter;
  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: true);
  bool _isInitialLoad = true;
  bool _hasConnection = true;
  bool _isConnectivityResolved = false;

  Color _onColor(Color bg) {
    final b = ThemeData.estimateBrightnessForColor(bg);
    return b == Brightness.dark ? Colors.white : Colors.black87;
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

  void _showOptionsAt(
      Offset globalPos,
      Ayat ayah,
      EvaluationsProvider evaluationsProvider,
      LanguageProvider languageProvider) {
    _removeMenu();

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final screen = overlayBox.size;

    const double menuWidth = 150;
    const double vGap = 8;

    double top = globalPos.dy + vGap;
    final approxMenuHeight =
        evaluationsProvider.evaluations.length * 44.0 + 12.0;
    if (top + approxMenuHeight > screen.height - 16) {
      top = globalPos.dy - approxMenuHeight - vGap;
    }

    final double right =
        (screen.width - globalPos.dx).clamp(0.0, screen.width - menuWidth);

    _menuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeMenu,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox(),
            ),
          ),
          Positioned(
            top: top,
            right: right,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 150, maxWidth: 150),
                  child: Column(
                    children: evaluationsProvider.evaluations.map((evaluation) {
                      final color = gc.getColorFromCategory(evaluation.id!);

                      return InkWell(
                        onTap: () async {
                          final savedScrollOffset = _scrollController.offset;
                          setState(() {
                            _selectedColors[ayah.id!] = color;
                          });

                          _removeMenu();
                          await EvaluationsController().sendEvaluation(
                              ayah, evaluation, evaluationsProvider, null);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(savedScrollOffset);
                            }
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          height: SizeConfig.getProportionalHeight(50),
                          color: color,
                          child: Center(
                            child: Text(
                              '${evaluation.name[languageProvider.langCode]}',
                              style: TextStyle(
                                  color: _onColor(color),
                                  fontFamily: AppFonts.versesFont),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_menuEntry!);
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
          _currentHizbQuarter =
              surahStart.clamp(_minHizbQuarter!, _maxHizbQuarter!);
        } else {
          _currentHizbQuarter = _minHizbQuarter;
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
          _currentHizbQuarter = _minHizbQuarter;
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

    List<int> ayatIds = ayat.map((ayah) => ayah.id!).toList();
    if (evaluationsProvider.evaluations.isEmpty) {
      await evaluationsProvider.getAllEvaluations();
    }
    await evaluationsProvider.getAllUserEvaluations(userId, ayatIds);

    setState(() {
      _ayat
        ..clear()
        ..addAll(ayat);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _removeMenu();
    WakelockPlus.disable();
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
      WakelockPlus.enable();
      int userId = context.read<UsersProvider>().selectedUser!.id;
      EvaluationsProvider evaluationsProvider =
          context.read<EvaluationsProvider>();
      _loadAyat(userId, evaluationsProvider);
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
                            onPressed: () => Get.off(const MainScreen()),
                          ),
                          actions: [
                            Builder(
                              builder: (context) => IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () {
                                  if ((Get.locale?.languageCode ?? 'ar') ==
                                      'ar') {
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
                              ..._buildAyatWidgets(
                                  languageProvider,
                                  evaluationProvider,
                                  _hasConnection,
                                  isDarkMode),

                              // ORIGINAL PAGINATION BUTTONS (UNCHANGED)
                              if (_currentHizbQuarter != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 20, bottom: 20),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (_currentHizbQuarter! >
                                          (_initialHizbQuarter ??
                                              _minHizbQuarter!))
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryPurple,
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
                                            final evalProvider = context
                                                .read<EvaluationsProvider>();
                                            _loadAyat(userId, evalProvider);
                                          },
                                          child: const Icon(
                                              Icons.arrow_back_ios_new,
                                              size: 20),
                                        )
                                      else
                                        const SizedBox(width: 48),
                                      if (_currentHizbQuarter! <
                                          _maxHizbQuarter!)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryPurple,
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
                                            final evalProvider = context
                                                .read<EvaluationsProvider>();
                                            _loadAyat(userId, evalProvider);
                                          },
                                          child: const Icon(
                                              Icons.arrow_forward_ios,
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
              final userEvaluation = evaluationProvider.userEvaluations
                  .firstWhereOrNull((e) => e.ayah!.id == ayah.id);

              final defaultColor =
                  isDarkMode ? Colors.white : AppColors.blackFontColor;

              Color color = hasConnection
                  ? _selectedColors[ayah.id!] ??
                      (userEvaluation?.evaluation != null
                          ? gc.getColorFromCategory(
                              userEvaluation!.evaluation!.id!)
                          : defaultColor)
                  : defaultColor;

              return TextSpan(
                text: '${ayah.text} ',
                style: TextStyle(
                  fontSize: 20,
                  height: 2,
                  color: color,
                  fontFamily: AppFonts.versesFont,
                ),
                recognizer: hasConnection
                    ? (TapGestureRecognizer()
                      ..onTapDown = (details) => _showOptionsAt(
                          details.globalPosition,
                          ayah,
                          evaluationProvider,
                          languageProvider))
                    : null,
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
