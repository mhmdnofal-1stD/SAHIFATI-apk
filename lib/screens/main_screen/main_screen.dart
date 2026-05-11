import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/screens/quran_view/index_page.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../../services/evaluations_services.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/chart_filter_panel.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/info_icon_button.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/notifications_bell_button.dart';
import '../widgets/responsive_content_shell.dart';
import '../widgets/surah_picker_dialog.dart';
import '../../widgets/app_progress_overlay.dart';

class MainScreen extends StatefulWidget {
  static const String routeName = '/browse';

  const MainScreen({
    super.key,
    this.comesFirst = false,
    this.initialChartFilters = const QuranChartFilters(),
  });

  final bool comesFirst;
  final QuranChartFilters initialChartFilters;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isChartBootstrapInFlight = false;
  int? _chartBootstrapUserId;

  void _debugChartBootstrap(
    String event, {
    int? selectedUserId,
    EvaluationsProvider? evaluationsProvider,
  }) {
    if (!kDebugMode) {
      return;
    }

    final buffer = StringBuffer('[chart-bootstrap] $event');
    if (selectedUserId != null) {
      buffer.write(' user=$selectedUserId');
    }
    if (evaluationsProvider != null) {
      buffer.write(' loading=${evaluationsProvider.isLoading}');
      buffer.write(' entries=${evaluationsProvider.chartEvaluationData.length}');
      buffer.write(' hasError=${(evaluationsProvider.chartLoadError ?? '').isNotEmpty}');
    }
    debugPrint(buffer.toString());
  }

  bool _hasInAppBackTarget(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    if (canPop) {
      return true;
    }

    final previousRoute = Get.previousRoute;
    return previousRoute.isNotEmpty &&
        previousRoute != '/' &&
        previousRoute != MainScreen.routeName &&
        previousRoute != Get.currentRoute;
  }

  Future<void> _resumeReading(BuildContext context, int? userId) async {
    final session = await ReadingSessionStore().loadForUser(userId);
    if (!context.mounted) return;

    if (session != null) {
      await ReadingSessionStore().updateAutoResumeForUser(userId, false);
      if (!context.mounted) return;
      Get.toNamed(
        IndexPage.routeName,
        parameters: IndexPage.routeParametersForSession(session),
      );
      return;
    }

    // No saved session yet — fall back to opening Surah Al-Fatiha so the
    // button never feels broken on a fresh account.
    _openSurah(1);
  }

  Future<void> _pickSurah(BuildContext context) async {
    final surahId = await SurahPickerDialog.show(context);
    if (surahId == null) return;
    _openSurah(surahId);
  }

  void _openSurah(int surahId) {
    Get.toNamed(
      IndexPage.routeName,
      parameters: IndexPage.routeParameters(
        surah: Surah(
          id: surahId,
          nameAr: quran.getSurahNameArabic(surahId),
          ayahCount: quran.getVerseCount(surahId),
        ),
        filterTypeId: FilterTypes.thirds,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (widget.comesFirst) {
        final evaluationsProvider = context.read<EvaluationsProvider>();
        unawaited(
          AppProgressOverlay.showUntilDone(
            evaluationsProvider.getAllEvaluations(),
            message: 'جاري تحميل بيانات التقييمات...',
          ),
        );
      }

      _bootstrapChartDataIfNeeded();
    });
  }

  bool _needsChartBootstrap(
    EvaluationsProvider evaluationsProvider,
    int? selectedUserId,
  ) {
    if (!mounted || selectedUserId == null || _isChartBootstrapInFlight) {
      return false;
    }

    final sameUser = _chartBootstrapUserId == selectedUserId;
    if (!sameUser) {
      return true;
    }

    return evaluationsProvider.chartEvaluationData.isEmpty &&
        evaluationsProvider.chartLoadError == null &&
        !evaluationsProvider.isLoading;
  }

