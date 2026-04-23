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
    final evaluationsProvider =
    context.read<EvaluationsProvider>();

    final usersProvider =
    context.read<UsersProvider>();
    final surahs =
        surahsProvider.hizbSurahs[hizb['id']] ?? [];
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    String text(String arabic, String english) => isArabic ? arabic : english;
    final isLoading = surahsProvider.isLoading && surahs.isEmpty;
    final hasError = surahsProvider.hizbLoadError != null && surahs.isEmpty;

    final surahNames = surahs
        .map((e) => quran.getSurahNameArabic(e.id))
        .join('، ');
    final subtitle = isLoading
        ? text('جارٍ تجهيز سور هذا الحزب...', 'Preparing this hizb...')
        : hasError
            ? text(
                'تعذر تجهيز هذا المسار الآن. حاول مرة أخرى بعد اكتمال التحميل.',
                'This path is not ready right now. Try again after loading completes.',
              )
            : surahs.isEmpty
                ? text(
                    'لا توجد سور جاهزة لهذا الحزب حاليًا.',
                    'No surahs are available for this hizb right now.',
                  )
                : surahNames;

    return GestureDetector(
      onTap: () {
        if (surahs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isLoading
                    ? text(
                        'ما زلنا نجهز سور هذا الحزب. أعد المحاولة بعد لحظة.',
                        'We are still preparing this hizb. Please try again in a moment.',
                      )
                    : hasError
                        ? text(
                            'تعذر تجهيز هذا الحزب الآن. جرّب إعادة فتح تبويب الأحزاب.',
                            'This hizb could not be prepared right now. Try reopening the hizbs tab.',
                          )
                        : text(
                            'لا توجد سور جاهزة لهذا الحزب الآن.',
                            'No surahs are ready for this hizb right now.',
                          ),
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

