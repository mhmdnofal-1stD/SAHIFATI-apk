import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/screens/sahifa_screen/sahifa_screen.dart';
import 'package:sahifaty/screens/quran_view/index_page.dart';
import 'package:sahifaty/screens/widgets/custom_hizbs_dropdown.dart';
import '../../controllers/general_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/general_provider.dart';
import '../../providers/surahs_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/custom_parts_dropdown.dart';
import '../widgets/custom_thirds_dropdown.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/notifications_bell_button.dart';
import '../widgets/responsive_content_shell.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.comesFirst = false});

  final bool comesFirst;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int? openIndex;

  bool _hasChartData(EvaluationsProvider provider) {
    return provider.totalCount > 0 && provider.chartEvaluationData.isNotEmpty;
  }

  void _selectView(BuildContext context, int view) {
    final provider = context.read<GeneralProvider>();
    provider.setView(view);
    openIndex = null;
    if (view == FilterTypes.hizbs) {
      context
          .read<SurahsProvider>()
          .loadAllHizbSurahs(GeneralController().hizbList);
    }
  }

  void toggle(int index) {
    setState(() {
      if (openIndex == index) {
        openIndex = null;
      } else {
        openIndex = index;
      }
    });
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
    final generalProvider = Provider.of<GeneralProvider>(context);
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final surahsProvider = Provider.of<SurahsProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    final hasChartData = _hasChartData(evaluationsProvider);

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
                  backgroundColor: AppColors.backgroundColor,
                  leading:  CustomBackButton(
                    onPressed: () => Get.off(const SahifaScreen(firstScreen: false)),
                  ),
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
                            '${"well_done".tr} ${usersProvider.selectedUser?.fullName ?? ''}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: SizeConfig.getProportionalHeight(20)),
                      FutureBuilder<ReadingSession?>(
                        future: ReadingSessionStore()
                            .loadForUser(usersProvider.selectedUser?.id),
                        builder: (context, snapshot) {
                          final session = snapshot.data;
                          if (session == null) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 980),
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F8F4),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFDCE2DA)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'main_screen_resume_title'.tr,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'main_screen_resume_body'.trParams({
                                      'surah': session.surah.nameAr,
                                      'path': session.pathLabel(isArabic),
                                    }),
                                    style: const TextStyle(height: 1.5),
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

                                      Get.toNamed(
                                        IndexPage.routeName,
                                        parameters:
                                            IndexPage.routeParametersForSession(
                                          session,
                                        ),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.buttonColor,
                                    ),
                                    icon: const Icon(Icons.menu_book_rounded),
                                    label: Text(
                                      'main_screen_resume_action'.tr,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    SizedBox(height: SizeConfig.getProportionalHeight(16)),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 720),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Row(
                          children: [
                            _buildSegmentItem(
                              context,
                              "thirds_icons".tr,
                              FilterTypes.thirds,
                              generalProvider,
                            ),
                            _buildSegmentItem(
                              context,
                              "parts_icons".tr,
                              FilterTypes.parts,
                              generalProvider,
                            ),
                            _buildSegmentItem(
                              context,
                              "hizbs_icons".tr,
                              FilterTypes.hizbs,
                              generalProvider,
                            ),
                          ],
                        ),
                      ),
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
                    if (generalProvider.mainScreenView == FilterTypes.hizbs &&
                        surahsProvider.isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 50.0),
                        child: _MainScreenStateCard(
                          title: 'main_screen_hizb_loading_title'.tr,
                          body: 'main_screen_hizb_loading_body'.tr,
                          child: const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      )
                    else if (generalProvider.mainScreenView == FilterTypes.hizbs &&
                        surahsProvider.hizbLoadError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: _MainScreenStateCard(
                          title: 'main_screen_hizb_error_title'.tr,
                          body: surahsProvider.hizbLoadError!,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton(
                              onPressed: () {
                                surahsProvider.loadAllHizbSurahs(
                                  GeneralController().hizbList,
                                  force: true,
                                );
                              },
                              child: Text('welcome_chart_retry'.tr),
                            ),
                          ),
                        ),
                      )
                    else if (generalProvider.mainScreenView == FilterTypes.hizbs)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: 60,
                        itemBuilder: (context, index) => CustomHizbsButton(
                          hizb: GeneralController().hizbList[index],
                        ),
                      )
                    else
                      ...List.generate(
                        generalProvider.mainScreenView == FilterTypes.thirds
                            ? 3
                            : generalProvider.mainScreenView == FilterTypes.parts
                                ? 30
                                : 0,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 25),
                          child: generalProvider.mainScreenView ==
                                  FilterTypes.thirds
                              ? CustomThirdsDropdown(
                                  third: index + 1,
                                  isOpen: openIndex == index,
                                  onToggle: () => toggle(index),
                                )
                              : CustomPartsDropdown(
                                  part: GeneralController().parts[index],
                                  isOpen: openIndex == index,
                                  onToggle: () => toggle(index),
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

  Widget _buildSegmentItem(BuildContext context, String title, int view, GeneralProvider provider) {
    bool isSelected = provider.mainScreenView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _selectView(context, view);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryPurple : AppColors.uncategorizedColor,
            border: Border(
              right: view != FilterTypes.hizbs
                  ? BorderSide(color: Colors.grey.shade300)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.whiteFontColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _MainScreenStateCard extends StatelessWidget {
  const _MainScreenStateCard({
    required this.title,
    required this.body,
    this.child,
  });

  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 920),
      width: double.infinity,
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(height: 1.5),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
