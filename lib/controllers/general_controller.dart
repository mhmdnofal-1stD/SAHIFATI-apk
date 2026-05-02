import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import 'package:quran/quran.dart' as quran;
import 'package:get/get.dart';

class GeneralController {
  // Dropdown options with text and associated color
  final List<Map<String, dynamic>> dropdownOptions = [
    {'id': 0, 'color': AppColors.uncategorizedColor},
    {'id': 1, 'color': AppColors.strongColor},
    {'id': 2, 'color': AppColors.revisionColor},
    {'id': 3, 'color': AppColors.desireColor},
    {'id': 4, 'color': AppColors.easyColor},
    {'id': 5, 'color': AppColors.hardColor},
    {'id': 67, 'color': AppColors.uncategorizedColor},
  ];

  List<Map<String, dynamic>> get parts => List.generate(30, (index) {
        final juzNumber = index + 1;
        final surahRange = _getSurahRangeInJuz(juzNumber);
        return {
          'id': juzNumber,
          'name': '${"juz_prefix".tr} $juzNumber\n$surahRange'
        };
      });

  String _getSurahRangeInJuz(int juzNumber) {
    try {
      Map<int, List<int>> surahs = quran.getSurahAndVersesFromJuz(juzNumber);
      List<int> surahNumbers = surahs.keys.toList()..sort();

      if (surahNumbers.isEmpty) return "";

      bool isArabic = Get.locale?.languageCode == 'ar';
      String separator = isArabic ? "، " : ", ";

      List<String> surahNames =
          surahNumbers.map((s) => quran.getSurahNameArabic(s)).toList();

      return "(${surahNames.join(separator)})";
    } catch (e) {
      return "";
    }
  }

  List<Map<String, dynamic>> get firstThird => parts.sublist(0, 10);
  List<Map<String, dynamic>> get secondThird => parts.sublist(10, 20);
  List<Map<String, dynamic>> get thirdThird => parts.sublist(20, 30);

  List<Map<String, dynamic>> get hizbList => List.generate(60,
      (index) => {'id': index + 1, 'name': '${"hizb_prefix".tr} ${index + 1}'});

  List<Map<String, dynamic>> get quranSurahs => List.generate(
      114,
      (index) =>
          {'id': index + 1, 'name': quran.getSurahNameArabic(index + 1)});

  String toArabicDigits(int n) => n
      .toString()
      .replaceAll('0', '٠')
      .replaceAll('1', '١')
      .replaceAll('2', '٢')
      .replaceAll('3', '٣')
      .replaceAll('4', '٤')
      .replaceAll('5', '٥')
      .replaceAll('6', '٦')
      .replaceAll('7', '٧')
      .replaceAll('8', '٨')
      .replaceAll('9', '٩');

  String ayahMarker(int n) => '\u2067\u06DD${toArabicDigits(n)}\u2069';

  Color getColorFromCategory(int category) {
    switch (category) {
      case 0:
        return AppColors.uncategorizedColor;
      case 1:
        return AppColors.strongColor;
      case 2:
        return AppColors.revisionColor;
      case 3:
        return AppColors.desireColor;
      case 4:
        return AppColors.easyColor;
      case 5:
        return AppColors.hardColor;
      default:
        return AppColors.uncategorizedColor;
    }
  }

  String toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join('');
  }

  Color getColorForOption(String? text) {
    if (text == null) return AppColors.uncategorizedColor;
    return dropdownOptions.firstWhere(
      (opt) => opt['text'] == text,
      orElse: () => {'color': AppColors.uncategorizedColor},
    )['color'];
  }

  String getStringLevel(level) {
    if (level >= 1 && level <= 6) {
      return 'level_$level'.tr;
    }
    return '';
  }

  Color getOnColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  Future<bool> checkConnectivity() async {
    final List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    return true;
  }

  String getSurahNameByNumber(int number) {
    if (number < 1 || number > 114)
      return 'surah_not_found'.tr; // Need key or hardcode? 'Not Found'
    return quran.getSurahNameArabic(number);
  }

  String getSurahNameArabic(int number) {
    if (number < 1 || number > 114) return "";
    return quran.getSurahNameArabic(number);
  }
}
