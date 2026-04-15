import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../main_screen/main_screen.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text.dart';
import '../widgets/user_profile_badge.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';

class SahifaScreen extends StatelessWidget {
  const SahifaScreen({super.key, required this.firstScreen});

  final bool firstScreen;

  @override
  Widget build(BuildContext context) {
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context);
    LanguageProvider languageProvider = Provider.of<LanguageProvider>(context);
    final uncategorized =
        EvaluationsController().getEvaluationById(0, evaluationsProvider);
    final evaluatedPercentage =
        (100 - (uncategorized?.percentage ?? 0)).toStringAsFixed(2);
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: SizeConfig.getProportionalWidth(16),
                right: SizeConfig.getProportionalWidth(16),
                top: SizeConfig.getProportionalHeight(50),
                bottom: SizeConfig.getProportionalHeight(55),
              ),
              child: Column(
                children: [
                  CustomText(
                    text:
                        '${"well_done".tr} ${usersProvider.selectedUser?.fullName ?? ''}',
                    structHeight: 3,
                    textAlign: TextAlign.center,
                    fontSize: 24,
                    withBackground: false,
                  ),
                  BarChartWidget(
                    evaluationsProvider: evaluationsProvider,
                    languageProvider: languageProvider,
                  ),
                  SizedBox(
                    height: SizeConfig.getProportionalHeight(50),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      "categorized_verses_msg"
                          .trParams({'percentage': evaluatedPercentage}),
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
                  SizedBox(
                    height: SizeConfig.getProportionalHeight(50),
                  ),
                  CustomButton(
                    onPressed: () => {Get.to(const MainScreen())},
                    text: "browse_verses".tr,
                    width: 120,
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
