import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../controllers/users_controller.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/users_provider.dart';
import '../questions_screen/questions_screen.dart';
import '../settings_screen/settings_screen.dart';
import '../authentication_screens/select_user_screen.dart';
import '../profile_screen/profile_screen.dart';
import '../supervision_screen/incoming_requests_screen.dart';
import '../welcome_screen/welcome_screen.dart';
import '../main_screen/main_screen.dart';
import 'custom_text.dart';

import '../cards_screen/cards_list_screen.dart';

class GlobalDrawer extends StatelessWidget {
  const GlobalDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final drawerWidth =
        screenSize.width < 480 ? screenSize.width * 0.78 : 280.0;
    final topPadding = screenSize.height < 700 ? 72.0 : 100.0;

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                onTap: () {
                  final usersProvider = context.read<UsersProvider>();
                  // إذا كنت في سياق طالب، استرجع المستخدم الأصلي
                  usersProvider.popSelectedUser();
                  Get.to(() => const ProfileScreen());
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: 'drawer_profile'.tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () {
                  Get.toNamed('/my-licenses');
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: 'drawer_my_licenses'.tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () {
                  Get.to(() => const SettingsScreen());
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.settings,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: "settings".tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () {
                  Get.to(() => const SettingsScreen());
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.language,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: "language".tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () async {
                  final evaluationsProvider =
                      context.read<EvaluationsProvider>();
                  final schoolProvider = context.read<SchoolProvider>();
                  await schoolProvider.getQuickQuestionsSchool();
                  await evaluationsProvider.getAllEvaluations();
                  Get.to(const QuestionsScreen());
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.question_answer_sharp,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: "quick_questions".tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              Consumer<UsersProvider>(
                builder: (context, usersProvider, _) {
                  final role = usersProvider.selectedUser?.userRoleId ?? 0;
                  if (role == 0) return const SizedBox.shrink();
                  return ListTile(
                    onTap: () {
                      Get.toNamed(CardsListScreen.routeName);
                    },
                    title: const Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        CustomText(
                          text: 'البطاقات العلمية',
                          withBackground: false,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Consumer<UsersProvider>(
                builder: (context, usersProvider, _) {
                  final role = usersProvider.selectedUser?.userRoleId ?? 0;
                  final canAccessSupervision = role == 1 || role == 2;
                  if (!canAccessSupervision) return const SizedBox.shrink();
                  return ListTile(
                    onTap: () {
                      Get.toNamed(IncomingRequestsScreen.routeName);
                    },
                    title: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(
                          Icons.space_dashboard_rounded,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        CustomText(
                          text: 'supervision_dashboard_screen_title'.tr,
                          withBackground: false,
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                onTap: () async {
                  final usersProvider = context.read<UsersProvider>();
                  final storedUsers =
                      await usersProvider.getStoredDeviceUsers();
                  if (storedUsers.isNotEmpty) {
                    Get.to(() => const SelectUserScreen(
                          firstScreen: false,
                        ));
                  } else {
                    Get.snackbar(
                      "switch_user".tr,
                      "no_users_to_display".tr, // fallback message
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                    );
                  }
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.people,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: "switch_user".tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () {
                  Get.offAllNamed(WelcomeScreen.routeName);
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.home_outlined,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: 'drawer_home'.tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () {
                  Get.offAllNamed(MainScreen.routeName);
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.auto_stories_outlined,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    CustomText(
                      text: 'drawer_browse'.tr,
                      withBackground: false,
                    ),
                  ],
                ),
              ),
              ListTile(
                onTap: () async {
                  final usersProvider = context.read<UsersProvider>();
                  await UsersController().logout(usersProvider);
                },
                title: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(
                      Icons.logout,
                      color: Colors.red,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'logout'.tr,
                      style: AppTypography.of(context)
                          .drawerItem
                          .copyWith(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
