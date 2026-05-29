import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/soft_pattern_background.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/utils/size_config.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/general_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TapGestureRecognizer _emailRecognizer;
  late TapGestureRecognizer _websiteRecognizer;

  @override
  void initState() {
    super.initState();
    _emailRecognizer = TapGestureRecognizer()..onTap = _launchEmail;
    _websiteRecognizer = TapGestureRecognizer()..onTap = _launchWebsite;
  }

  @override
  void dispose() {
    _emailRecognizer.dispose();
    _websiteRecognizer.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'info@sahifati.com',
      query: 'subject=Feedback',
    );
    try {
      if (!await launchUrl(emailLaunchUri) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings_email_client_error'.tr),
          ),
        );
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  Future<void> _launchWebsite() async {
    final uri = Uri.parse('https://sahifati.org');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('notifications_cta_launch_failed'.tr),
          ),
        );
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftPatternBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const CustomBackButton(),
            title: Text(
              'settings'.tr,
              style: AppTypography.of(context)
                  .appBarTitle
                  .copyWith(color: AppColors.blackFontColor),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            children: [
              Consumer<GeneralProvider>(
                builder: (context, generalProvider, _) {
                  return SwitchListTile(
                    title: Text(
                      'dark_mode'.tr,
                      style: AppTypography.of(context).listTileTitle,
                    ),
                    value: generalProvider.themeMode == ThemeMode.dark,
                    onChanged: (_) {
                      generalProvider.toggleTheme();
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip,
                  color: AppColors.primaryPurple,
                ),
                title: Text(
                  'privacy_policy_title'.tr,
                  style: AppTypography.of(context).listTileTitle,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Get.to(() => const PrivacyPolicyScreen());
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.gavel,
                  color: AppColors.primaryPurple,
                ),
                title: Text(
                  'terms_of_service_title'.tr,
                  style: AppTypography.of(context).listTileTitle,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Get.to(() => const TermsOfServiceScreen());
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'delete_account'.tr,
                  style: AppTypography.of(context)
                      .listTileTitle
                      .copyWith(color: Colors.red),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: Text('delete_account_confirm_title'.tr),
                        content: Text('delete_account_confirm_message'.tr),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text('cancel'.tr),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: Text('confirm'.tr),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmed == true && context.mounted) {
                    try {
                      final usersProvider =
                          Provider.of<UsersProvider>(context, listen: false);
                      await usersProvider.deleteAccount();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('delete_account_success'.tr),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('delete_account_error'.tr),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const Divider(),
              SizeConfig.customSizedBox(null, 4, null),
              Padding(
                padding: EdgeInsets.only(
                  bottom: SizeConfig.getProportionalHeight(10),
                ),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTypography.of(context)
                            .bodyDefault
                            .copyWith(color: Colors.black),
                        children: [
                          TextSpan(text: '${'feedback'.tr} '),
                          TextSpan(
                            text: '  info@sahifati.com',
                            style:
                                AppTypography.of(context).bodyDefault.copyWith(
                                      decoration: TextDecoration.underline,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                            recognizer: _emailRecognizer,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTypography.of(context)
                            .bodyDefault
                            .copyWith(color: Colors.black54),
                        children: const [
                          TextSpan(text: 'sahifati.org'),
                        ],
                        recognizer: _websiteRecognizer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
