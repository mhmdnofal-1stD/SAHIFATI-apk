import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/auth/post_auth_navigation.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../core/utils/size_config.dart';
import '../../providers/ayat_provider.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/surahs_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/no_pop_scope.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/custom_auth_footer.dart';
import 'child_login_screen.dart';

/// Resolves the human-facing identity for a stored device account row.
///
/// `username` is the live primary identity. When it is absent the caller
/// falls back to `email` and only then to a generic label. Legacy display-only
/// identity keys from older session caches are intentionally ignored so they
/// cannot resurrect a live identity after task139/task140/task142.
String resolveStoredAccountDisplayName(
  Map<String, dynamic> user, {
  required String fallback,
}) {
  final username = (user['username'] as String?)?.trim();
  if (username != null && username.isNotEmpty) {
    return username;
  }
  final email = (user['email'] as String?)?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }
  return fallback;
}

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
  }

  void _prepareLoginForUser(Map<String, dynamic> userData) {
    if (userData['authProvider'] == 'managed_child') {
      Get.to(
        () => ChildLoginScreen(
          initialChildName: resolveStoredAccountDisplayName(
            Map<String, dynamic>.from(userData),
            fallback: 'auth_saved_accounts_user_fallback'.tr,
          ),
        ),
      );
      return;
    }

    final email = userData['email'];

    if (email == null || (email as String).isEmpty) {
      Get.snackbar(
        'auth_saved_accounts_error_title'.tr,
        'auth_saved_accounts_incomplete_user_error'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.to(
      () => LoginScreen(
        firstScreen: false,
        initialEmail: email.toString(),
      ),
    );
  }

  Future<void> _resetUserScopedState() async {
    context.read<EvaluationsProvider>().resetForAccountSwitch();
    context.read<AyatProvider>().resetForAccountSwitch();
    context.read<SurahsProvider>().resetForAccountSwitch();
  }

  Future<void> _bootstrapAndEnterSelectedUser({
    required UsersProvider usersProvider,
    required EvaluationsProvider evaluationsProvider,
  }) async {
    final selectedUser = usersProvider.selectedUser;
    if (selectedUser == null) {
      throw Exception('auth_saved_accounts_session_expired'.tr);
    }

    await _resetUserScopedState();
    try {
      await usersProvider.ensureLicenseStateLoaded(
        forceRefresh: !usersProvider.hasKnownLicenseState,
      );
    } catch (error) {
      debugPrint('Saved-account bootstrap skipped license refresh: $error');
    }

    if (usersProvider.canProceedWithoutFreshLicenseCheck) {
      await usersProvider.ensureReadingDisplayPreferencesLoaded(
        forceRefresh: true,
      );
    }

    if (!mounted) {
      return;
    }

    await navigateAfterSuccessfulLogin(
      userId: selectedUser.id,
      isFirstLogin: usersProvider.isFirstLogin,
      hasActiveLicense: usersProvider.canProceedWithoutFreshLicenseCheck,
      loadChartData: (userId) => evaluationsProvider.getQuranChartData(userId),
    );
  }

  Future<void> _continueWithUser(Map<String, dynamic> userData) async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final evaluationsProvider =
        Provider.of<EvaluationsProvider>(context, listen: false);

    if (userData['isCurrent'] == true) {
      setState(() {
        _isLoading = true;
      });

      final hasReadyCurrentUser = usersProvider.selectedUser != null;
      final restoredCurrentUser = hasReadyCurrentUser
          ? true
          : await usersProvider.switchToStoredUser(userData);

      if (restoredCurrentUser && usersProvider.selectedUser != null) {
        await _bootstrapAndEnterSelectedUser(
          usersProvider: usersProvider,
          evaluationsProvider: evaluationsProvider,
        );
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      _prepareLoginForUser(userData);
      return;
    }

    if (userData['hasActiveSession'] == true) {
      setState(() {
        _isLoading = true;
      });

      final switched = await usersProvider.switchToStoredUser(userData);
      if (switched && usersProvider.selectedUser != null) {
        await _bootstrapAndEnterSelectedUser(
          usersProvider: usersProvider,
          evaluationsProvider: evaluationsProvider,
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
        'auth_saved_accounts_session_expired'.tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }

    _prepareLoginForUser(userData);
  }

  Future<void> _removeUserById(int userId) async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    await usersProvider.removeUserFromDeviceById(userId);
    await _loadStoredUsers();
  }

  Future<void> _removeUser(String email) async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    await usersProvider.removeUserFromDevice(email);
    await _loadStoredUsers(); // Refresh the list
  }

  void _openManualLogin() {
    Get.to(() => const LoginScreen(firstScreen: false));
  }

  void _openSignup() {
    Get.to(() => const SignUpScreen());
  }

  String _statusText(Map<String, dynamic> user) {
    if (user['isCurrent'] == true) {
      return 'auth_saved_accounts_current'.tr;
    }

    if (user['hasActiveSession'] == true) {
      return 'auth_saved_accounts_instant'.tr;
    }

    return 'auth_saved_accounts_requires_login'.tr;
  }

  Color _statusColor(Map<String, dynamic> user) {
    if (user['isCurrent'] == true) {
      return const Color(0xFF175CD3);
    }

    if (user['hasActiveSession'] == true) {
      return AppColors.successColor;
    }

    return const Color(0xFFB54708);
  }

  Color _cardBackground(Map<String, dynamic> user) {
    if (user['isCurrent'] == true) {
      return const Color(0xFFF5F8FF);
    }

    if (user['hasActiveSession'] == true) {
      return const Color(0xFFF4FBF7);
    }

    return const Color(0xFFFFFBF5);
  }

  Color _cardBorder(Map<String, dynamic> user) {
    if (user['isCurrent'] == true) {
      return const Color(0xFFD0DFFF);
    }

    if (user['hasActiveSession'] == true) {
      return const Color(0xFFCFE9D8);
    }

    return const Color(0xFFF3D6A8);
  }

  Widget _buildSummaryBlock() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'auth_saved_accounts_label'.tr,
            style: AppTypography.of(context).sectionTitle.copyWith(
                  fontSize: 16,
                  color: AppColors.primaryPurple,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3ECE0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2D8C8)),
          ),
          child: Text(
            'auth_saved_accounts_count'.trParams({
              'count': _storedUsers.length.toString(),
            }),
            style: AppTypography.of(context).badgeLabel.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF5E6B7D),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E0D2)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
          const SizedBox(height: 16),
          Text(
            'auth_saved_accounts_loading'.tr,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).bodySecondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4DACA)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.panelColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2D8C8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1013284A),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: AppColors.primaryPurple,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'auth_saved_accounts_empty_title'.tr,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).subsectionTitle.copyWith(
                  color: AppColors.primaryPurple,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'auth_saved_accounts_empty_body'.tr,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).bodySecondary.copyWith(
                  fontSize: 13,
                  color: const Color(0xFF5E6B7D),
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoredUserCard(Map<String, dynamic> user) {
    final statusColor = _statusColor(user);
    final userId = user['id'];
    final isChild = user['authProvider'] == 'managed_child';
    final hasEmail = user['email'] != null &&
        (user['email'] as String).isNotEmpty;

    return Material(
      color: _cardBackground(user),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _isLoading ? null : () => _continueWithUser(user),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder(user)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F172A),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            user['hasActiveSession'] == true
                                ? Icons.bolt_rounded
                                : Icons.person_outline_rounded,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        if (isChild)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.successColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.child_care_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolveStoredAccountDisplayName(
                            Map<String, dynamic>.from(user),
                            fallback:
                                'auth_saved_accounts_user_fallback'.tr,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.of(context)
                              .userDisplayName
                              .copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryPurple,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (user['email'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.of(context)
                              .listTileSubtitle
                              .copyWith(
                                color: const Color(0xFF6C7280),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'auth_saved_accounts_remove'.tr,
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF7A808A)),
                    onPressed: userId != null
                        ? () => _removeUserById(
                              userId is int
                                  ? userId
                                  : int.tryParse(userId.toString()) ?? 0,
                            )
                        : hasEmail
                            ? () => _removeUser(user['email'].toString())
                            : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusText(user),
                      style: AppTypography.of(context).badgeLabel.copyWith(
                            fontSize: 11,
                            color: statusColor,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'auth_saved_accounts_continue'.tr,
                    style: AppTypography.of(context).buttonSecondary.copyWith(
                          fontSize: 12,
                          color: AppColors.primaryPurple,
                        ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.primaryPurple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return NoPopScope(
      child: AuthScreenShell(
        title: 'auth_account_selector_title'.tr,
        subtitle: 'auth_account_selector_subtitle'.tr,
        isSignup: false,
        maxWidth: 560,
        onSelectSignup: _isLoading ? null : _openSignup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading)
              _buildLoadingState()
            else ...[
              if (_storedUsers.isEmpty)
                _buildEmptyState()
              else ...[
                _buildSummaryBlock(),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _storedUsers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildStoredUserCard(_storedUsers[index]),
                ),
              ],
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _openManualLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  disabledBackgroundColor:
                      AppColors.primaryPurple.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: Text(
                  'auth_saved_accounts_manual_login'.tr,
                  style: AppTypography.of(context).buttonPrimary.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: CustomAuthFooter(
                actionText: 'auth_saved_accounts_create_account'.tr,
                icon: Icons.person_add_alt_1_rounded,
                onTap: _isLoading ? null : _openSignup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
