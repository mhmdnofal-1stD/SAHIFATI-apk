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
import '../../providers/general_provider.dart';
import '../../providers/surahs_provider.dart';
import '../../providers/users_provider.dart';
import '../../services/evaluations_services.dart';
import '../widgets/assessment_dimension_toggle.dart';
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
    this.autoBootstrapChart = true,
    this.useResponsiveShell = true,
    this.useScaffoldFrame = true,
    this.initialChartFilters = const QuranChartFilters(),
  });

  final bool comesFirst;
  final bool autoBootstrapChart;
  final bool useResponsiveShell;
  final bool useScaffoldFrame;
  final QuranChartFilters initialChartFilters;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isChartBootstrapInFlight = false;
  bool _chartBootstrapScheduled = false;
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
      buffer
          .write(' entries=${evaluationsProvider.chartEvaluationData.length}');
      buffer.write(
          ' hasError=${(evaluationsProvider.chartLoadError ?? '').isNotEmpty}');
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
        // Load evaluations in the background — the chart and filter panels
        // handle their own loading states, so there is no need to block the
        // main screen with a full-screen overlay on every startup.
        unawaited(context.read<EvaluationsProvider>().getAllEvaluations());
      }

      if (widget.autoBootstrapChart) {
        _bootstrapChartDataIfNeeded();
      }
    });
  }

  bool _needsChartBootstrap(
    EvaluationsProvider evaluationsProvider,
    int? selectedUserId,
  ) {
    if (!widget.autoBootstrapChart ||
        !mounted ||
        selectedUserId == null ||
        _isChartBootstrapInFlight) {
      return false;
    }

    final sameUser = _chartBootstrapUserId == selectedUserId;
    if (evaluationsProvider.chartEvaluationData.isNotEmpty) {
      return false;
    }

    if (!sameUser) {
      return true;
    }

    return evaluationsProvider.chartEvaluationData.isEmpty &&
        evaluationsProvider.chartLoadError == null &&
        !evaluationsProvider.isLoading;
  }

  Future<void> _bootstrapChartDataIfNeeded() async {
    _chartBootstrapScheduled = false;

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
    // The chart widget renders _BrowseLoadingPlaceholder while
    // _isChartBootstrapInFlight is true via showLoadingState — no
    // full-screen overlay needed here.
    _debugChartBootstrap(
      'request:start',
      selectedUserId: selectedUserId,
      evaluationsProvider: evaluationsProvider,
    );

    try {
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
    final generalProvider = Provider.of<GeneralProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final surahsProvider = Provider.of<SurahsProvider>(context);
    final showBackButton = _hasInAppBackTarget(context);
    final selectedUserId = usersProvider.selectedUser?.id;
    final hasChartData = evaluationsProvider.chartEvaluationData.isNotEmpty;
    final showLoadingState = widget.comesFirst &&
        !hasChartData &&
        (evaluationsProvider.isLoading ||
            _isChartBootstrapInFlight ||
            selectedUserId == null ||
            evaluationsProvider.chartEvaluationData.isEmpty);

    if (_needsChartBootstrap(evaluationsProvider, selectedUserId) &&
        !_chartBootstrapScheduled) {
      _chartBootstrapScheduled = true;
      _debugChartBootstrap(
        'schedule:post-frame',
        selectedUserId: selectedUserId,
        evaluationsProvider: evaluationsProvider,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bootstrapChartDataIfNeeded();
      });
    }

    final mainBodyContent = Builder(
      builder: (context) {
        final shellWidth = MediaQuery.sizeOf(context).width;
        final availableContentWidth =
            (shellWidth - 32).clamp(0.0, double.infinity);
        final topRowMaxWidth =
            availableContentWidth >= 920 ? 920.0 : availableContentWidth;
        final compactTopRow = topRowMaxWidth < 620;
        final useWideActions =
            (availableContentWidth >= 920 ? 920.0 : availableContentWidth) >=
                520;
        final summaryMode = widget.comesFirst ||
            (!widget.useScaffoldFrame &&
                generalProvider.mainScreenView == FilterTypes.thirds);
        final activeChartEntries = evaluationsProvider.chartEvaluationData
            .where((entry) =>
                entry.evaluationId != 0 && (entry.verseCount ?? 0) > 0)
            .toList()
          ..sort(
            (a, b) => (b.verseCount ?? 0).compareTo(a.verseCount ?? 0),
          );
        final topSignal =
            activeChartEntries.isEmpty ? null : activeChartEntries.first;
        final categorizedVerseCount = activeChartEntries.fold<int>(
          0,
          (sum, entry) => sum + ((entry.verseCount ?? 0).round()),
        );
        final remainingVerseCount =
            evaluationsProvider.totalCount > categorizedVerseCount
                ? evaluationsProvider.totalCount - categorizedVerseCount
                : 0;

        String filterTypeLabel(int? filterTypeId) {
          switch (filterTypeId) {
            case FilterTypes.parts:
              return 'parts_icons'.tr;
            case FilterTypes.hizbs:
              return 'hizbs_icons'.tr;
            case FilterTypes.subjects:
              return 'subjects'.tr;
            case FilterTypes.thirds:
            default:
              return 'thirds_icons'.tr;
          }
        }

        String activeViewLabel() {
          return filterTypeLabel(generalProvider.mainScreenView);
        }

        Widget centeredSection(Widget child, {double maxWidth = 920}) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          );
        }

        Widget infoCard({
          required String title,
          String? body,
          Widget? trailing,
          Widget? child,
        }) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDCE2DA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.of(context).subsectionTitle,
                ),
                if (body != null && body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: AppTypography.of(context).bodyDefault,
                  ),
                ],
                if (child != null) ...[
                  const SizedBox(height: 12),
                  child,
                ],
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing,
                  ),
                ],
              ],
            ),
          );
        }

        Widget eyebrow(String text) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3EA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD3DECF)),
            ),
            child: Text(
              text,
              style: AppTypography.of(context).badgeCount,
            ),
          );
        }

        Widget resumeCard({required bool summaryStyle}) {
          if (selectedUserId == null) {
            return const SizedBox.shrink();
          }

          return FutureBuilder<ReadingSession?>(
            future: ReadingSessionStore().loadForUser(selectedUserId),
            builder: (context, snapshot) {
              final session = snapshot.data;
              if (session == null) {
                return const SizedBox.shrink();
              }

              final titleKey = summaryStyle
                  ? 'sahifa_screen_resume_title'
                  : 'main_screen_resume_title';
              final bodyKey = summaryStyle
                  ? 'sahifa_screen_resume_body'
                  : 'main_screen_resume_body';
              return centeredSection(
                infoCard(
                  title: titleKey.tr,
                  body: bodyKey.trParams({
                    'surah': session.surah.nameAr,
                    'path': filterTypeLabel(session.filterTypeId),
                  }),
                ),
              );
            },
          );
        }

        final resumeBtn = FilledButton.icon(
          onPressed: () => _resumeReading(context, selectedUserId),
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
            style: AppTypography.of(context).buttonPrimary,
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
            (summaryMode ? 'browse_verses' : 'main_screen_pick_surah').tr,
            style: AppTypography.of(context)
                .buttonSecondary
                .copyWith(color: AppColors.buttonColor),
          ),
        );

        final introCard = Container(
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
            border: Border.all(color: const Color(0xFFDCE2DA)),
          ),
          child: Row(
            children: [
              summaryMode
                  ? const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF7B8794),
                      size: 20,
                    )
                  : InfoIconButton(
                      message: 'main_screen_chart_intro_first'.tr,
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
                  style: AppTypography.of(context).pageHeading.copyWith(
                        fontSize: compactTopRow ? 24 : 28,
                        height: 1.0,
                      ),
                ),
              ),
            ],
          ),
        );

        final filterPanel = selectedUserId == null
            ? null
            : ChartFilterPanel(
                userId: selectedUserId,
                margin: EdgeInsets.zero,
              );

        return ScrollConfiguration(
          behavior: const _MainScreenScrollBehavior(),
          child: CustomScrollView(
            primary: false,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      centeredSection(
                        summaryMode
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: eyebrow(
                                      (widget.comesFirst
                                              ? 'sahifa_screen_header_badge_first'
                                              : 'sahifa_screen_header_badge_returning')
                                          .tr,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  infoCard(
                                    title: 'main_screen_gateway_badge'.tr,
                                    body: 'sahifa_screen_header_body'.tr,
                                  ),
                                ],
                              )
                            : infoCard(
                                title: 'main_screen_gateway_badge'.tr,
                                body: activeViewLabel(),
                              ),
                      ),
                      resumeCard(summaryStyle: summaryMode),
                      if (summaryMode && activeChartEntries.isNotEmpty)
                        centeredSection(
                          infoCard(
                            title: 'sahifa_screen_summary_title'.tr,
                            body: evaluationsProvider.chartDimension ==
                                    'comprehension'
                                ? 'sahifa_screen_comprehension_summary'
                                    .trParams({
                                    'evaluated':
                                        categorizedVerseCount.toString(),
                                    'remaining': remainingVerseCount.toString(),
                                  })
                                : 'sahifa_screen_memorization_summary'
                                    .trParams({
                                    'evaluated':
                                        categorizedVerseCount.toString(),
                                    'remaining': remainingVerseCount.toString(),
                                  }),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AssessmentDimensionToggle(
                                  selectedDimension:
                                      evaluationsProvider.chartDimension,
                                  onChanged: selectedUserId == null
                                      ? (_) {}
                                      : (dimension) {
                                          unawaited(
                                            evaluationsProvider
                                                .getQuranChartData(
                                              selectedUserId,
                                              dimension: dimension,
                                              filters: evaluationsProvider
                                                  .chartFilters,
                                            ),
                                          );
                                        },
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'sahifa_screen_metric_remaining'.tr,
                                  style:
                                      AppTypography.of(context).subsectionTitle,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  remainingVerseCount.toString(),
                                  style: AppTypography.of(context).bodyDefault,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'sahifa_screen_top_signal_title'.tr,
                                  style:
                                      AppTypography.of(context).subsectionTitle,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'sahifa_screen_top_signal_body'.trParams({
                                    'name': topSignal!
                                            .name[languageProvider.langCode] ??
                                        '',
                                    'count':
                                        (topSignal.verseCount ?? 0).toString(),
                                  }),
                                  style: AppTypography.of(context).bodyDefault,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (summaryMode)
                        centeredSection(
                          infoCard(
                            title: 'sahifa_screen_empty_title'.tr,
                            body: 'sahifa_screen_empty_body'.tr,
                          ),
                        ),
                      if (!summaryMode &&
                          generalProvider.mainScreenView == FilterTypes.hizbs &&
                          (surahsProvider.hizbLoadError?.trim().isNotEmpty ??
                              false))
                        centeredSection(
                          infoCard(
                            title: 'main_screen_hizb_error_title'.tr,
                            body: surahsProvider.hizbLoadError,
                            trailing: OutlinedButton(
                              onPressed: () {},
                              child: Text('welcome_chart_retry'.tr),
                            ),
                          ),
                        ),
                      centeredSection(
                        (compactTopRow || summaryMode)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  introCard,
                                  if (filterPanel != null) ...[
                                    const SizedBox(height: 10),
                                    filterPanel,
                                  ],
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: introCard),
                                  if (filterPanel != null) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: filterPanel,
                                    ),
                                  ],
                                ],
                              ),
                        maxWidth: topRowMaxWidth,
                      ),
                      centeredSection(
                        BarChartWidget(
                          evaluationsProvider: evaluationsProvider,
                          languageProvider: languageProvider,
                          includeUncategorized: false,
                        ),
                      ),
                      SizedBox(height: SizeConfig.getProportionalHeight(20)),
                      centeredSection(
                        useWideActions
                            ? Row(
                                children: [
                                  Expanded(child: resumeBtn),
                                  const SizedBox(width: 12),
                                  Expanded(child: pickBtn),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  resumeBtn,
                                  const SizedBox(height: 10),
                                  pickBtn,
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    final screenBody = showLoadingState
        ? const _BrowseLoadingPlaceholder()
        : widget.useResponsiveShell
            ? ResponsiveContentShell(child: mainBodyContent)
            : mainBodyContent;

    if (!widget.useScaffoldFrame) {
      return screenBody;
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
        body: screenBody,
      ),
    );
  }
}

class _MainScreenScrollBehavior extends MaterialScrollBehavior {
  const _MainScreenScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _BrowseLoadingPlaceholder extends StatelessWidget {
  const _BrowseLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundColor,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.buttonColor,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'جاري تجهيز الصفحة...',
              textAlign: TextAlign.center,
              style: AppTypography.of(context).sectionTitle.copyWith(
                    color: AppColors.blackFontColor,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'إذا كان التحميل من الشبكة مستمرًا فسيظهر شريط التقدم تلقائيًا.',
              textAlign: TextAlign.center,
              style: AppTypography.of(context).emptyStateBody,
            ),
          ],
        ),
      ),
    );
  }
}
