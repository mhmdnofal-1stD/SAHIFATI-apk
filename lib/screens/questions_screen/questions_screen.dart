import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import '../../controllers/general_controller.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/users_provider.dart';
import '../sahifa_screen/sahifa_screen.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';
import 'content_item_card.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  int selectedIndex = 0;

  final ScrollController _scrollController = ScrollController();

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

    if (usersProvider.selectedUser == null) {
      return;
    }

    await evaluationsProvider.preloadQuestionLevelData(
      usersProvider.selectedUser!.id,
      schoolProvider.quickQuestionsSchool.levels[selectedIndex].content,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SchoolProvider schoolProvider = Provider.of<SchoolProvider>(context);
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context);
    LanguageProvider languageProvider = Provider.of<LanguageProvider>(context);
    final contentWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = contentWidth >= 900;
    final actionHeight = isDesktop ? 50.0 : 44.0;
    final skipWidth = isDesktop ? 140.0 : 110.0;
    final navigationWidth = isDesktop ? 190.0 : 150.0;
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
            title: CustomText(
              text:
                  '${'level_assessment'.tr} ${GeneralController().getStringLevel(selectedIndex + 1)} (${schoolProvider.quickQuestionsSchool.levels[selectedIndex].name![languageProvider.langCode]})',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              withBackground: true,
              color: const Color(0xFFFFFFFF),
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
      drawer: (Get.locale?.languageCode ?? 'ar') == 'ar' ? const GlobalDrawer() : null,
      endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar' ? null : const GlobalDrawer(),
      body: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: ResponsiveContentShell(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: SizeConfig.getProportionalHeight(0),
              horizontal: SizeConfig.getProportionalWidth(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (evaluationsProvider.isQuestionsLevelLoading)
                  const LinearProgressIndicator(minHeight: 3),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: schoolProvider
                        .quickQuestionsSchool.levels[selectedIndex].content.length,
                    itemBuilder: (context, index) {
                      final content = schoolProvider
                          .quickQuestionsSchool.levels[selectedIndex].content[index];
                      return ContentItemCard(
                        content: content,
                        index: index,
                        isCompleted:
                            evaluationsProvider.getQuestionContentCompletion(content),
                        isLoadingStatus:
                            evaluationsProvider.isQuestionsLevelLoading,
                      );
                    },
                  ),
                ),
                SizeConfig.customSizedBox(null, 15, null),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      CustomButton(
                        onPressed: () async {
                          UsersProvider usersProvider =
                              context.read<UsersProvider>();
                          await evaluationsProvider
                              .getQuranChartData(usersProvider.selectedUser!.id);
                          Get.to(const SahifaScreen(
                            firstScreen: false,
                          ));
                        },
                        text: "skip".tr,
                        width: skipWidth,
                        height: actionHeight,
                        isDisabled: false,
                      ),
                      CustomButton(
                        onPressed: () {
                          if (selectedIndex > 0) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                            setState(() {
                              selectedIndex = selectedIndex - 1;
                            });
                            _preloadSelectedLevel();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("you_are_at_first_level".tr),
                              ),
                            );
                          }
                        },
                        text: "previous_level".tr,
                        width: navigationWidth,
                        height: actionHeight,
                        isDisabled: false,
                      ),
                      CustomButton(
                        onPressed: () {
                          if (selectedIndex + 1 <
                              schoolProvider.quickQuestionsSchool.levels.length) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                            setState(() {
                              selectedIndex = selectedIndex + 1;
                            });
                            _preloadSelectedLevel();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("questions_finished".tr),
                              ),
                            );
                          }
                        },
                        text: "next_level".tr,
                        width: navigationWidth,
                        height: actionHeight,
                        isDisabled: false,
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
