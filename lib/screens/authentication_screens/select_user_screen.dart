import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../controllers/users_controller.dart';
import '../../core/auth/post_auth_navigation.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/ayat_provider.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/surahs_provider.dart';
import '../../providers/users_provider.dart';
import 'login_screen.dart';

class SelectUserScreen extends StatefulWidget {
  const SelectUserScreen({super.key, required this.firstScreen});
  final bool firstScreen;

  @override
  State<SelectUserScreen> createState() => _SelectUserScreenState();
}

class _SelectUserScreenState extends State<SelectUserScreen> {
  List<Map<String, dynamic>> _storedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoredUsers();
  }

  Future<void> _loadStoredUsers() async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final users = await usersProvider.getStoredDeviceUsers();
    if (!mounted) {
      return;
    }

    setState(() {
      _storedUsers = users;
      _isLoading = false;
    });

    // If no users, go straight to login
    if (_storedUsers.isEmpty) {
      Get.offAll(() => const LoginScreen(firstScreen: false));
    }
  }

  void _prepareLoginForUser(Map<String, dynamic> userData) {
    final email = userData['email'];

    if (email == null) {
      Get.snackbar(
        'خطأ',
        'بيانات المستخدم غير مكتملة',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    UsersController().loginEmailController.text = email.toString();
    UsersController().loginPasswordController.clear();
    Get.to(() => const LoginScreen(firstScreen: false));
  }

  Future<void> _resetUserScopedState() async {
    context.read<EvaluationsProvider>().resetForAccountSwitch();
    context.read<AyatProvider>().resetForAccountSwitch();
    context.read<SurahsProvider>().resetForAccountSwitch();
  }

  Future<void> _continueWithUser(Map<String, dynamic> userData) async {
    if (userData['isCurrent'] == true) {
      Get.back();
      return;
    }

    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final evaluationsProvider =
        Provider.of<EvaluationsProvider>(context, listen: false);

    if (userData['hasActiveSession'] == true) {
      setState(() {
        _isLoading = true;
      });

      final switched = await usersProvider.switchToStoredUser(userData);
      if (switched && usersProvider.selectedUser != null) {
        await _resetUserScopedState();
        await usersProvider.ensureReadingDisplayPreferencesLoaded(
          forceRefresh: true,
        );

        if (!mounted) {
          return;
        }

        await navigateAfterSuccessfulLogin(
          userId: usersProvider.selectedUser!.id,
          isFirstLogin: usersProvider.isFirstLogin,
          loadChartData: (userId) =>
              evaluationsProvider.getQuranChartData(userId),
        );
      return;
    }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      Get.snackbar(
        'switch_user'.tr,
        'انتهت جلسة هذا الحساب، يرجى تسجيل الدخول مرة أخرى.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }

    _prepareLoginForUser(userData);
  }

  Future<void> _removeUser(String email) async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    await usersProvider.removeUserFromDevice(email);
    await _loadStoredUsers(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    SizeConfig().init(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('select_account'.tr), // Select Account
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'choose_account_continue'.tr,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blackFontColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _storedUsers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _storedUsers[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppColors.uncategorizedColor,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: user['isCurrent'] == true
                                  ? AppColors.buttonColor.withValues(alpha: 0.15)
                                  : AppColors.uncategorizedColor,
                              child: Icon(
                                user['hasActiveSession'] == true
                                    ? Icons.bolt
                                    : Icons.person,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            title: Text(
                              user['fullName'] ?? 'مستخدم',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(user['email'] ?? ''),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (user['isCurrent'] == true)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                    if (user['isCurrent'] == true)
                                      const SizedBox(width: 4),
                                    Text(
                                      user['isCurrent'] == true
                                          ? 'الحساب الحالي'
                                          : user['hasActiveSession'] == true
                                              ? 'تبديل فوري متاح'
                                              : 'يتطلب تسجيل دخول',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: user['hasActiveSession'] == true
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: user['email'] == null
                                  ? null
                                  : () => _removeUser(user['email']),
                            ),
                            onTap: () => _continueWithUser(user),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.to(() => const LoginScreen(firstScreen: false));
                    },
                    icon: const Icon(Icons.add),
                    label: Text('login_another_account'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackFontColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
