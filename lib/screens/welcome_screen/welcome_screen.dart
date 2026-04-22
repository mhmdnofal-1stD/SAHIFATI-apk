import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import '../../controllers/evaluations_controller.dart';
import '../../core/utils/size_config.dart';
import '../../core/constants/colors.dart';
import '../questions_screen/questions_screen.dart';
import '../widgets/assessment_dimension_toggle.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text.dart';
import '../widgets/no_pop_scope.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    if (usersProvider.selectedUser != null) {
      await evaluationsProvider
          .getQuranChartData(usersProvider.selectedUser!.id);
      await evaluationsProvider.getAllEvaluations();

    }
  }

  @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: AppColors.backgroundColor,
  //     body: Column(
  //         mainAxisAlignment: MainAxisAlignment.start,
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           SizeConfig.customSizedBox(null, 6, null),
  //           const Directionality(
  //             textDirection: TextDirection.rtl,
  //             child: CustomText(
  //               text: 'أهلًا بك في صحيفتي!',
  //               fontWeight: FontWeight.bold,
  //               fontSize: 20,
  //               color: Colors.black,
  //               textAlign: TextAlign.center,
  //               withBackground: false,
  //             ),
  //           ),
  //           SizeConfig.customSizedBox(null, 20, null),
  //           Center(
  //             child: SizedBox(
  //                 width: SizeConfig.getProportionalWidth(300),
  //                 child: const CustomText(
  //                   text:
  //                   'سنقوم بطرح بعض الأسئلة السريعة\nلتكوين صحيفتك المبدئية.\nستبنى هذه الصحيفة على مدى إلمامك بالقرآن الكريم',
  //                   fontSize: 18,
  //                   structHeight: 1.35,
  //                   structLeading: 0.0,
  //                   textHeight: 1.35,
  //                   withBackground: false,
  //                 )),
  //           ),
  //           SizeConfig.customSizedBox(null, 20, null),
  //           Image.asset(Assets.quran),
  //           CustomButton(
  //             onPressed: () async {
  //               final schoolProvider = context.read<SchoolProvider>();
  //               final ayatProvider = context.read<AyatProvider>();
  //               final evaluationsProvider = context.read<EvaluationsProvider>();
  //
  //               await schoolProvider.getQuickQuestionsSchool();
  //               await ayatProvider.getQuickQuestionsAyatByLevel(1, 1);
  //               await evaluationsProvider.getAllEvaluations();
  //
  //               Get.to(const QuestionsScreen());
  //             },
  //             text: 'إبدأ التقييم',
  //             width: 106,
  //             height: 36,
  //           ),
  //
  //         ]),
  //   );
  // }

  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return NoPopScope(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: AppColors.backgroundColor,
            ),
          ),
        ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: SizeConfig.getProportionalHeight(50),
              bottom: SizeConfig.getProportionalHeight(20),
              right: SizeConfig.getProportionalWidth(10),
              left: SizeConfig.getProportionalWidth(10),
            ),
            child: Column(
              children: [
                Center(
                  child: SizedBox(
                      width: SizeConfig.getProportionalWidth(300),
                      child: CustomText(
                        text: "welcome_msg".tr,
                        fontSize: 18,
                        structHeight: 1.35,
                        structLeading: 0.0,
                        textHeight: 1.35,
                        withBackground: false,
                        textAlign: TextAlign.center,
                      )),
                ),
                SizeConfig.customSizedBox(null, 10, null),
                Consumer2<EvaluationsProvider, UsersProvider>(
                  builder: (context, evaluationsProvider, usersProvider, child) {
                    return AssessmentDimensionToggle(
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
                    );
                  },
                ),
                SizeConfig.customSizedBox(null, 10, null),
                Consumer<EvaluationsProvider>(
                  builder: (context, evaluationsProvider, child) {
                    List<PieChartSectionData> sections = [];

                    if (evaluationsProvider.chartEvaluationData.isEmpty) {
                      sections = [
                        PieChartSectionData(
                          value: 100,
                          color: AppColors.uncategorizedColor,
                          radius: 150,
                        ),
                      ];
                    } else {
                      sections = EvaluationsController()
                          .buildChartSections(evaluationsProvider);
                    }

                    return SizedBox(
                        width: SizeConfig.getProportionalWidth(300),
                        height: SizeConfig.getProportionalHeight(300),
                        child: PieChart(PieChartData(
                          sectionsSpace: 1,
                          centerSpaceRadius: 0,
                          sections: sections,
                        )));
                  },
                ),
                SizeConfig.customSizedBox(null, 10, null),
                CustomButton(
                  onPressed: () async {
                    final schoolProvider = context.read<SchoolProvider>();

                    await schoolProvider.getQuickQuestionsSchool();

                    Get.to(const QuestionsScreen());
                  },
                  text: 'start_evaluation'.tr,
                  width: 106,
                  height: 36,
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
