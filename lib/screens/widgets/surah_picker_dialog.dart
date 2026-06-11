import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../core/utils/size_config.dart';
import '../../core/utils/surah_localization.dart';

class SurahPickerDialog extends StatefulWidget {
  const SurahPickerDialog({super.key});

  /// Shows the picker and resolves to the selected surah number (1..114),
  /// or `null` if the user dismissed the dialog without picking.
  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (_) => const SurahPickerDialog(),
    );
  }

  @override
  State<SurahPickerDialog> createState() => _SurahPickerDialogState();
}

class _SurahPickerDialogState extends State<SurahPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    final query = _query.trim().toLowerCase();

    final entries = List<int>.generate(114, (index) => index + 1).where((id) {
      if (query.isEmpty) return true;
      final searchableNames = searchableSurahNamesById(
        id,
        localeCode: Get.locale?.languageCode,
      );
      return searchableNames.any(
            (name) => name.toLowerCase().contains(query),
          ) ||
          id.toString() == query;
    }).toList();

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: SizeConfig.getResponsiveDialogWidth(tabletMaxWidth: 520),
            maxHeight: SizeConfig.getResponsiveModalHeight(maxHeightPercent: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'surah_picker_title'.tr,
                        style: AppTypography.of(context).dialogTitle,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'surah_picker_search_hint'.tr,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'surah_picker_empty'.tr,
                          textAlign: TextAlign.center,
                          style: AppTypography.of(context).emptyStateBody,
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (_, index) {
                          final surahId = entries[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  AppColors.primaryPurple.withValues(alpha: 0.1),
                              child: Text(
                                surahId.toString(),
                                style: AppTypography.of(context)
                                    .badgeLabel
                                    .copyWith(color: AppColors.primaryPurple),
                              ),
                            ),
                            title: Text(
                              localizedSurahNameById(
                                surahId,
                                localeCode: Get.locale?.languageCode,
                              ),
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: AppTypography.of(context).listTileTitle,
                            ),
                            subtitle: Text(
                              'surah_picker_ayah_count'.trParams({
                                'count':
                                    quran.getVerseCount(surahId).toString(),
                              }),
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                            ),
                            onTap: () => Navigator.of(context).pop(surahId),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