  Future<void> _bootstrapChartDataIfNeeded() async {
    if (!mounted || _isChartBootstrapInFlight) {
      return;
    }

    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final selectedUserId = usersProvider.selectedUser?.id;

    if (selectedUserId == null) {
      _debugChartBootstrap('skip:no-user');
      return;
    }

    if (!_needsChartBootstrap(evaluationsProvider, selectedUserId)) {
      _debugChartBootstrap(
        'skip:not-needed',
        selectedUserId: selectedUserId,
        evaluationsProvider: evaluationsProvider,
      );
      return;
    }

    _isChartBootstrapInFlight = true;
    _chartBootstrapUserId = selectedUserId;
    AppProgressOverlay.show('جاري تحميل بيانات القرآن...', progress: 0.2);
    _debugChartBootstrap(
      'request:start',
      selectedUserId: selectedUserId,
      evaluationsProvider: evaluationsProvider,
    );

    try {
      AppProgressOverlay.updateStep('جاري حساب بيانات الخريطة...', progress: 0.6);
      await evaluationsProvider.getQuranChartData(
        selectedUserId,
        filters: widget.initialChartFilters,
      );
    } catch (_) {
      // The chart widget already shows its own error state if needed.
    } finally {
      AppProgressOverlay.hide();
      _isChartBootstrapInFlight = false;
      _debugChartBootstrap(
        'request:end',
        selectedUserId: selectedUserId,
        evaluationsProvider: evaluationsProvider,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final showBackButton = _hasInAppBackTarget(context);
    final selectedUserId = usersProvider.selectedUser?.id;

    if (_needsChartBootstrap(evaluationsProvider, selectedUserId)) {
      _debugChartBootstrap(
        'schedule:post-frame',
        selectedUserId: selectedUserId,
        evaluationsProvider: evaluationsProvider,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bootstrapChartDataIfNeeded();
      });
    }

    return NoPopScope(
      child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: AppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: AppColors.backgroundColor,
                    leading: showBackButton ? const CustomBackButton() : null,
                    actions: [
                      const NotificationsBellButton(),
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
              body: ResponsiveContentShell(
                builder: (context) => LayoutBuilder(
                  builder: (context, shellConstraints) {
                    final topRowMaxWidth = shellConstraints.maxWidth >= 920
                        ? 920.0
                        : shellConstraints.maxWidth;
                    final compactTopRow = topRowMaxWidth < 620;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: topRowMaxWidth),
                            child: Flex(
                              direction:
                                  compactTopRow ? Axis.vertical : Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compactTopRow ? 14 : 18,
                                    vertical: compactTopRow ? 12 : 14,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF5F2EA),
                                        Color(0xFFE9F0E7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFFDCE2DA),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      InfoIconButton(
                                        message:
                                            'main_screen_chart_intro_first'.tr,
                                        color: const Color(0xFF7B8794),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${"well_done".tr} ${usersProvider.selectedUser?.username ?? usersProvider.selectedUser?.email ?? ''}',
                                          textAlign: TextAlign.right,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.of(context)
                                              .pageHeading
                                              .copyWith(
                                                fontSize: compactTopRow ? 24 : 28,
                                                height: 1.0,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedUserId != null) ...[
                                  SizedBox(
                                    width: compactTopRow ? 0 : 12,
                                    height: compactTopRow ? 10 : 0,
                                  ),
                                  if (compactTopRow)
                                    ChartFilterPanel(
                                      userId: selectedUserId,
                                      margin: EdgeInsets.zero,
                                    )
                                  else
                                    Expanded(
                                      child: ChartFilterPanel(
                                        userId: selectedUserId,
                                        margin: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: BarChartWidget(
                              evaluationsProvider: evaluationsProvider,
                              languageProvider: languageProvider,
                              includeUncategorized: false,
                            ),
                          ),
                          SizedBox(
                            height: SizeConfig.getProportionalHeight(20),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 520;
                                final resumeBtn = FilledButton.icon(
                                  onPressed: () =>
                                      _resumeReading(context, selectedUserId),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.buttonColor,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(
                                    'main_screen_resume_action'.tr,
                                    style:
                                        AppTypography.of(context).buttonPrimary,
                                  ),
                                );
                                final pickBtn = OutlinedButton.icon(
                                  onPressed: () => _pickSurah(context),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.buttonColor,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.menu_book_outlined,
                                    color: AppColors.buttonColor,
                                  ),
                                  label: Text(
                                    'main_screen_pick_surah'.tr,
                                    style: AppTypography.of(context)
                                        .buttonSecondary
                                        .copyWith(
                                          color: AppColors.buttonColor,
                                        ),
                                  ),
                                );
                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(child: resumeBtn),
                                      const SizedBox(width: 12),
                                      Expanded(child: pickBtn),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    resumeBtn,
                                    const SizedBox(height: 10),
                                    pickBtn,
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
  }
}
