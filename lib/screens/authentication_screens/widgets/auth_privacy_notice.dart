import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../core/typography/app_typography.dart';
import '../../settings_screen/privacy_policy_screen.dart';

class AuthPrivacyNotice extends StatelessWidget {
  const AuthPrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primaryPurple,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'privacy_policy_title'.tr,
                  textAlign: TextAlign.right,
                  style: AppTypography.of(context)
                      .listTileTitle
                      .copyWith(color: AppColors.blackFontColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'بالمتابعة فأنت تقر بأنك اطلعت على سياسة الخصوصية الخاصة بتطبيق صحيفتي المطور بواسطة مؤسسة البعد الأول لإدارة التطبيقات.\nBy continuing, you acknowledge the privacy policy for Sahifati, developed by مؤسسة البعد الأول لإدارة التطبيقات.',
            textAlign: TextAlign.right,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Get.to(() => const PrivacyPolicyScreen()),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('privacy_policy_title'.tr),
            ),
          ),
        ],
      ),
    );
  }
}