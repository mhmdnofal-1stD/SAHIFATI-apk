import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/school_level_content.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';
import 'content_item_card.dart';
import 'questions_completion_screen.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  int selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isTransitioningLevel = false;
  String? _levelLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadSelectedLevel();
    });
  }

  Future<void> _preloadSelectedLevel() async {
    if (!mounted) return;

    final usersProvider = context.read<UsersProvider>();
    final schoolProvider = context.read<SchoolProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final levels = _readLevels(schoolProvider);

    if (usersProvider.selectedUser == null || levels.isEmpty) {
      return;
    }

    setState(() {
      _levelLoadError = null;
    });

    try {
      await evaluationsProvider.preloadQuestionLevelData(
        usersProvider.selectedUser!.id,
        levels[selectedIndex].content,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _levelLoadError = _cleanError(error);
      });
    }
  }

  List<SchoolLevel> _readLevels(SchoolProvider schoolProvider) {
    try {
      return schoolProvider.quickQuestionsSchool.levels;
    } catch (_) {
      return const [];
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? 'questions_screen_level_load_generic_error'.tr
        : message;
  }

  int _countCompletedItems(
    EvaluationsProvider evaluationsProvider,
    List<SchoolLevelContent> contents,
  ) {
    return contents
        .where(
          (content) =>
              evaluationsProvider.getQuestionContentCompletion(content) == true,
        )
        .length;
  }

  int _countCompletedLevels(
    EvaluationsProvider evaluationsProvider,
    List<SchoolLevel> levels,
  ) {
    return levels
        .where(
          (level) =>
              level.content.isNotEmpty &&
              level.content.every(
                (content) =>
                    evaluationsProvider.getQuestionContentCompletion(content) ==
                    true,
              ),
        )
        .length;
  }

  int _countTotalItems(List<SchoolLevel> levels) {
    return levels.fold<int>(
      0,
      (total, level) => total + level.content.length,
    );
  }

  int _countCompletedItemsAcrossLevels(
    EvaluationsProvider evaluationsProvider,
    List<SchoolLevel> levels,
  ) {
    return levels.fold<int>(
      0,
      (total, level) => total + _countCompletedItems(evaluationsProvider, level.content),
    );
  }

  Future<void> _changeLevel(int nextIndex) async {
    final schoolProvider = context.read<SchoolProvider>();
    final levels = _readLevels(schoolProvider);
    if (_isBusy || nextIndex < 0 || nextIndex >= levels.length) {
      return;
    }

    setState(() {
      selectedIndex = nextIndex;
      _isTransitioningLevel = true;
      _levelLoadError = null;
    });

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    await _preloadSelectedLevel();

    if (!mounted) {
      return;
    }

    setState(() {
      _isTransitioningLevel = false;
    });
  }

  Future<void> _openCompletionSummary({required bool skipped}) async {
    final schoolProvider = context.read<SchoolProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final levels = _readLevels(schoolProvider);
    if (levels.isEmpty) {
      return;
    }

    final totalItems = _countTotalItems(levels);
    final completedItems =
        _countCompletedItemsAcrossLevels(evaluationsProvider, levels);
    final completedLevels = _countCompletedLevels(evaluationsProvider, levels);

    await Get.to(
      QuestionsCompletionScreen(
        skipped: skipped,
        totalLevels: levels.length,
        completedLevels: completedLevels,
        totalItems: totalItems,
        completedItems: completedItems,
        lastReachedLevel: selectedIndex + 1,
      ),
    );
  }

  bool get _isBusy {
    final evaluationsProvider = context.read<EvaluationsProvider>();
    return _isTransitioningLevel || evaluationsProvider.isQuestionsLevelLoading;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = context.watch<SchoolProvider>();
    final evaluationsProvider = context.watch<EvaluationsProvider>();
    final levels = _readLevels(schoolProvider);
    final isSchoolReady = levels.isNotEmpty;
    final currentLevel = isSchoolReady ? levels[selectedIndex] : null;
    final totalLevels = levels.length;
    final currentLevelCompleted = currentLevel == null
        ? 0
        : _countCompletedItems(evaluationsProvider, currentLevel.content);
    final currentLevelTotal = currentLevel?.content.length ?? 0;
    final overallCompletedLevels = isSchoolReady
        ? _countCompletedLevels(evaluationsProvider, levels)
        : 0;
    final isLastLevel = isSchoolReady && selectedIndex == totalLevels - 1;
    final levelProgress = totalLevels == 0 ? 0.0 : (selectedIndex + 1) / totalLevels;

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
                'questions_screen_title'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackFontColor,
                ),
              ),
              leading: const CustomBackButton(),
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
        body: SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: ResponsiveContentShell(
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: !isSchoolReady
                  ? _QuestionsEmptyState(
                      title: schoolProvider.isLoading
                          ? 'questions_screen_empty_loading_title'.tr
                          : 'questions_screen_empty_no_levels_title'.tr,
                      body: schoolProvider.isLoading
                          ? 'questions_screen_empty_loading_body'.tr
                          : 'questions_screen_empty_no_levels_body'.tr,
                      actionLabel: schoolProvider.isLoading
                          ? null
                          : 'welcome_chart_retry'.tr,
                      onAction: schoolProvider.isLoading
                          ? null
                          : () async {
                              await schoolProvider.getQuickQuestionsSchool();
                              if (!mounted) {
                                return;
                              }
                              await _preloadSelectedLevel();
                            },
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            controller: _scrollController,
                            children: [
                              _QuestionsHeader(
                                eyebrow: 'questions_screen_level_eyebrow'
                                    .trParams({
                                  'current': '${selectedIndex + 1}',
                                  'total': '$totalLevels',
                                }),
                                title: currentLevel?.name?[Get.locale?.languageCode ?? 'ar'] ??
                                    'questions_screen_level_fallback_title'.tr,
                                subtitle: 'questions_screen_level_subtitle'.tr,
                                progress: levelProgress,
                                completedItems: currentLevelCompleted,
                                totalItems: currentLevelTotal,
                                completedLevels: overallCompletedLevels,
                                totalLevels: totalLevels,
                              ),
                              if (_isBusy)
                                _QuestionsStatusBanner(
                                  icon: Icons.sync,
                                  title: 'questions_screen_status_loading_title'.tr,
                                  body: 'questions_screen_status_loading_body'.tr,
                                ),
                              if (_levelLoadError != null)
                                _QuestionsStatusBanner(
                                  icon: Icons.error_outline,
                                  color: const Color(0xFFFFF2F0),
                                  borderColor: const Color(0xFFE8B4AE),
                                  title: 'questions_screen_status_error_title'.tr,
                                  body: _levelLoadError!,
                                  actionLabel: 'welcome_chart_retry'.tr,
                                  onAction: _preloadSelectedLevel,
                                ),
                              if (currentLevelTotal == 0)
                                _QuestionsEmptyState(
                                  title: 'questions_screen_empty_level_title'.tr,
                                  body: 'questions_screen_empty_level_body'.tr,
                                )
                              else
                                ...currentLevel!.content.asMap().entries.map(
                                  (entry) => ContentItemCard(
                                    content: entry.value,
                                    index: entry.key,
                                    isCompleted: evaluationsProvider
                                        .getQuestionContentCompletion(entry.value),
                                    isLoadingStatus: _isBusy,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _QuestionsFooter(
                                isBusy: _isBusy,
                                isFirstLevel: selectedIndex == 0,
                                isLastLevel: isLastLevel,
                                footerHint: 'questions_screen_footer_hint'.tr,
                                onPrevious: selectedIndex == 0
                                    ? null
                                    : () => _changeLevel(selectedIndex - 1),
                                onNext: isLastLevel
                                    ? () => _openCompletionSummary(skipped: false)
                                    : () => _changeLevel(selectedIndex + 1),
                                onFinishForNow: () => _openCompletionSummary(skipped: true),
                                previousLabel: 'previous_level'.tr,
                                nextLabel: isLastLevel
                                    ? 'questions_screen_summary_label'.tr
                                    : 'next_level'.tr,
                                finishLabel: 'questions_screen_finish_now_label'.tr,
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
    );
  }
}

class _QuestionsHeader extends StatelessWidget {
  const _QuestionsHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.completedItems,
    required this.totalItems,
    required this.completedLevels,
    required this.totalLevels,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final double progress;
  final int completedItems;
  final int totalItems;
  final int completedLevels;
  final int totalLevels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7F4ED), Color(0xFFE8F0EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.lineColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10112038),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.buttonColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30.5,
              fontWeight: FontWeight.w800,
              color: AppColors.blackFontColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16.2,
              height: 1.5,
              color: Color(0xFF39433D),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.buttonColor),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuestionsMetricChip(
                label: 'questions_screen_metric_completed_units'.tr,
                value: '$completedItems / $totalItems',
              ),
              _QuestionsMetricChip(
                label: 'questions_screen_metric_completed_levels'.tr,
                value: '$completedLevels / $totalLevels',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionsMetricChip extends StatelessWidget {
  const _QuestionsMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5A645F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionsStatusBanner extends StatelessWidget {
  const _QuestionsStatusBanner({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.color = const Color(0xFFF6F8FA),
    this.borderColor = const Color(0xFFD9E0E7),
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.buttonColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 15, height: 1.55),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionsFooter extends StatelessWidget {
  const _QuestionsFooter({
    required this.isBusy,
    required this.isFirstLevel,
    required this.isLastLevel,
    required this.footerHint,
    required this.onPrevious,
    required this.onNext,
    required this.onFinishForNow,
    required this.previousLabel,
    required this.nextLabel,
    required this.finishLabel,
  });

  final bool isBusy;
  final bool isFirstLevel;
  final bool isLastLevel;
  final String footerHint;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinishForNow;
  final String previousLabel;
  final String nextLabel;
  final String finishLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lineColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10112038),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            footerHint,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy || isFirstLevel ? null : onPrevious,
                icon: const Icon(Icons.arrow_back),
                label: Text(previousLabel),
              ),
              FilledButton.icon(
                onPressed: isBusy ? null : onNext,
                icon: Icon(isLastLevel ? Icons.summarize : Icons.arrow_forward),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.buttonColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                label: Text(nextLabel),
              ),
              TextButton(
                onPressed: isBusy ? null : onFinishForNow,
                child: Text(finishLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionsEmptyState extends StatelessWidget {
  const _QuestionsEmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.lineColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: AppColors.buttonColor,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15.5, height: 1.6),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.buttonColor,
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
