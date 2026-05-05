import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/models/ayat.dart';

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
}