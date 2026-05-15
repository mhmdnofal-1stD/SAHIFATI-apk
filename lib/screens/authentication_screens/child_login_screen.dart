import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/auth/post_auth_navigation.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import 'widgets/auth_screen_shell.dart';
import 'widgets/custom_auth_textfield.dart';

class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({
    super.key,
    this.initialChildName,
  });

  final String? initialChildName;

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final TextEditingController _guardianEmailController =
      TextEditingController();
  final TextEditingController _guardianPasswordController =
      TextEditingController();

  List<Map<String, dynamic>> _childOptions = [];
  String? _selectedChildId;
  String? _inlineError;
  bool _isBusy = false;
  bool _isLoadingChildren = false;

  @override
  void initState() {
    super.initState();
    _guardianEmailController.addListener(_resetLoadedChildren);
    _guardianPasswordController.addListener(_resetLoadedChildren);
  }

  @override
  void dispose() {
    _guardianEmailController.removeListener(_resetLoadedChildren);
    _guardianPasswordController.removeListener(_resetLoadedChildren);
    _guardianEmailController.dispose();
    _guardianPasswordController.dispose();
    super.dispose();
  }

  void _resetLoadedChildren() {
    if (!_childOptions.isNotEmpty && _selectedChildId == null && _inlineError == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _childOptions = [];
      _selectedChildId = null;
      _inlineError = null;
    });
  }

  String _childId(Map<String, dynamic> child) {
    return child['childId']?.toString() ??
        child['userId']?.toString() ??
        child['id']?.toString() ??
        '';
  }

  String _childUsername(Map<String, dynamic> child) {
    return child['username']?.toString() ??
        child['displayName']?.toString() ??
        '';
  }

  String? _resolveInitialChildId(List<Map<String, dynamic>> children) {
    final initialName = widget.initialChildName?.trim().toLowerCase();
    if (initialName == null || initialName.isEmpty) {
      return null;
    }

    for (final child in children) {
      if (_childUsername(child).trim().toLowerCase() == initialName) {
        final childId = _childId(child);
        if (childId.isNotEmpty) {
          return childId;
        }
      }
    }

    return null;
  }

  bool _hasValidGuardianCredentials() {
    final guardianEmail = _guardianEmailController.text.trim();
    final password = _guardianPasswordController.text;

    if (guardianEmail.isEmpty || password.isEmpty) {
      setState(() {
        _inlineError = 'all_fields_required'.tr;
      });
      return false;
    }

    if (!GetUtils.isEmail(guardianEmail)) {
      setState(() {
        _inlineError = 'invalid_email'.tr;
      });
      return false;
    }

    return true;
  }

  Future<void> _loadChildOptions() async {
    if (_isBusy || _isLoadingChildren || !_hasValidGuardianCredentials()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);

    setState(() {
      _isLoadingChildren = true;
      _inlineError = null;
    });

    try {
      final options = await usersProvider.getChildLoginOptions(
        guardianEmail: _guardianEmailController.text.trim(),
        password: _guardianPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      final initialChildId = _resolveInitialChildId(options);
      setState(() {
        _childOptions = options;
        _selectedChildId = initialChildId ??
            (options.length == 1 ? _childId(options.first) : null);
        _inlineError = options.isEmpty ? 'child_login_no_children'.tr : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineError = usersProvider.extractErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChildren = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }

    if (_childOptions.isEmpty) {
      await _loadChildOptions();
      return;
    }

    if (!_hasValidGuardianCredentials()) {
      return;
    }

    final childId = _selectedChildId?.trim() ?? '';
    if (childId.isEmpty) {
      setState(() {
        _inlineError = 'child_login_child_required'.tr;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final evaluationsProvider =
        Provider.of<EvaluationsProvider>(context, listen: false);

    setState(() {
      _isBusy = true;
      _inlineError = null;
    });

    try {
      final authData = await usersProvider.loginAsChild(
        guardianEmail: _guardianEmailController.text.trim(),
        password: _guardianPasswordController.text,
        childId: childId,
      );

      await usersProvider.finalizeAuthenticatedUser(authData);
      TextInput.finishAutofillContext(shouldSave: false);

      if (!mounted || usersProvider.selectedUser == null) {
        return;
      }

      await navigateAfterSuccessfulLogin(
        userId: usersProvider.selectedUser!.id,
        isFirstLogin: usersProvider.isFirstLogin,
        hasActiveLicense: usersProvider.hasActiveLicense,
        loadChartData: (userId) => evaluationsProvider.getQuranChartData(userId),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineError = usersProvider.extractErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Widget _buildInlineErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context).inputError,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final isCompactPhone = mediaSize.shortestSide < 600;
    final fieldGap = isCompactPhone ? 8.0 : 14.0;
    final bodyGap = isCompactPhone ? 12.0 : 18.0;
    final primaryActionGap = isCompactPhone ? 14.0 : 18.0;

    return AuthScreenShell(
      title: 'child_login_title'.tr,
      subtitle: 'child_login_subtitle'.tr,
      isSignup: false,
      showHeading: true,
      fillViewport: true,
      preferCompactMobileLayout: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CustomBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(height: bodyGap),
          Text(
            'child_login_help'.tr,
            textAlign: TextAlign.center,
            style: AppTypography.of(context).bodySecondary.copyWith(
                  color: AppColors.mutedText,
                  height: 1.5,
                ),
          ),
          SizedBox(height: bodyGap),
          CustomAuthenticationTextField(
            hintText: 'child_login_guardian_email_hint'.tr,
            semanticLabel: 'child_login_guardian_email_label'.tr,
            leadingIcon: Icons.alternate_email_rounded,
            obscureText: false,
            textEditingController: _guardianEmailController,
            borderColor: AppColors.textFieldBorderColor,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          SizedBox(height: fieldGap),
          CustomAuthenticationTextField(
            hintText: 'child_login_guardian_password_hint'.tr,
            semanticLabel: 'child_login_guardian_password_label'.tr,
            leadingIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textEditingController: _guardianPasswordController,
            borderColor: AppColors.textFieldBorderColor,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
          ),
          SizedBox(height: fieldGap),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: (_isBusy || _isLoadingChildren) ? null : _loadChildOptions,
              icon: _isLoadingChildren
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.1),
                    )
                  : const Icon(Icons.badge_outlined),
              label: Text('child_login_load_children'.tr),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          if (_childOptions.isNotEmpty) ...[
            SizedBox(height: fieldGap),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedChildId ?? _childOptions.length),
              initialValue: _selectedChildId,
              decoration: InputDecoration(
                labelText: 'child_login_children_label'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                prefixIcon: const Icon(
                  Icons.child_care_rounded,
                  color: AppColors.primaryPurple,
                ),
                filled: true,
                fillColor: AppColors.panelColor,
              ),
              items: _childOptions
                  .map(
                    (child) => DropdownMenuItem<String>(
                      value: _childId(child),
                      child: Text(_childUsername(child)),
                    ),
                  )
                  .toList(),
              onChanged: _isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedChildId = value;
                        _inlineError = null;
                      });
                    },
            ),
          ],
          if (_inlineError != null) ...[
            SizedBox(height: fieldGap),
            _buildInlineErrorBanner(_inlineError!),
          ],
          SizedBox(height: primaryActionGap),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                disabledBackgroundColor:
                    AppColors.primaryPurple.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(Icons.login_rounded, color: Colors.white),
              label: Text(
                'child_login_action'.tr,
                style: AppTypography.of(context)
                    .buttonPrimary
                    .copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
