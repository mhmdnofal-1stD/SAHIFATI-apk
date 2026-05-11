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
  final TextEditingController _childNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String? _inlineError;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _childNameController.text = widget.initialChildName?.trim() ?? '';
  }

  @override
  void dispose() {
    _guardianEmailController.dispose();
    _childNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _hasValidInput() {
    final guardianEmail = _guardianEmailController.text.trim();
    final childName = _childNameController.text.trim();
    final pin = _pinController.text.trim();

    if (guardianEmail.isEmpty || childName.isEmpty || pin.isEmpty) {
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

    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() {
        _inlineError = 'child_pin_not_set'.tr;
      });
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (_isBusy || !_hasValidInput()) {
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
        childName: _childNameController.text.trim(),
        pin: _pinController.text.trim(),
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
            hintText: 'child_login_child_name_hint'.tr,
            semanticLabel: 'child_login_child_name_label'.tr,
            leadingIcon: Icons.child_care_rounded,
            obscureText: false,
            textEditingController: _childNameController,
            borderColor: AppColors.textFieldBorderColor,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: fieldGap),
          CustomAuthenticationTextField(
            hintText: 'child_login_pin_hint'.tr,
            semanticLabel: 'child_login_pin_label'.tr,
            leadingIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textEditingController: _pinController,
            borderColor: AppColors.textFieldBorderColor,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
          ),
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
