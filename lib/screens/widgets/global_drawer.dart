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
import '../../services/teacher_supervisions_services.dart';
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
                  return _SupervisionDashboardTile(
                    hasDelegatedUser: usersProvider.hasPushedSelectedUser,
                    fallbackRole: usersProvider.selectedUser?.userRoleId ?? 0,
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

class _SupervisionDashboardTile extends StatefulWidget {
  const _SupervisionDashboardTile({
    required this.hasDelegatedUser,
    required this.fallbackRole,
  });

  final bool hasDelegatedUser;
  final int fallbackRole;

  @override
  State<_SupervisionDashboardTile> createState() =>
      _SupervisionDashboardTileState();
}

class _SupervisionDashboardTileState extends State<_SupervisionDashboardTile> {
  final TeacherSupervisionsService _service = TeacherSupervisionsService();
  late Future<bool> _visibilityFuture;

  @override
  void initState() {
    super.initState();
    _visibilityFuture = _loadVisibility();
  }

  @override
  void didUpdateWidget(covariant _SupervisionDashboardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasDelegatedUser != widget.hasDelegatedUser ||
        oldWidget.fallbackRole != widget.fallbackRole) {
      _visibilityFuture = _loadVisibility();
    }
  }

  Future<bool> _loadVisibility() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.listIncomingRequests(),
        _service.getLimits(),
      ]);
      final requests = results[0] as List<Map<String, dynamic>>;
      final limits = results[1] as Map<String, dynamic>;
      final teacherActiveCount = (limits['teacherActiveCount'] as num?)?.toInt() ?? 0;
      final studentActiveCount = (limits['studentActiveCount'] as num?)?.toInt() ?? 0;
      return requests.isNotEmpty ||
          teacherActiveCount > 0 ||
          studentActiveCount > 0 ||
          widget.hasDelegatedUser;
    } catch (_) {
      return widget.hasDelegatedUser ||
          widget.fallbackRole == 1 ||
          widget.fallbackRole == 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _visibilityFuture,
      builder: (context, snapshot) {
        final canAccessSupervision = snapshot.data ??
            widget.hasDelegatedUser ||
            widget.fallbackRole == 1 ||
            widget.fallbackRole == 2;
        if (!canAccessSupervision) {
          return const SizedBox.shrink();
        }

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
    );
  }
}
