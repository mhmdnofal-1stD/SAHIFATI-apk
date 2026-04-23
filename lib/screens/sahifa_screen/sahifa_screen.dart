import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/models/chart_evaluation_data.dart';
import 'package:sahifaty/providers/language_provider.dart';
import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../main_screen/main_screen.dart';
import '../quran_view/index_page.dart';
import '../widgets/assessment_dimension_toggle.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/custom_button.dart';
import '../widgets/user_profile_badge.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';

class SahifaScreen extends StatelessWidget {
  const SahifaScreen({super.key, required this.firstScreen});

  final bool firstScreen;

  String _copy(bool isArabic, String arabic, String english) {
    return isArabic ? arabic : english;
  }

  int _evaluatedVerses(EvaluationsProvider provider) {
    final categorizedVerses = provider.chartEvaluationData
        .where((entry) => entry.evaluationId != 0)
        .fold<int>(0, (sum, entry) => sum + (entry.verseCount ?? 0));

    if (categorizedVerses > 0) {
      return categorizedVerses;
    }

    final uncategorized =
        EvaluationsController().getEvaluationById(0, provider)?.verseCount ?? 0;
    final fallback = provider.totalCount - uncategorized;
    return fallback < 0 ? 0 : fallback;
  }

  ChartEvaluationData? _topSignal(EvaluationsProvider provider) {
    final entries = provider.chartEvaluationData
        .where((entry) => entry.evaluationId != 0 && (entry.verseCount ?? 0) > 0)
        .toList()
      ..sort((a, b) => (b.verseCount ?? 0).compareTo(a.verseCount ?? 0));

    if (entries.isEmpty) {
      return null;
    }

    return entries.first;
  }

  int _remainingVerses(EvaluationsProvider provider) {
    final remaining = provider.totalCount - _evaluatedVerses(provider);
    return remaining < 0 ? 0 : remaining;
  }

  @override
  Widget build(BuildContext context) {
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context);
    LanguageProvider languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    final isComprehension = evaluationsProvider.chartDimension ==
        EvaluationsController.comprehensionDimension;
    final evaluatedVerses = _evaluatedVerses(evaluationsProvider);
    final hasChartData =
        evaluatedVerses > 0 && evaluationsProvider.chartEvaluationData.isNotEmpty;
    final topSignal = _topSignal(evaluationsProvider);
    final remainingVerses = _remainingVerses(evaluationsProvider);
    final currentDimensionLabel = _copy(
      isArabic,
      isComprehension ? 'الفهم' : 'الحفظ',
      isComprehension ? 'Comprehension' : 'Memorization',
    );

