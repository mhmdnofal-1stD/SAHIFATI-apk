import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/no_pop_scope.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  late TapGestureRecognizer _emailRecognizer;

  @override
  void initState() {
    super.initState();
    _emailRecognizer = TapGestureRecognizer()..onTap = _launchEmail;
  }

  @override
  void dispose() {
    _emailRecognizer.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'info@sahifati.org',
      query: 'subject=Terms of Service Inquiry',
    );
    try {
      if (!await launchUrl(emailLaunchUri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('privacy_policy_open_email_error'.tr),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoPopScope(
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: AppColors.backgroundColor,
              elevation: 0,
              leading: const CustomBackButton(),
              title: Text(
                "terms_of_service_title".tr,
                style: AppTypography.of(context)
                    .appBarTitle
                    .copyWith(color: AppColors.blackFontColor),
              ),
              centerTitle: true,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "terms_of_service_last_update".tr,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Text(
                "terms_of_service_intro".tr,
                style: AppTypography.of(context)
                    .bodyDefault
                    .copyWith(color: AppColors.blackFontColor),
              ),
              const SizedBox(height: 25),
              _buildSection(
                "terms_of_service_section_1_title".tr,
                "terms_of_service_section_1_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_2_title".tr,
                "terms_of_service_section_2_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_3_title".tr,
                "terms_of_service_section_3_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_4_title".tr,
                "terms_of_service_section_4_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_5_title".tr,
                "terms_of_service_section_5_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_6_title".tr,
                "terms_of_service_section_6_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_7_title".tr,
                "terms_of_service_section_7_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_8_title".tr,
                "terms_of_service_section_8_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_9_title".tr,
                "terms_of_service_section_9_content".tr,
              ),
              _buildSection(
                "terms_of_service_section_10_title".tr,
                "terms_of_service_section_10_content".tr,
                isContact: true,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isContact = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.primaryPurple),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (isContact)
              RichText(
                text: TextSpan(
                  style: AppTypography.of(context)
                      .bodyDefault
                      .copyWith(color: AppColors.blackFontColor),
                  children: [
                    TextSpan(text: content),
                    const TextSpan(text: "\n"),
                    TextSpan(
                      text: "info@sahifati.org",
                      style: AppTypography.of(context).bodyDefault.copyWith(
                            color: Colors.red,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                      recognizer: _emailRecognizer,
                    ),
                  ],
                ),
              )
            else
              Text(
                content,
                style: AppTypography.of(context)
                    .bodyDefault
                    .copyWith(color: AppColors.blackFontColor),
              ),
          ],
        ],
      ),
    );
  }
}
