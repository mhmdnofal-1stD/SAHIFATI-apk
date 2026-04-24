import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/surahs_provider.dart';
import '../../providers/users_provider.dart';
import '../quran_view/index_page.dart';
import 'custom_text.dart';
import 'package:quran/quran.dart' as quran;

class CustomHizbsButton extends StatelessWidget {
  final Map<String, dynamic> hizb;

  const CustomHizbsButton({
    super.key,
    required this.hizb,
  });

  @override
  Widget build(BuildContext context) {
    final surahsProvider = context.watch<SurahsProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    final usersProvider = context.read<UsersProvider>();
    final surahs = surahsProvider.hizbSurahs[hizb['id']] ?? [];
    final isLoading = surahsProvider.isLoading && surahs.isEmpty;
    final hasError = surahsProvider.hizbLoadError != null && surahs.isEmpty;

    final surahNames = surahs
        .map((e) => quran.getSurahNameArabic(e.id))
        .join('، ');
    final subtitle = isLoading
      ? 'custom_hizb_preparing'.tr
        : hasError
        ? 'custom_hizb_error_subtitle'.tr
            : surahs.isEmpty
          ? 'custom_hizb_empty_subtitle'.tr
                : surahNames;

    return GestureDetector(
      onTap: () {
        if (surahs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isLoading
                    ? 'custom_hizb_loading_snackbar'.tr
                    : hasError
                        ? 'custom_hizb_error_snackbar'.tr
                        : 'custom_hizb_empty_snackbar'.tr,
              ),
            ),
          );
          return;
        }

        final surah = surahs.first;

        Get.to(
          IndexPage(
            surah: surah,
            filterTypeId: 3,
            hizb: hizb['id'],
          ),
        )?.then((_) {
          evaluationsProvider.getQuranChartData(
              usersProvider.selectedUser!.id);
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.getProportionalWidth(12),
          vertical: SizeConfig.getProportionalHeight(4),
        ),
        decoration: BoxDecoration(
          color: surahs.isEmpty ? AppColors.uncategorizedColor : AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(
                text: hizb['name'],
                fontSize: 15,
                color: Colors.white,
                withBackground: false,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              CustomText(
                text: subtitle,
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.92),
                withBackground: false,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

