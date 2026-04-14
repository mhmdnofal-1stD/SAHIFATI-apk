import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/screens/sahifa_screen/sahifa_screen.dart';
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
import '../widgets/custom_text.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.comesFirst = false});

  final bool comesFirst;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int? openIndex;

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
    if (widget.comesFirst) {
      SizeConfig().init(context);
    }
    final generalProvider = Provider.of<GeneralProvider>(context);
    final usersProvider = Provider.of<UsersProvider>(context);
    final evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    final surahsProvider = Provider.of<SurahsProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

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
            body: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: SizeConfig.getProportionalWidth(75),
                right: SizeConfig.getProportionalWidth(35),
                top: SizeConfig.getProportionalHeight(20),
                bottom: SizeConfig.getProportionalHeight(55),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomText(
                    text:
                        '${"well_done".tr} ${usersProvider.selectedUser?.fullName ?? ''}',
                    structHeight: 3,
                    textAlign: TextAlign.center,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    withBackground: false,
                  ),

                  SizedBox(height: SizeConfig.getProportionalHeight(20)),

                  // SEGMENTED FILTER
                  Container(
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

                    BarChartWidget(evaluationsProvider: evaluationsProvider, languageProvider: languageProvider,)
                  else
                    SizedBox(height: SizeConfig.getProportionalHeight(250)),

                  SizedBox(height: SizeConfig.getProportionalHeight(20)),

                  if (generalProvider.mainScreenView == FilterTypes.hizbs &&
                      surahsProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 50.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (generalProvider.mainScreenView == FilterTypes.hizbs)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        child: generalProvider.mainScreenView == FilterTypes.thirds
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
          );
  }

  Widget _buildSegmentItem(BuildContext context, String title, int view, GeneralProvider provider) {
    bool isSelected = provider.mainScreenView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          provider.setView(view);
          if (view == FilterTypes.hizbs) {
            context.read<SurahsProvider>().loadAllHizbSurahs(GeneralController().hizbList);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
