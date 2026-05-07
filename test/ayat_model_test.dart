import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/surah.dart';

void main() {
  test('Ayat.fromJson normalizes mixed subject keys to strings', () {
    final ayah = Ayat.fromJson({
      '_id': 1,
      'ayahNo': 1,
      'text': 'بسم الله الرحمن الرحيم',
      'juz': 1,
      'hizb': 1,
      'hizbQuarter': 1,
      'page': 1,
      'wordCount': 4,
      'letterCount': 19,
      'weight': 1.0,
      'ayahType': 'Makki',
      'subjects': [108, 'dua'],
      'surah': {
        'id': 1,
        'nameAr': 'الفاتحة',
        'ayahCount': 7,
      },
    });

    expect(ayah.subjects, ['108', 'dua']);
  });

  test('Ayat.fromJson uses canonical mushaf page instead of stale payload page', () {
    final ayah = Ayat.fromJson({
      '_id': 1749,
      'ayahNo': 1,
      'text': 'الحمد لله الذي أنزل على عبده الكتاب',
      'juz': 15,
      'hizb': 30,
      'hizbQuarter': 57,
      'page': 294,
      'wordCount': 6,
      'letterCount': 28,
      'weight': 1.0,
      'ayahType': 'Makki',
      'subjects': const [],
      'surah': {
        'id': 18,
        'nameAr': 'الكهف',
        'ayahCount': 110,
      },
    });

    expect(ayah.page, quran.getPageNumber(18, 1));
  });

  test('Surah.displayName prefers localized name for active locale', () {
    final surah = Surah.fromJson({
      'id': 18,
      'nameAr': 'الكهف',
      'name': {
        'ar': 'الكهف',
        'en': 'Al-Kahf - The Cave',
        'fr': 'Al-Kahf - La Caverne',
      },
      'ayahCount': 110,
    });

    expect(surah.displayName(localeCode: 'en'), 'Al-Kahf - The Cave');
    expect(surah.displayName(localeCode: 'fr'), 'Al-Kahf - La Caverne');
    expect(surah.displayName(localeCode: 'ar'), 'الكهف');
  });
}