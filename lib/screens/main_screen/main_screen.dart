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
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/chart_filter_panel.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/notifications_bell_button.dart';
import '../widgets/responsive_content_shell.dart';
import '../widgets/surah_picker_dialog.dart';

class MainScreen extends StatefulWidget {
  static const String routeName = '/browse';

  const MainScreen({super.key, this.comesFirst = false});

  final bool comesFirst;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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

  bool _hasChartData(EvaluationsProvider provider) {
    return provider.totalCount > 0 && provider.chartEvaluationData.isNotEmpty;
  }

  Future<void> _resumeReading(BuildContext context, int? userId) async {
    final session = await ReadingSessionStore().loadForUser(userId);
    if (!context.mounted) return;

    if (session != null) {
      await ReadingSessionStore()
          .updateAutoResumeForUser(userId, false);
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

    if (widget.comesFirst) {
      final evaluationsProvider = context.read<EvaluationsProvider>();
      evaluationsProvider.getAllEvaluations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final hasChartData = _hasChartData(evaluationsProvider);
    final showBackButton = _hasInAppBackTarget(context);
    final selectedUserId = usersProvider.selectedUser?.id;

    return evaluationsProvider.isLoading == true
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : NoPopScope(
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
            drawer: (Get.locale?.languageCode ?? 'ar') == 'ar' ? const GlobalDrawer() : null,
            endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar' ? null : const GlobalDrawer(),
            body: ResponsiveContentShell(
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 980),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF5F2EA), Color(0xFFE9F0E7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFDCE2DA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'main_screen_gateway_badge'.tr,
                            style: const TextStyle(
                              color: AppColors.buttonColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${"well_done".tr} ${usersProvider.selectedUser?.username ?? usersProvider.selectedUser?.email ?? ''}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: SizeConfig.getProportionalHeight(20)),
                    if (selectedUserId != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: ChartFilterPanel(userId: selectedUserId),
                      ),
                    if (!widget.comesFirst)
                      hasChartData
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 920),
                              child: BarChartWidget(
                                evaluationsProvider: evaluationsProvider,
                                languageProvider: languageProvider,
                                includeUncategorized: false,
                              ),
                            )
                          : Container(
                              constraints: const BoxConstraints(maxWidth: 920),
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F8F4),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFDCE2DA)),
                              ),
                              child: Text(
                                'main_screen_chart_empty'.tr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(height: 1.5),
                              ),
                            )
                    else
                      Container(
                        constraints: const BoxConstraints(maxWidth: 920),
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F4),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFDCE2DA)),
                        ),
                        child: Text(
                          'main_screen_chart_intro_first'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    SizedBox(height: SizeConfig.getProportionalHeight(20)),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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
                              style: const TextStyle(
                                color: AppColors.buttonColor,
                                fontWeight: FontWeight.w800,
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
              ),
            ),
            ),
          );
  }
}
