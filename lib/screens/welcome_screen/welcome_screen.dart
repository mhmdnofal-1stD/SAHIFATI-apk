import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/screens/questions_screen/questions_screen.dart';
import 'package:sahifaty/screens/widgets/assessment_dimension_toggle.dart';
import 'package:sahifaty/screens/widgets/no_pop_scope.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isChartLoading = false;
  bool _hasResolvedChartState = false;
  String? _chartErrorMessage;
  bool _isStartingAssessment = false;
  bool _isOpeningReadingBrowser = false;
  String? _kickoffErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChartData();
    });
  }

  Future<void> _loadChartData({String? dimension}) async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final user = usersProvider.selectedUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isChartLoading = false;
        _hasResolvedChartState = true;
        _chartErrorMessage = null;
      });
      return;
    }

    setState(() {
      _isChartLoading = true;
      _chartErrorMessage = null;
    });

    try {
      await evaluationsProvider.getQuranChartData(
        user.id,
        dimension: dimension ?? evaluationsProvider.chartDimension,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasResolvedChartState = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasResolvedChartState = true;
        _chartErrorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChartLoading = false;
        });
      }
    }
  }

  Future<void> _startAssessment() async {
    if (_isStartingAssessment || _isOpeningReadingBrowser) {
      return;
    }

    final usersProvider = context.read<UsersProvider>();
    final schoolProvider = context.read<SchoolProvider>();

    if (usersProvider.selectedUser == null) {
      setState(() {
        _kickoffErrorMessage = 'welcome_kickoff_error_missing_user'.tr;
      });
      return;
    }

    setState(() {
      _isStartingAssessment = true;
      _kickoffErrorMessage = null;
    });

    try {
      await schoolProvider.getQuickQuestionsSchool();
      await usersProvider.markOnboardingCompleted();

      if (!mounted) {
        return;
      }

      Get.to(const QuestionsScreen());
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _kickoffErrorMessage = message.isEmpty
            ? 'welcome_kickoff_generic_error'.tr
            : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingAssessment = false;
        });
      }
    }
  }

  Future<void> _openReadingBrowserNow() async {
    if (_isStartingAssessment || _isOpeningReadingBrowser) {
      return;
    }

    final usersProvider = context.read<UsersProvider>();
    if (usersProvider.selectedUser == null) {
      setState(() {
        _kickoffErrorMessage = 'welcome_kickoff_error_missing_user'.tr;
      });
      return;
    }

    setState(() {
      _isOpeningReadingBrowser = true;
      _kickoffErrorMessage = null;
    });

    try {
      await usersProvider.markOnboardingCompleted();

      if (!mounted) {
        return;
      }

      Get.offAllNamed(
        MainScreen.routeName,
        parameters: const {'comesFirst': 'true'},
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _kickoffErrorMessage = message.isEmpty
            ? 'welcome_kickoff_generic_error'.tr
            : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningReadingBrowser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();
    final user = usersProvider.selectedUser;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;
    final horizontalPadding = width >= 1200 ? 32.0 : 20.0;

    return NoPopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4ED),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF9F5EE), Color(0xFFF4F7FB)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -50,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x25132A4A), Color(0x00132A4A)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -110,
                  left: -40,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x1F0B503D), Color(0x000B503D)],
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WelcomeHero(userName: user?.username ?? user?.email),
                          const SizedBox(height: 24),
                          Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: isWide ? 6 : 0,
                                child: _WelcomeStoryCard(
                                  isBusy: _isStartingAssessment,
                                  isOpeningSahifa: _isOpeningReadingBrowser,
                                  errorMessage: _kickoffErrorMessage,
                                  onPrimaryPressed: _startAssessment,
                                  onSecondaryPressed: _openReadingBrowserNow,
                                ),
                              ),
                              SizedBox(
                                width: isWide ? 22 : 0,
                                height: isWide ? 0 : 22,
                              ),
                              Expanded(
                                flex: isWide ? 5 : 0,
                                child: _WelcomeMetricsCard(
                                  isChartLoading: _isChartLoading,
                                  hasResolvedChartState: _hasResolvedChartState,
                                  chartErrorMessage: _chartErrorMessage,
                                  onRetry: _loadChartData,
                                  onDimensionChanged: (dimension) {
                                    _loadChartData(dimension: dimension);
                                  },
                                ),
                              ),
                            ],
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
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final firstName = (userName == null || userName!.trim().isEmpty)
        ? null
        : userName!.trim().split(' ').first;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF132A4A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26132A4A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName == null
                ? 'welcome_back'.tr
                : '${'welcome_back'.tr} $firstName',
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .pageHeading
                .copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'welcome_kickoff_subtitle'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .bodyDefault
                .copyWith(color: Colors.white.withValues(alpha: 0.86)),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStoryCard extends StatelessWidget {
  const _WelcomeStoryCard({
    required this.isBusy,
    required this.isOpeningSahifa,
    required this.errorMessage,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final bool isBusy;
  final bool isOpeningSahifa;
  final String? errorMessage;
  final Future<void> Function() onPrimaryPressed;
  final Future<void> Function() onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final busy = isBusy || isOpeningSahifa;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE7DFD2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'welcome_msg'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: const Color(0xFF132A4A)),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ValueCard(
                titleKey: 'welcome_kickoff_value_1_title',
                bodyKey: 'welcome_kickoff_value_1_body',
                icon: Icons.timer_outlined,
                tint: Color(0xFFF4E6CC),
              ),
              _ValueCard(
                titleKey: 'welcome_kickoff_value_2_title',
                bodyKey: 'welcome_kickoff_value_2_body',
                icon: Icons.insights_outlined,
                tint: Color(0xFFDDEBFF),
              ),
              _ValueCard(
                titleKey: 'welcome_kickoff_value_3_title',
                bodyKey: 'welcome_kickoff_value_3_body',
                icon: Icons.route_outlined,
                tint: Color(0xFFDCEFE7),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _JourneyStep(
            titleKey: 'welcome_kickoff_step_1_title',
            bodyKey: 'welcome_kickoff_step_1_body',
          ),
          const SizedBox(height: 12),
          const _JourneyStep(
            titleKey: 'welcome_kickoff_step_2_title',
            bodyKey: 'welcome_kickoff_step_2_body',
          ),
          const SizedBox(height: 12),
          const _JourneyStep(
            titleKey: 'welcome_kickoff_step_3_title',
            bodyKey: 'welcome_kickoff_step_3_body',
          ),
          const SizedBox(height: 24),
          if (errorMessage != null) ...[
            _InlineFeedbackBanner(message: errorMessage!),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF132A4A),
                disabledBackgroundColor:
                    const Color(0xFF132A4A).withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text(
                isBusy
                    ? 'welcome_primary_cta_loading'.tr
                    : 'start_evaluation'.tr,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context)
                    .buttonPrimary
                    .copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'welcome_primary_cta_caption'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : onSecondaryPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Color(0x40132A4A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: isOpeningSahifa
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF132A4A),
                    ),
                  )
                : const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF132A4A),
                  ),
            label: Text(
              isOpeningSahifa
                  ? 'welcome_secondary_cta_loading'.tr
                  : 'welcome_secondary_cta'.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .buttonSecondary
                  .copyWith(color: const Color(0xFF132A4A)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'welcome_secondary_cta_caption'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _WelcomeMetricsCard extends StatelessWidget {
  const _WelcomeMetricsCard({
    required this.isChartLoading,
    required this.hasResolvedChartState,
    required this.chartErrorMessage,
    required this.onRetry,
    required this.onDimensionChanged,
  });

  final bool isChartLoading;
  final bool hasResolvedChartState;
  final String? chartErrorMessage;
  final Future<void> Function() onRetry;
  final ValueChanged<String> onDimensionChanged;

  @override
  Widget build(BuildContext context) {
    final evaluationsProvider = context.watch<EvaluationsProvider>();
    final entries = _meaningfulEntries(evaluationsProvider);
    final topEntry = _topSignal(entries);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9E2D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'welcome_chart_title'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: const Color(0xFF132A4A)),
          ),
          const SizedBox(height: 8),
          Text(
            'welcome_chart_subtitle'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .bodyDefault
                .copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          if (isChartLoading && !hasResolvedChartState)
            const _ChartStateCard(
              icon: Icons.hourglass_top_rounded,
              titleKey: 'welcome_chart_loading_title',
              bodyKey: 'welcome_chart_loading_body',
            )
          else if (chartErrorMessage != null)
            _ChartStateCard(
              icon: Icons.wifi_tethering_error_rounded,
              titleKey: 'welcome_chart_error_title',
              bodyKey: 'welcome_chart_error_body',
              actionLabel: 'welcome_chart_retry'.tr,
              onAction: onRetry,
              footerMessage: chartErrorMessage,
            )
          else if (entries.isEmpty)
            const _ChartStateCard(
              icon: Icons.insights_outlined,
              titleKey: 'welcome_chart_empty_title',
              bodyKey: 'welcome_chart_empty_body',
            )
          else ...[
            AssessmentDimensionToggle(
              selectedDimension: evaluationsProvider.chartDimension,
              onChanged: onDimensionChanged,
            ),
            const SizedBox(height: 10),
            Text(
              'welcome_dimension_hint'.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .bodySmall
                  .copyWith(color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 320,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    sections: _truthfulSections(context, entries),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ChartLegend(entries: entries),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8E0D4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'welcome_chart_top_label'.tr,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.of(context)
                        .badgeLabel
                        .copyWith(color: const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    topEntry == null ? '-' : _localizedName(topEntry),
                    textDirection: TextDirection.rtl,
                    style: AppTypography.of(context)
                        .sectionTitle
                        .copyWith(color: const Color(0xFF132A4A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'welcome_chart_total_count'.trParams({
                      'count': evaluationsProvider.totalCount.toString(),
                    }),
                    textDirection: TextDirection.rtl,
                    style: AppTypography.of(context)
                        .bodySecondary
                        .copyWith(color: const Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<ChartEvaluationData> _meaningfulEntries(EvaluationsProvider provider) {
    return provider.chartEvaluationData.where((entry) {
      final percentage = entry.percentage?.toDouble() ?? 0;
      final verseCount = entry.verseCount ?? 0;
      final characterCount = entry.characterCount ?? 0;
      return percentage > 0 || verseCount > 0 || characterCount > 0;
    }).toList();
  }

  List<PieChartSectionData> _truthfulSections(
      BuildContext context, List<ChartEvaluationData> entries) {
    final controller = EvaluationsController();
    // Slices below this percentage are too narrow to fit a label inside,
    // so we draw an external callout (leader arrow + text) instead.
    const double inlineLabelThreshold = 8;
    return entries.map((entry) {
      final percentage = entry.percentage?.toDouble() ?? 0;
      final color = controller.getColorForChartEntry(entry);
      final fitsInside = percentage >= inlineLabelThreshold;
      return PieChartSectionData(
        color: color,
        value: percentage,
        radius: 96,
        title: fitsInside ? '${percentage.toStringAsFixed(0)}%' : '',
        titleStyle: AppTypography.of(context)
            .chartTooltip
            .copyWith(color: Colors.white),
        badgeWidget:
            fitsInside ? null : _ExternalSliceLabel(color: color, percentage: percentage),
        badgePositionPercentageOffset: 1.45,
      );
    }).toList();
  }

  ChartEvaluationData? _topSignal(List<ChartEvaluationData> entries) {
    if (entries.isEmpty) {
      return null;
    }

    final sorted = [...entries]
      ..sort((a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0));
    return sorted.first;
  }

  String _localizedName(ChartEvaluationData entry) {
    final langCode = Get.locale?.languageCode ?? 'ar';
    return entry.name[langCode] ?? entry.name['ar'] ?? entry.name['en'] ?? '';
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
    required this.tint,
  });

  final String titleKey;
  final String bodyKey;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF132A4A)),
            const SizedBox(height: 14),
            Text(
              titleKey.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .listTileTitle
                  .copyWith(color: const Color(0xFF132A4A)),
            ),
            const SizedBox(height: 8),
            Text(
              bodyKey.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .bodySecondary
                  .copyWith(color: const Color(0xFF304256)),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.titleKey,
    required this.bodyKey,
  });

  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE3D6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF132A4A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleKey.tr,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .listTileTitle
                      .copyWith(color: const Color(0xFF132A4A)),
                ),
                const SizedBox(height: 6),
                Text(
                  bodyKey.tr,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .bodySecondary
                      .copyWith(color: const Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.entries});

  final List<ChartEvaluationData> entries;

  String _localizedName(ChartEvaluationData entry) {
    final langCode = Get.locale?.languageCode ?? 'ar';
    return entry.name[langCode] ?? entry.name['ar'] ?? entry.name['en'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final controller = EvaluationsController();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: controller.getColorForChartEntry(entry),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _localizedName(entry),
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .chartAxisLabel
                  .copyWith(color: const Color(0xFF132A4A)),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ExternalSliceLabel extends StatelessWidget {
  const _ExternalSliceLabel({required this.color, required this.percentage});

  final Color color;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 2,
          color: color,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            textDirection: TextDirection.ltr,
            style: AppTypography.of(context)
                .badgeCount
                .copyWith(color: color, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ChartStateCard extends StatelessWidget {
  const _ChartStateCard({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    this.actionLabel,
    this.onAction,
    this.footerMessage,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final String? footerMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DFD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: const Color(0xFF132A4A), size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            titleKey.tr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: const Color(0xFF132A4A)),
          ),
          const SizedBox(height: 8),
          Text(
            bodyKey.tr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .bodyDefault
                .copyWith(color: const Color(0xFF6B7280)),
          ),
          if (footerMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              footerMessage!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: AppTypography.of(context)
                  .bodySecondary
                  .copyWith(color: AppColors.errorColor),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0x26132A4A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionLabel!,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context)
                    .buttonSecondary
                    .copyWith(color: const Color(0xFF132A4A)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineFeedbackBanner extends StatelessWidget {
  const _InlineFeedbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .inputError
                  .copyWith(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
