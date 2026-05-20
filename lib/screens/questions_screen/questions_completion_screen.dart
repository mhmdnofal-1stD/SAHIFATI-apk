import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/main_screen/main_screen.dart';
import 'package:sahifaty/services/evaluations_services.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/info_icon_button.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';

class QuestionsCompletionScreen extends StatefulWidget {
  const QuestionsCompletionScreen({
    super.key,
    required this.skipped,
    required this.totalLevels,
    required this.completedLevels,
    required this.totalItems,
    required this.completedItems,
    required this.lastReachedLevel,
    this.browseSchoolLevelPair,
  });

  final bool skipped;
  final int totalLevels;
  final int completedLevels;
  final int totalItems;
  final int completedItems;
  final int lastReachedLevel;
  final String? browseSchoolLevelPair;

  @override
  State<QuestionsCompletionScreen> createState() =>
      _QuestionsCompletionScreenState();
}

class _QuestionsCompletionScreenState extends State<QuestionsCompletionScreen> {
  bool _isOpeningReadingBrowser = false;
  bool _isNavigatingToAuth = false;
  String? _errorMessage;

  QuranChartFilters _browseChartFilters() {
    final schoolLevelPair = widget.browseSchoolLevelPair?.trim();
    if (schoolLevelPair == null || schoolLevelPair.isEmpty) {
      return const QuranChartFilters();
    }

    return QuranChartFilters(schoolLevelPairs: [schoolLevelPair]);
  }

  Future<void> _openReadingBrowser() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final user = usersProvider.selectedUser;
    final filters = _browseChartFilters();

    setState(() {
      _isOpeningReadingBrowser = true;
      _errorMessage = null;
    });

    try {
      if (user != null) {
        await evaluationsProvider.getQuranChartData(
          user.id,
          filters: filters,
        );
      }

      if (!mounted) {
        return;
      }

      final parameters = <String, String>{
        'comesFirst': 'false',
      };
      if (filters.schoolLevelPairs.isNotEmpty) {
        parameters['schoolLevelPairs'] = filters.schoolLevelPairs.join(',');
      }

      Get.offAllNamed(MainScreen.routeName, parameters: parameters);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _errorMessage = message.isEmpty
            ? 'questions_completion_open_browse_error'.tr
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

  void _openSignUp() {
    if (_isNavigatingToAuth) {
      return;
    }

    setState(() {
      _isNavigatingToAuth = true;
      _errorMessage = null;
    });

    Get.offAllNamed('/signup');
  }

  void _openLogin() {
    if (_isNavigatingToAuth) {
      return;
    }

    setState(() {
      _isNavigatingToAuth = true;
      _errorMessage = null;
    });

    Get.offAllNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();
    final isGuestFlow = usersProvider.selectedUser == null;
    final completionRatio = widget.totalItems == 0
        ? 0.0
        : widget.completedItems / widget.totalItems;
    final remainingItems = widget.totalItems - widget.completedItems;

    return NoPopScope(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'questions_completion_title'.tr,
                style: AppTypography.of(context)
                    .appBarTitle
                    .copyWith(color: AppColors.blackFontColor),
              ),
              leading: const CustomBackButton(),
              actions: isGuestFlow
                  ? const []
                  : [
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
        drawer: !isGuestFlow && (Get.locale?.languageCode ?? 'ar') == 'ar'
            ? const GlobalDrawer()
            : null,
        endDrawer: !isGuestFlow && (Get.locale?.languageCode ?? 'ar') == 'ar'
            ? null
            : const GlobalDrawer(),
        body: ResponsiveContentShell(
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF4EFE6), Color(0xFFE7F0E8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.lineColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10112038),
                            blurRadius: 22,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.skipped
                                ? 'questions_completion_badge_skipped'.tr
                                : 'questions_completion_badge_complete'.tr,
                            style: AppTypography.of(context)
                                .badgeLabel
                                .copyWith(
                                  color: AppColors.buttonColor,
                                  fontSize: 15,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isGuestFlow
                                ? 'questions_completion_heading_guest'.tr
                                : widget.skipped
                                    ? 'questions_completion_heading_skipped'.tr
                                    : 'questions_completion_heading_complete'.tr,
                            style: AppTypography.of(context).pageHeading,
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: completionRatio.clamp(0, 1),
                              minHeight: 9,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.buttonColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _SummaryMetricCard(
                          label: 'questions_completion_metric_completed_units'.tr,
                          value: '${widget.completedItems} / ${widget.totalItems}',
                        ),
                        _SummaryMetricCard(
                          label: 'questions_completion_metric_completed_levels'.tr,
                          value: '${widget.completedLevels} / ${widget.totalLevels}',
                        ),
                        _SummaryMetricCard(
                          label: 'questions_completion_metric_last_level'.tr,
                          value: '${widget.lastReachedLevel} / ${widget.totalLevels}',
                        ),
                        _SummaryMetricCard(
                          label: 'questions_completion_metric_remaining_units'.tr,
                          value: '$remainingItems',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.lineColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: AppTypography.of(context)
                                  .bodySecondary
                                  .copyWith(color: AppColors.errorColor),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (isGuestFlow) ...[
                            Text(
                              'questions_completion_meaning_body_guest'.tr,
                              style: AppTypography.of(context)
                                  .bodySecondary
                                  .copyWith(color: AppColors.mutedText),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isNavigatingToAuth
                                      ? null
                                      : _openSignUp,
                                  icon: const Icon(Icons.person_add_alt_1),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.buttonColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                  ),
                                  label: Text('create_account'.tr),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isNavigatingToAuth
                                      ? null
                                      : _openLogin,
                                  icon: const Icon(Icons.login_rounded),
                                  label: Text('login'.tr),
                                ),
                              ],
                            ),
                          ] else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isOpeningReadingBrowser
                                      ? null
                                      : _openReadingBrowser,
                                  icon: _isOpeningReadingBrowser
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.auto_graph),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.buttonColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                  ),
                                  label: Text(
                                    _isOpeningReadingBrowser
                                        ? 'questions_completion_opening_label'
                                            .tr
                                        : 'questions_completion_continue_label'
                                            .tr,
                                  ),
                                ),
                                InfoIconButton(
                                  message: widget.skipped
                                      ? 'questions_completion_meaning_body_skipped'
                                          .tr
                                      : 'questions_completion_meaning_body_complete'
                                          .tr,
                                  color: AppColors.mutedText,
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isOpeningReadingBrowser
                                      ? null
                                      : () => Get.back<void>(),
                                  icon: const Icon(Icons.arrow_back),
                                  label: Text(
                                    'questions_completion_back_label'.tr,
                                  ),
                                ),
                              ],
                            ),
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
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: const Color(0xFF59625D)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.of(context).pageHeading,
          ),
        ],
      ),
    );
  }
}