    return NoPopScope(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: AppColors.backgroundColor,
              automaticallyImplyLeading: usersProvider.isFirstLogin,
              leadingWidth: usersProvider.isFirstLogin ? 56 : 140,
              // adjust
              leading: usersProvider.isFirstLogin
                  ? const CustomBackButton()
                  : const Padding(
                      padding: EdgeInsetsDirectional.only(start: 12),
                      child: UserProfileBadge(),
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
        body: ResponsiveContentShell(
          builder: (context) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 980),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4EFE6), Color(0xFFE5F0E8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD7DED6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _copy(
                            isArabic,
                            firstScreen
                                ? 'هذه هي بداية صحيفتك'
                                : 'هذه الصحيفة تقرأ وضعك الحالي',
                            firstScreen
                                ? 'This is the start of your Sahifa'
                                : 'This Sahifa reads your current state',
                          ),
                          style: const TextStyle(
                            color: AppColors.buttonColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _copy(
                            isArabic,
                            '${"well_done".tr} ${usersProvider.selectedUser?.fullName ?? ''}',
                            '${"well_done".tr} ${usersProvider.selectedUser?.fullName ?? ''}',
                          ),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blackFontColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _copy(
                            isArabic,
                            'هذه الشاشة ليست dashboard منفصلًا، بل ملخصًا سريعًا يساعدك على فهم وضعك ثم الانتقال إلى القراءة من نقطة أوضح.',
                            'This screen is not a separate dashboard. It is a quick summary that helps you understand your current state, then move into reading from a clearer starting point.',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: Color(0xFF39433D),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SahifaMetricChip(
                              label: _copy(
                                isArabic,
                                'الآيات ذات الإشارة الفعلية',
                                'Verses with real signal',
                              ),
                              value: '$evaluatedVerses',
                            ),
                            _SahifaMetricChip(
                              label: _copy(
                                isArabic,
                                'البعد المعروض الآن',
                                'Current dimension',
                              ),
                              value: currentDimensionLabel,
                            ),
                            _SahifaMetricChip(
                              label: _copy(
                                isArabic,
                                'الآيات غير المقيمة بعد',
                                'Verses still without assessment',
                              ),
                              value: '$remainingVerses',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<ReadingSession?>(
                    future:
                        ReadingSessionStore().loadForUser(usersProvider.selectedUser?.id),
                    builder: (context, snapshot) {
                      final session = snapshot.data;
                      if (session == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 980),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFDCE2DA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _copy(
                                  isArabic,
                                  'قراءة محفوظة بانتظارك',
                                  'A saved reading session is waiting',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _copy(
                                  isArabic,
                                  'إذا كنت خرجت من القراءة أو عدت بعد refresh، يمكنك استئناف القراءة مباشرة من سورة ${session.surah.nameAr} عبر مسار ${session.pathLabel(true)}.',
                                  'If you left reading or came back after a refresh, you can resume directly from Surah ${session.surah.nameAr} through the ${session.pathLabel(false)} path.',
                                ),
                                style: const TextStyle(height: 1.55),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () async {
                                  await ReadingSessionStore()
                                      .updateAutoResumeForUser(
                                    usersProvider.selectedUser?.id,
                                    false,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }

                                  Get.to(() => IndexPage.fromReadingSession(session));
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.buttonColor,
                                ),
                                icon: const Icon(Icons.menu_book_rounded),
                                label: Text(
                                  _copy(
                                    isArabic,
                                    'استئناف القراءة',
                                    'Resume reading',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    height: SizeConfig.getProportionalHeight(24),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 980),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFDCE2DA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _copy(
                            isArabic,
                            'ملخص الصحيفة الآن',
                            'Your Sahifa summary right now',
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _copy(
                            isArabic,
                            'نستخدم هذا الملخص لتوضيح حالتك الحالية فقط: ما الذي تم تقييمه فعلاً، وأي بعد تراه الآن، وأين يمكنك المتابعة إلى القراءة.',
                            'This summary only explains your current state: what has actually been assessed, which dimension you are looking at now, and where you can continue into reading.',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: Color(0xFF4A554E),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (evaluationsProvider.isLoading && !hasChartData)
                          _SahifaStateCard(
                            icon: Icons.sync,
                            title: _copy(
                              isArabic,
                              'جارٍ تجهيز الملخص',
                              'Preparing your summary',
                            ),
                            body: _copy(
                              isArabic,
                              'نحمّل قراءة الحالة الحالية قبل عرض أي مخطط حتى لا نعطيك انطباعًا مضللًا.',
                              'We are loading your current state before showing any chart so the screen does not imply progress that is not real.',
                            ),
                          )
                        else if (!hasChartData)
                          _SahifaStateCard(
                            icon: evaluationsProvider.chartLoadError == null
                                ? Icons.info_outline
                                : Icons.error_outline,
                            title: evaluationsProvider.chartLoadError == null
                                ? _copy(
                                    isArabic,
                                    'لا توجد إشارة تقييم كافية بعد',
                                    'There is not enough assessment signal yet',
                                  )
                                : _copy(
                                    isArabic,
                                    'تعذر تحميل الملخص الآن',
                                    'We could not load the summary right now',
                                  ),
                            body: evaluationsProvider.chartLoadError == null
                                ? _copy(
                                    isArabic,
                                    'عندما تبدأ التقييم أو تكمل القراءة المقيمة سيظهر هنا ملخص فعلي بدل مخطط يوحي ببيانات غير موجودة.',
                                    'Once you start assessing or build real reading data, this area will show an actual summary instead of a chart that implies missing data exists.',
                                  )
                                : evaluationsProvider.chartLoadError!,
                            actionLabel: usersProvider.selectedUser == null
                                ? null
                                : _copy(isArabic, 'إعادة المحاولة', 'Retry'),
                            onAction: usersProvider.selectedUser == null
                                ? null
                                : () async {
                                    await evaluationsProvider.getQuranChartData(
                                      usersProvider.selectedUser!.id,
                                      dimension: evaluationsProvider.chartDimension,
                                    );
                                  },
                          )
                        else ...[
                          AssessmentDimensionToggle(
                            selectedDimension: evaluationsProvider.chartDimension,
                            onChanged: (dimension) async {
                              final user = usersProvider.selectedUser;
                              if (user == null) {
                                return;
                              }

                              await evaluationsProvider.getQuranChartData(
                                user.id,
                                dimension: dimension,
                              );
                            },
                          ),
                          SizedBox(
                            height: SizeConfig.getProportionalHeight(16),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: BarChartWidget(
                              evaluationsProvider: evaluationsProvider,
                              languageProvider: languageProvider,
                              includeUncategorized: false,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (topSignal != null)
                            _SahifaStateCard(
                              icon: Icons.auto_graph,
                              title: _copy(
                                isArabic,
                                'أوضح نتيجة حالية',
                                'Strongest current signal',
                              ),
                              body: _copy(
                                isArabic,
                                '${topSignal.name[languageProvider.langCode] ?? ''} تغطي ${topSignal.verseCount ?? 0} آية ضمن هذا العرض.',
                                '${topSignal.name[languageProvider.langCode] ?? ''} currently covers ${topSignal.verseCount ?? 0} verses in this view.',
                              ),
                            ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Text(
                              isComprehension
                                  ? _copy(
                                      isArabic,
                                      'هذا العرض يحسب فقط الآيات التي تحمل تقييم فهم فعلي الآن. عددها الحالي: $evaluatedVerses آية.',
                                      'This view counts only verses that currently carry a real comprehension assessment. Current total: $evaluatedVerses verses, with $remainingVerses still outside this summary.',
                                    )
                                  : _copy(
                                      isArabic,
                                      'هذا الملخص مبني على $evaluatedVerses آية صُنفت فعلاً داخل الصحيفة، بينما تبقى $remainingVerses آية خارج هذا الملخص إلى أن تُقيّم لاحقًا.',
                                      'This summary is built from $evaluatedVerses verses that were actually categorized inside the Sahifa, while $remainingVerses verses still remain outside this summary until they are assessed later.',
                                    ),
                              textAlign: TextAlign.center,
                              strutStyle: const StrutStyle(
                                forceStrutHeight: true,
                                height: 1.35,
                                leading: 0.0,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDCE2DA)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _copy(
                                isArabic,
                                'الخطوة التالية: افتح القراءة من المسار الذي يناسبك',
                                'Next step: open reading from the path that fits you best',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _copy(
                                isArabic,
                                'الصحيفة هنا لتوضح الصورة، ثم تتركك تنتقل سريعًا إلى التصفح والقراءة من دون التفاف زائد.',
                                'The Sahifa clarifies the picture here, then lets you move quickly into exploration and reading without unnecessary detours.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 18),
                            CustomButton(
                              onPressed: () => {Get.to(const MainScreen())},
                              text: "browse_verses".tr,
                              width: 220,
                              height: 48,
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
      ),
    );
  }
}

class _SahifaMetricChip extends StatelessWidget {
  const _SahifaMetricChip({
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
        border: Border.all(color: const Color(0xFFE1E5DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A645F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SahifaStateCard extends StatelessWidget {
  const _SahifaStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E0E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.buttonColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(height: 1.55),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => onAction!(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
