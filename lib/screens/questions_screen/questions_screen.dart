import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/models/school.dart';
import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/school_level_content.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/info_icon_button.dart';
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
  int selectedSchoolIndex = 0;
  int selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isTransitioningLevel = false;
  String? _levelLoadError;

  bool get _isArabicUi => (Get.locale?.languageCode ?? 'ar') == 'ar';

  String get _compactFinishLabel => _isArabicUi ? 'إنهاء' : 'Finish';

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
    final activeUser = usersProvider.activeAccountUser;

    if (activeUser == null || levels.isEmpty) {
      return;
    }

    setState(() {
      _levelLoadError = null;
    });

    try {
      await evaluationsProvider.preloadQuestionLevelData(
        activeUser.id,
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
      final schools = schoolProvider.schools;
      if (schools.isEmpty) return const [];
      if (selectedSchoolIndex >= schools.length) return const [];
      return schools[selectedSchoolIndex].levels;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _changeSchool(int nextSchoolIndex) async {
    if (_isBusy) return;
    final schoolProvider = context.read<SchoolProvider>();
    final schools = schoolProvider.schools;
    if (nextSchoolIndex < 0 || nextSchoolIndex >= schools.length) return;
    setState(() {
      selectedSchoolIndex = nextSchoolIndex;
      selectedIndex = 0;
      _levelLoadError = null;
    });
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    await _preloadSelectedLevel();
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
      (total, level) =>
          total + _countCompletedItems(evaluationsProvider, level.content),
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
        browseSchoolLevelPair: (() {
          final currentLevel = levels[selectedIndex];
          final schoolId = currentLevel.schoolId;
          final levelNumber = currentLevel.level;
          if (schoolId == null || levelNumber == null) {
            return null;
          }
          return '$schoolId:$levelNumber';
        })(),
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
    final allSchools = schoolProvider.schools;
    final levels = _readLevels(schoolProvider);
    final isSchoolReady = levels.isNotEmpty;
    final currentLevel = isSchoolReady ? levels[selectedIndex] : null;
    final currentLevelContents = currentLevel?.content ?? const <SchoolLevelContent>[];
    final totalLevels = levels.length;
    final currentLevelCompleted = currentLevel == null
        ? 0
        : _countCompletedItems(evaluationsProvider, currentLevel.content);
    final currentLevelTotal = currentLevel?.content.length ?? 0;
    final overallCompletedLevels =
        isSchoolReady ? _countCompletedLevels(evaluationsProvider, levels) : 0;
    final isLastLevel = isSchoolReady && selectedIndex == totalLevels - 1;
    final levelProgress =
        totalLevels == 0 ? 0.0 : (selectedIndex + 1) / totalLevels;

    return NoPopScope(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              toolbarHeight: 52,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
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
            horizontalGutter: 8,
            pendingSyncBottomPadding: 6,
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
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
                        if (allSchools.length > 1)
                          _SchoolTabsRow(
                            schools: allSchools,
                            selectedIndex: selectedSchoolIndex,
                            onTap: _changeSchool,
                            isArabicUi: _isArabicUi,
                          ),
                        _QuestionsHeader(
                          isArabicUi: _isArabicUi,
                          currentLevelNumber: selectedIndex + 1,
                          totalLevels: totalLevels,
                          title: currentLevel?.name?[
                                  Get.locale?.languageCode ?? 'ar'] ??
                              'questions_screen_level_fallback_title'.tr,
                          progress: levelProgress,
                          completedItems: currentLevelCompleted,
                          totalItems: currentLevelTotal,
                          completedLevels: overallCompletedLevels,
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
                        const SizedBox(height: 8),
                        Expanded(
                          child: currentLevelTotal == 0
                              ? _QuestionsEmptyState(
                                  title: 'questions_screen_empty_level_title'.tr,
                                  body: 'questions_screen_empty_level_body'.tr,
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  itemCount: currentLevelContents.length,
                                  padding: const EdgeInsets.only(bottom: 4),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final content = currentLevelContents[index];
                                    return ContentItemCard(
                                      content: content,
                                      index: index,
                                      isCompleted: evaluationsProvider
                                          .getQuestionContentCompletion(content),
                                      isLoadingStatus: _isBusy,
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 10),
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
                          onFinishForNow: () =>
                              _openCompletionSummary(skipped: true),
                          previousLabel: 'previous'.tr,
                          nextLabel: 'next'.tr,
                          finishLabel: _compactFinishLabel,
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
    required this.isArabicUi,
    required this.currentLevelNumber,
    required this.totalLevels,
    required this.title,
    required this.progress,
    required this.completedItems,
    required this.totalItems,
    required this.completedLevels,
  });

  final bool isArabicUi;
  final int currentLevelNumber;
  final int totalLevels;
  final String title;
  final double progress;
  final int completedItems;
  final int totalItems;
  final int completedLevels;

  String _metricUnitsLabel() => isArabicUi ? 'وحدات' : 'Units';

  String _metricLevelsLabel() => isArabicUi ? 'مستويات' : 'Levels';

  String _stateLabel() {
    if (completedItems > 0 && completedItems >= totalItems && totalItems > 0) {
      return isArabicUi ? 'منجز' : 'Done';
    }

    if (completedItems > 0) {
      return isArabicUi ? 'تقدّم' : 'Progress';
    }

    return isArabicUi ? 'بداية' : 'Start';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metricWidth = constraints.maxWidth < 540 ? 72.0 : 82.0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFCFBF8), Color(0xFFF7FAF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.lineColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08112038),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _QuestionsHeaderBadge(
                    icon: Icons.layers_outlined,
                    label: '$currentLevelNumber / $totalLevels',
                  ),
                  const SizedBox(width: 6),
                  _QuestionsHeaderBadge(
                    icon: Icons.auto_awesome_rounded,
                    label: _stateLabel(),
                    emphasized: true,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: metricWidth,
                    child: _QuestionsMetricChip(
                      label: _metricUnitsLabel(),
                      value: '$completedItems/$totalItems',
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: metricWidth,
                    child: _QuestionsMetricChip(
                      label: _metricLevelsLabel(),
                      value: '$completedLevels/$totalLevels',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F4F1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.buttonColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestionsHeaderBadge extends StatelessWidget {
  const _QuestionsHeaderBadge({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = emphasized
        ? AppColors.buttonColor.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.92);
    final foregroundColor = emphasized
        ? AppColors.buttonColor
        : AppColors.blackFontColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.2,
              color: Color(0xFF5A645F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lineColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08112038),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: isBusy || isFirstLevel ? null : onPrevious,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  previousLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onNext,
                icon: Icon(
                  isLastLevel ? Icons.summarize_rounded : Icons.arrow_forward,
                  size: 18,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.buttonColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  nextLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 38,
            child: TextButton(
              onPressed: isBusy ? null : onFinishForNow,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                finishLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InfoIconButton(
            message: footerHint,
            color: AppColors.mutedText,
            size: 17,
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

class _SchoolTabsRow extends StatelessWidget {
  const _SchoolTabsRow({
    required this.schools,
    required this.selectedIndex,
    required this.onTap,
    required this.isArabicUi,
  });

  final List<School> schools;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isArabicUi;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: schools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == selectedIndex;
          final school = schools[i];
          final label = (school.schoolName[isArabicUi ? 'ar' : 'en'] ??
              school.schoolName['ar'] ??
              school.schoolName['en'] ??
              '') as String;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.buttonColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.buttonColor
                      : AppColors.buttonColor.withAlpha(80),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.buttonColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
