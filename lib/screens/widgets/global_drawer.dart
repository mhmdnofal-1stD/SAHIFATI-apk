import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../controllers/users_controller.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/users_provider.dart';
import '../cards_screen/cards_list_screen.dart';
import '../questions_screen/questions_screen.dart';
import '../settings_screen/manage_children_screen.dart';
import '../settings_screen/settings_screen.dart';
import '../authentication_screens/select_user_screen.dart';
import '../profile_screen/profile_screen.dart';
import '../supervision_screen/incoming_requests_screen.dart';
import '../user_overview_screen/user_overview_screen.dart';
import '../main_screen/main_screen.dart';
import '../../services/teacher_supervisions_services.dart';
import 'custom_text.dart';

Widget _buildDrawerTitle({
  required String text,
  required IconData icon,
  Color? color,
}) {
  return Row(
    textDirection: TextDirection.rtl,
    children: [
      Icon(
        icon,
        size: 30,
        color: color,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: CustomText(
          text: text,
          withBackground: false,
          color: color,
          textAlign: TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

List<Map<String, String>> _availableLanguages(LanguageProvider provider) {
  return provider.languages
      .where((language) =>
          (language['code'] ?? '').trim().isNotEmpty &&
          (language['name'] ?? '').trim().isNotEmpty)
      .map(
        (language) => {
          'code': language['code']!.trim().toLowerCase(),
          'name': language['name']!.trim(),
        },
      )
      .toList(growable: false);
}

Future<void> _openLanguagePicker(
  BuildContext context,
  LanguageProvider languageProvider,
) async {
  if (!languageProvider.isLoadingLanguages &&
      !languageProvider.hasFetchedLanguages) {
    await languageProvider.fetchLanguages();
  }

  if (!context.mounted) {
    return;
  }

  final languages = _availableLanguages(languageProvider);
  if (languages.isEmpty) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'language'.tr,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final language in languages)
              ListTile(
                title: Text(language['name']!),
                trailing:
                    language['code'] == languageProvider.langCode.toLowerCase()
                        ? Icon(
                            Icons.check,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          )
                        : null,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await languageProvider.changeLanguage(language['code']!);
                },
              ),
          ],
        ),
      );
    },
  );
}

class GlobalDrawer extends StatelessWidget {
  const GlobalDrawer({
    super.key,
    this.guestMode = false,
  });

  final bool guestMode;

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
                  Get.offAllNamed(UserOverviewScreen.routeName);
                },
                title: _buildDrawerTitle(
                  text: 'drawer_home'.tr,
                  icon: Icons.home_outlined,
                ),
              ),
              ListTile(
                onTap: () {
                  Get.offAllNamed(MainScreen.routeName);
                },
                title: _buildDrawerTitle(
                  text: 'صحيفتي',
                  icon: Icons.auto_stories_outlined,
                ),
              ),
              if (!guestMode)
                Consumer<UsersProvider>(
                  builder: (context, usersProvider, _) {
                    return _SupervisionDashboardTile(
                      hasDelegatedUser: usersProvider.hasPushedSelectedUser,
                    );
                  },
                ),
              ListTile(
                onTap: () async {
                  final evaluationsProvider =
                      context.read<EvaluationsProvider>();
                  final schoolProvider = context.read<SchoolProvider>();
                  await schoolProvider.getQuickQuestionsSchool();
                  if (!guestMode) {
                    await evaluationsProvider.getAllEvaluations();
                  }
                  Get.to(const QuestionsScreen());
                },
                title: _buildDrawerTitle(
                  text: 'quick_questions'.tr,
                  icon: Icons.question_answer_sharp,
                ),
              ),
              // ── حسابي (expandable) ────────────────────────────────────
              ExpansionTile(
                leading: const Icon(
                  Icons.account_circle_outlined,
                  size: 30,
                ),
                title: Text(
                  'drawer_profile'.tr,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 15),
                ),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsetsDirectional.only(start: 56, end: 16),
                    onTap: () => Get.to(() => const ProfileScreen()),
                    title: _buildDrawerTitle(
                      text: 'profile_screen_title'.tr,
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  ListTile(
                    contentPadding:
                        const EdgeInsetsDirectional.only(start: 56, end: 16),
                    onTap: () => Get.toNamed('/my-licenses'),
                    title: _buildDrawerTitle(
                      text: 'drawer_my_licenses'.tr,
                      icon: Icons.verified_outlined,
                    ),
                  ),
                  Consumer<UsersProvider>(
                    builder: (context, usersProvider, _) {
                      final user = usersProvider.activeAccountUser;
                      if (user == null || user.isChildAccount) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        contentPadding:
                            const EdgeInsetsDirectional.only(start: 56, end: 16),
                        onTap: () => Get.to(() => const ManageChildrenScreen()),
                        title: _buildDrawerTitle(
                          text: 'child_manage_settings_entry'.tr,
                          icon: Icons.family_restroom_rounded,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Consumer<UsersProvider>(
                builder: (context, usersProvider, _) {
                  final roleId = usersProvider.activeAccountUser?.userRoleId;
                  // Show cards management for all authenticated roles (1-5); hide for role 0 or unauthenticated
                  if (roleId == null || roleId == 0) {
                    return const SizedBox.shrink();
                  }
                  return ListTile(
                    onTap: () {
                      Get.toNamed(CardsListScreen.routeName);
                    },
                    title: _buildDrawerTitle(
                      text: 'drawer_cards'.tr,
                      icon: Icons.library_books_outlined,
                    ),
                  );
                },
              ),
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) {
                  return ListTile(
                    onTap: () => _openLanguagePicker(context, languageProvider),
                    title: _buildDrawerTitle(
                      text: 'language'.tr,
                      icon: Icons.language,
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
                title: _buildDrawerTitle(
                  text: 'switch_user'.tr,
                  icon: Icons.swap_horiz_rounded,
                ),
              ),
              ListTile(
                onTap: () {
                  Get.to(() => const SettingsScreen());
                },
                title: _buildDrawerTitle(
                  text: 'settings'.tr,
                  icon: Icons.settings,
                ),
              ),
              ListTile(
                onTap: () async {
                  final usersProvider = context.read<UsersProvider>();
                  await UsersController().logout(usersProvider);
                },
                title: _buildDrawerTitle(
                  text: 'logout'.tr,
                  icon: Icons.logout,
                  color: Colors.red,
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
  });

  final bool hasDelegatedUser;

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
    if (oldWidget.hasDelegatedUser != widget.hasDelegatedUser) {
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
      final teacherActiveCount =
          (limits['teacherActiveCount'] as num?)?.toInt() ?? 0;
      final studentActiveCount =
          (limits['studentActiveCount'] as num?)?.toInt() ?? 0;
      return requests.isNotEmpty ||
          teacherActiveCount > 0 ||
          studentActiveCount > 0 ||
          widget.hasDelegatedUser;
    } catch (_) {
      return widget.hasDelegatedUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _visibilityFuture,
      builder: (context, snapshot) {
        final canAccessSupervision = snapshot.data ?? widget.hasDelegatedUser;
        if (!canAccessSupervision) {
          return const SizedBox.shrink();
        }

        return ListTile(
          onTap: () {
            Get.toNamed(IncomingRequestsScreen.routeName);
          },
          title: _buildDrawerTitle(
            text: 'supervision_dashboard_screen_title'.tr,
            icon: Icons.space_dashboard_rounded,
          ),
        );
      },
    );
  }
}
