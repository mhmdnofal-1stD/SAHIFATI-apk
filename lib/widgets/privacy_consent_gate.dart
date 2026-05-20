import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/colors.dart';
import '../core/typography/app_typography.dart';
import '../screens/settings_screen/privacy_policy_screen.dart';

class PrivacyConsentGate extends StatefulWidget {
  const PrivacyConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

class _PrivacyConsentGateState extends State<PrivacyConsentGate> {
  static const String _privacyConsentKey =
      'privacy_policy_first_launch_acknowledged_v1';

  bool _checkedConsent = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _checkConsentStatus();
  }

  Future<void> _checkConsentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final acknowledged = prefs.getBool(_privacyConsentKey) ?? false;
    if (!mounted) {
      return;
    }

    _checkedConsent = true;
    if (!acknowledged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPrivacyConsentDialog();
        }
      });
    }
  }

  Future<void> _markConsentAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyConsentKey, true);
  }

  Future<void> _showPrivacyConsentDialog() async {
    if (_dialogVisible || !_checkedConsent || !mounted) {
      return;
    }

    final hostContext = Get.overlayContext;
    if (hostContext == null ||
        Navigator.maybeOf(hostContext, rootNavigator: true) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPrivacyConsentDialog();
        }
      });
      return;
    }

    _dialogVisible = true;
    await showDialog<void>(
      context: hostContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              'privacy_policy_title'.tr,
              style: AppTypography.of(dialogContext)
                  .sectionTitle
                  .copyWith(color: AppColors.blackFontColor),
              textAlign: TextAlign.right,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'يرجى قراءة سياسة الخصوصية عند أول تشغيل للتطبيق.\nPlease review the privacy policy before continuing.',
                  textAlign: TextAlign.right,
                  style: AppTypography.of(dialogContext)
                      .bodyDefault
                      .copyWith(color: AppColors.blackFontColor),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.panelColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lineColor),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'App: صحيفتي - Sahifati',
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Developer: مؤسسة البعد الأول لإدارة التطبيقات',
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Get.to(() => const PrivacyPolicyScreen());
                },
                child: Text('privacy_policy_title'.tr),
              ),
              FilledButton(
                onPressed: () async {
                  await _markConsentAccepted();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                ),
                child: const Text('Agree'),
              ),
            ],
          ),
        );
      },
    );
    _dialogVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}