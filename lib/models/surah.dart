import '../core/utils/surah_localization.dart';

class Surah {
  final int id;
  final String nameAr;
  final Map<String, String> name;
  final int ayahCount;

  const Surah({
    required this.id,
    required this.nameAr,
    this.name = const {},
    required this.ayahCount,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'] ?? 0;
    final localizedName = <String, String>{};
    final rawName = json['name'];

    if (rawName is Map) {
      for (final entry in rawName.entries) {
        final value = entry.value?.toString().trim();
        if (value == null || value.isEmpty) {
          continue;
        }
        localizedName[entry.key.toString()] = value;
      }
    }

    final nameAr = json['nameAr']?.toString().trim() ?? '';
    if (nameAr.isNotEmpty) {
      localizedName.putIfAbsent('ar', () => nameAr);
    }

    return Surah(
      id: id,
      nameAr: nameAr,
      name: localizedName,
      ayahCount: canonicalAyahCountForSurah(
        id,
        fallbackAyahCount: json['ayahCount'] as int?,
      ),
    );
  }

  String displayName({String? localeCode}) {
    return localizedSurahName(
      surahId: id,
      fallbackArabicName: nameAr,
      localizedNames: name,
      localeCode: localeCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameAr': nameAr,
      'name': name,
      'ayahCount': ayahCount,
    };
  }
}
