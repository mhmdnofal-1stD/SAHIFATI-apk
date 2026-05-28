import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/utils/localized_value.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/screens/questions_screen/questions_screen.dart';
import 'package:sahifaty/screens/widgets/assessment_dimension_toggle.dart';
import 'package:sahifaty/screens/widgets/info_icon_button.dart';
import 'package:sahifaty/screens/widgets/no_pop_scope.dart';

class WelcomeScreen extends StatefulWidget {
  static const String routeName = '/welcome';

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

  Future<void> _startQuickAssessment() async {
    final usersProvider = context.read<UsersProvider>();
    if (usersProvider.selectedUser == null) {
      setState(() {
        _kickoffErrorMessage = 'welcome_kickoff_error_missing_user'.tr;
      });
      return;
    }

    try {
      await usersProvider.markOnboardingCompleted();

      if (!mounted) {
        return;
      }

      Get.toNamed('/quick-assessment');
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();
    final user = usersProvider.selectedUser;
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final isWide = width >= 980;
    final compactViewport = height <= 900;
    final horizontalPadding = width >= 1200 ? 28.0 : 16.0;

    return NoPopScope(
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFCFDF8), Color(0xFFF4F8EB)],
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
                        colors: [Color(0x33EDF3D7), Color(0x00EDF3D7)],
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
                        colors: [Color(0x1F2F7B64), Color(0x002F7B64)],
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    compactViewport ? 14 : 20,
                    horizontalPadding,
                    compactViewport ? 18 : 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WelcomeHero(userName: user?.username ?? user?.email),
                          SizedBox(height: compactViewport ? 16 : 22),
                          Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: isWide ? 6 : 0,
                                child: _WelcomeStoryCard(
                                  compactViewport: compactViewport,
                                  isBusy: _isStartingAssessment,
                                  isOpeningSahifa: _isOpeningReadingBrowser,
                                  errorMessage: _kickoffErrorMessage,
                                  onPrimaryPressed: _startAssessment,
                                  onSecondaryPressed: _openReadingBrowserNow,
                                  onQuickAssessmentPressed: _startQuickAssessment,
                                ),
                              ),
                              SizedBox(
                                width: isWide ? 16 : 0,
                                height: isWide ? 0 : 16,
                              ),
                              Expanded(
                                flex: isWide ? 5 : 0,
                                child: _WelcomeMetricsCard(
                                  compactViewport: compactViewport,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryPurple, AppColors.brandAccent],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x26EDF3D7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261D6652),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WelcomeBrandHeader(),
          const SizedBox(height: 14),
          _TitleInfoRow(
            title: firstName == null
                ? 'welcome_back'.tr
                : '${'welcome_back'.tr} $firstName',
            message: 'welcome_kickoff_subtitle'.tr,
            titleStyle: AppTypography.of(context)
                .pageHeading
                .copyWith(color: Colors.white),
            infoColor: const Color(0xFFEDF3D7),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBrandHeader extends StatelessWidget {
  const _WelcomeBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(Assets.logoLightSvg),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'صحيفتي',
                style: AppTypography.of(context).pageHeading.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.0,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'بداية قرآنية دقيقة وهوية بصرية واحدة من الدخول حتى التقييم.',
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context).bodySmall.copyWith(
                      color: const Color(0xFFEDF3D7),
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeStoryCard extends StatelessWidget {
  const _WelcomeStoryCard({
    required this.compactViewport,
    required this.isBusy,
    required this.isOpeningSahifa,
    required this.errorMessage,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    required this.onQuickAssessmentPressed,
  });

  final bool compactViewport;
  final bool isBusy;
  final bool isOpeningSahifa;
  final String? errorMessage;
  final Future<void> Function() onPrimaryPressed;
  final Future<void> Function() onSecondaryPressed;
  final Future<void> Function() onQuickAssessmentPressed;

  @override
  Widget build(BuildContext context) {
    final busy = isBusy || isOpeningSahifa;

    return Container(
      padding: EdgeInsets.all(compactViewport ? 18 : 22),
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.lineColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121D6652),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 144,
                  child: _ValueCard(
                    titleKey: 'welcome_kickoff_value_1_title',
                    bodyKey: 'welcome_kickoff_value_1_body',
                    icon: Icons.timer_outlined,
                    tint: AppColors.warmSurface,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 144,
                  child: _ValueCard(
                    titleKey: 'welcome_kickoff_value_2_title',
                    bodyKey: 'welcome_kickoff_value_2_body',
                    icon: Icons.insights_outlined,
                    tint: Color(0xFFF2F7E7),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 144,
                  child: _ValueCard(
                    titleKey: 'welcome_kickoff_value_3_title',
                    bodyKey: 'welcome_kickoff_value_3_body',
                    icon: Icons.route_outlined,
                    tint: AppColors.mintSurface,
                  ),
                ),
              ],
            ),
            ),
          SizedBox(height: compactViewport ? 18 : 22),
          if (errorMessage != null) ...[
            _InlineFeedbackBanner(message: errorMessage!),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: compactViewport ? 48 : 52,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : onPrimaryPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          disabledBackgroundColor:
                              AppColors.primaryPurple.withValues(alpha: 0.45),
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
                          textDirection: (Get.locale?.languageCode ?? 'ar') == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                          style: AppTypography.of(context)
                              .buttonPrimary
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InfoIconButton(
                        message: 'welcome_primary_cta_caption'.tr,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: compactViewport ? 48 : 52,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onSecondaryPressed,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(compactViewport ? 46 : 50),
                          side: const BorderSide(color: AppColors.lineColor),
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
                                  color: AppColors.primaryPurple,
                                ),
                              )
                            : const Icon(
                                Icons.menu_book_rounded,
                                color: AppColors.primaryPurple,
                              ),
                        label: Text(
                          isOpeningSahifa
                              ? 'welcome_secondary_cta_loading'.tr
                            : 'welcome_secondary_cta'.tr,
                          textDirection: (Get.locale?.languageCode ?? 'ar') == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                          style: AppTypography.of(context)
                              .buttonSecondary
                              .copyWith(color: AppColors.primaryPurple),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InfoIconButton(
                        message: 'welcome_secondary_cta_caption'.tr,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick Assessment Button
          SizedBox(
            width: double.infinity,
            height: compactViewport ? 48 : 52,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onQuickAssessmentPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.lineColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.quiz_outlined,
                color: AppColors.primaryPurple,
              ),
              label: Text(
                'تقييم سريع',
                textDirection: (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
                style: AppTypography.of(context)
                    .buttonSecondary
                    .copyWith(color: AppColors.primaryPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeMetricsCard extends StatelessWidget {
  const _WelcomeMetricsCard({
    required this.compactViewport,
    required this.isChartLoading,
    required this.hasResolvedChartState,
    required this.chartErrorMessage,
    required this.onRetry,
    required this.onDimensionChanged,
  });

  final bool compactViewport;
  final bool isChartLoading;
  final bool hasResolvedChartState;
  final String? chartErrorMessage;
  final Future<void> Function() onRetry;
  final ValueChanged<String> onDimensionChanged;

  @override
  Widget build(BuildContext context) {
    final evaluationsProvider = context.watch<EvaluationsProvider>();
    final entries = _meaningfulEntries(evaluationsProvider);

    return Container(
      padding: EdgeInsets.all(compactViewport ? 18 : 22),
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.lineColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1D6652),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AssessmentDimensionToggle(
                    selectedDimension: evaluationsProvider.chartDimension,
                    onChanged: onDimensionChanged,
                  ),
                ),
                InfoIconButton(
                  message: 'welcome_dimension_hint'.tr,
                  color: AppColors.mutedText,
                ),
              ],
            ),
            SizedBox(height: compactViewport ? 10 : 12),
            Text(
              'welcome_chart_top_label'.tr,
              textDirection: (Get.locale?.languageCode ?? 'ar') == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: AppTypography.of(context)
                  .sectionTitle
                  .copyWith(color: AppColors.primaryPurple),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: compactViewport ? 240 : 280,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compactViewport ? 8 : 16),
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: compactViewport ? 34 : 42,
                    sections: _truthfulSections(context, entries),
                  ),
                ),
              ),
            ),
            SizedBox(height: compactViewport ? 8 : 10),
            _ChartLegend(entries: entries),
            SizedBox(height: compactViewport ? 8 : 10),
            Text(
              'welcome_chart_total_count'.trParams({
                'count': evaluationsProvider.totalCount.toString(),
              }),
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .bodySecondary
                  .copyWith(color: AppColors.mutedText),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.lineColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryPurple, size: 20),
              const Spacer(),
              InfoIconButton(
                title: titleKey.tr,
                message: bodyKey.tr,
                color: AppColors.mutedText,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            titleKey.tr,
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.of(context)
                .listTileTitle
                .copyWith(color: AppColors.primaryPurple, fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}

class _TitleInfoRow extends StatelessWidget {
  const _TitleInfoRow({
    required this.title,
    required this.message,
    required this.titleStyle,
    required this.infoColor,
  });

  final String title;
  final String message;
  final TextStyle titleStyle;
  final Color infoColor;

  @override
  Widget build(BuildContext context) {
    final isRtl = (Get.locale?.languageCode ?? 'ar') == 'ar';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoIconButton(
            title: title,
            message: message,
            color: infoColor,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              style: titleStyle,
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
    return localizedValue(entry.name, preferredLocale: langCode);
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
                  .copyWith(color: AppColors.primaryPurple),
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
                color: Color(0x141D6652),
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
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.mintSurface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            titleKey.tr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.primaryPurple),
          ),
          const SizedBox(height: 8),
          Text(
            bodyKey.tr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .bodyDefault
              .copyWith(color: AppColors.mutedText),
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
                side: const BorderSide(color: AppColors.lineColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionLabel!,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context)
                    .buttonSecondary
                    .copyWith(color: AppColors.primaryPurple),
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
