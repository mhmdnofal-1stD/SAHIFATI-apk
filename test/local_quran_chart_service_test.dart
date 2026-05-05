import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart' as app_models;
import 'package:sahifaty/models/user_evaluation.dart';
import 'package:sahifaty/services/evaluations_services.dart';
import 'package:sahifaty/services/local_quran_chart_service.dart';

Ayat _buildAyah({
  required int id,
  required int surahId,
  required int ayahNo,
  required int juz,
  required int letterCount,
  String ayahType = 'Makki',
  List<String> subjects = const <String>[],
  List<Map<String, dynamic>> schoolLevels = const <Map<String, dynamic>>[],
}) {
  return Ayat.fromJson({
    '_id': id,
    'ayahNo': ayahNo,
    'text': 'آية $id',
    'juz': juz,
    'hizb': 1,
    'hizbQuarter': 1,
    'page': 1,
    'wordCount': 2,
    'letterCount': letterCount,
    'weight': 1.0,
    'ayahType': ayahType,
    'subjects': subjects,
    'schoolLevels': schoolLevels,
    'surah': {
      'id': surahId,
      'nameAr': 'سورة $surahId',
      'ayahCount': 10,
    },
  });
}

void main() {
  const service = LocalQuranChartService();

  test('buildChartPayload calculates offline memorization distribution', () {
    final allAyat = <Ayat>[
      _buildAyah(
        id: 1,
        surahId: 1,
        ayahNo: 1,
        juz: 1,
        letterCount: 10,
        subjects: const ['108'],
      ),
      _buildAyah(
        id: 2,
        surahId: 1,
        ayahNo: 2,
        juz: 1,
        letterCount: 20,
        subjects: const ['108'],
      ),
      _buildAyah(
        id: 3,
        surahId: 2,
        ayahNo: 1,
        juz: 2,
        letterCount: 30,
        subjects: const ['dua'],
      ),
    ];

    final userEvaluations = <UserEvaluation>[
      UserEvaluation(ayahId: 1, memoId: 7),
      UserEvaluation(ayahId: 2, memoId: 9),
    ];
    final evaluations = <app_models.Evaluation>[
      app_models.Evaluation(
        id: 7,
        code: 'G',
        name: const {'ar': 'متمكن', 'en': 'Strong'},
      ),
      app_models.Evaluation(
        id: 9,
        code: 'S',
        name: const {'ar': 'مراجعة', 'en': 'Review'},
      ),
    ];

    final payload = service.buildChartPayload(
      allAyat: allAyat,
      userEvaluations: userEvaluations,
      evaluations: evaluations,
      dimension: 'memorization',
      filters: const QuranChartFilters(subjectKeys: <String>['108']),
    );

    expect(payload['totalVerses'], 2);
    final chartEntries = (payload['evaluations'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    expect(chartEntries.length, 2);
    expect(chartEntries[0]['evaluationId'], 9);
    expect(chartEntries[0]['characterCount'], 20);
    expect(chartEntries[0]['verseCount'], 1);
    expect(chartEntries[0]['percentage'], 66.67);
    expect(chartEntries[1]['evaluationId'], 7);
    expect(chartEntries[1]['characterCount'], 10);
    expect(chartEntries[1]['verseCount'], 1);
    expect(chartEntries[1]['percentage'], 33.33);
  });

  test('filterAyat respects school level pairs offline', () {
    final filtered = service.filterAyat(
      <Ayat>[
        _buildAyah(
          id: 1,
          surahId: 1,
          ayahNo: 1,
          juz: 1,
          letterCount: 10,
          schoolLevels: const [
            {'schoolId': 1, 'schoolName': 'الاسئلة السريعة', 'level': 1},
          ],
        ),
        _buildAyah(
          id: 2,
          surahId: 1,
          ayahNo: 2,
          juz: 1,
          letterCount: 20,
          schoolLevels: const [
            {'schoolId': 1, 'schoolName': 'الاسئلة السريعة', 'level': 2},
          ],
        ),
      ],
      const QuranChartFilters(schoolLevelPairs: <String>['1:1']),
    );

    expect(filtered.map((ayah) => ayah.id).toList(growable: false), [1]);
  });
}