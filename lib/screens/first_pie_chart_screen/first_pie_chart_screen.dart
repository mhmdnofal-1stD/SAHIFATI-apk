import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/evaluations_controller.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../sahifa_screen/sahifa_screen.dart';
import '../widgets/assessment_dimension_toggle.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text.dart';
import '../widgets/no_pop_scope.dart';

class FirstPieChartScreen extends StatelessWidget {
  const FirstPieChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context);
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    final uncategorized =
        EvaluationsController().getEvaluationById(0, evaluationsProvider);
    final evaluatedPercentage =
        (100 - (uncategorized?.percentage ?? 0)).toStringAsFixed(2);
    final isComprehension = evaluationsProvider.chartDimension ==
      EvaluationsController.comprehensionDimension;

    return NoPopScope(
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        // trailing: const CustomBackButton(),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: SizeConfig.getProportionalHeight(50),
              bottom: SizeConfig.getProportionalHeight(55),
              right: SizeConfig.getProportionalWidth(10),
              left: SizeConfig.getProportionalWidth(10),
            ),
            child: Column(
              children: [
                const CustomText(
                  text: 'تهانينا! \n لقد أتممت التقييم الأولي',
                  textAlign: TextAlign.center,
                  fontSize: 24,
                  structHeight: 2,
                  withBackground: false,
                ),
                SizeConfig.customSizedBox(null, 5, null),
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
                SizeConfig.customSizedBox(null, 5, null),
                SizedBox(
                    width: 100,
                    height: 100,
                    child: PieChart(
                        PieChartData(
                      sectionsSpace: 1,
                      centerSpaceRadius: 30,
                      sections: EvaluationsController()
                          .buildChartSections(evaluationsProvider)
                          .map((section) {
                        final double adjustedValue =
                            section.value < 2.0 ? 2.0 : section.value;
                        return section.copyWith(value: adjustedValue);
                      }).toList(),
                    ))),
                SizeConfig.customSizedBox(null, 5, null),
                Text(
                  isComprehension
                      ? 'يعرض هذا المخطط الآيات التي تم تقييم فهمها فقط'
                      : 'لقد تم تصنيف $evaluatedPercentage% من آيات القرآن في صحيفتك',
                  textAlign: TextAlign.center,
                  locale: const Locale('ar'),
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
                SizeConfig.customSizedBox(null, 30, null),
                const Text(
                  'هذه الصحيفة هي نقطة البداية\nالعمل الحقيقي يبدأ الآن',
                  textAlign: TextAlign.center,
                  locale: Locale('ar'),
                  strutStyle: StrutStyle(
                    forceStrutHeight: true,
                    height: 1.35,
                    leading: 0.0,
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: SizeConfig.getProportionalHeight(50)),
                CustomButton(
                  onPressed: () => {Get.to( const SahifaScreen(firstScreen: false,))},
                  text: 'اذهب إلى صحيفتي',
                  width: 155,
                  height: 35,
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
