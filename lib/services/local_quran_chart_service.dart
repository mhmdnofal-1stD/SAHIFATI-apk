import '../models/ayat.dart';
import '../models/evaluation.dart';
import '../models/user_evaluation.dart';
import 'evaluations_services.dart';

class LocalQuranChartService {
  const LocalQuranChartService();

  Map<String, dynamic> buildChartPayload({
    required List<Ayat> allAyat,
    required List<UserEvaluation> userEvaluations,
    required List<Evaluation> evaluations,
    String dimension = 'memorization',
    QuranChartFilters filters = const QuranChartFilters(),
    Set<int>? allowedSchoolAyahIds,
  }) {
    final relevantAyat = filterAyat(
      allAyat,
      filters,
      allowedSchoolAyahIds: allowedSchoolAyahIds,
    );
    final evaluationsByAyahId = _latestEvaluationsByAyahId(userEvaluations);

    final filteredAyat = relevantAyat.where((ayah) {
      final ayahId = ayah.id;
      final evaluation = ayahId == null ? null : evaluationsByAyahId[ayahId];

      if (filters.memoEvaluationIds.isNotEmpty) {
        final memoId = evaluation?.memoId ?? 0;
        if (!filters.memoEvaluationIds.contains(memoId)) {
          return false;
        }
      }

      if (filters.comprehensionEvaluationIds.isNotEmpty) {
        final compreId = evaluation?.compreId ?? 0;
        if (!filters.comprehensionEvaluationIds.contains(compreId)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);

    final totalCharacters = filteredAyat.fold<int>(
      0,
      (sum, ayah) => sum + (ayah.letterCount ?? 0),
    );
    final totalVerses = filteredAyat.length;

    if (totalVerses == 0) {
      return {
        'dimension': dimension,
        'totalCharacters': 0,
        'totalVerses': 0,
        'evaluations': const <Map<String, dynamic>>[],
        'filters': filters.toQueryParameters(),
      };
    }

    final evaluationCharacterCounts = <int, int>{};
    final evaluationVerseCounts = <int, int>{};
    final evaluatedAyahIds = <int>{};

    for (final ayah in filteredAyat) {
      final ayahId = ayah.id;
      if (ayahId == null) {
        continue;
      }

      final evaluation = evaluationsByAyahId[ayahId];
      final evaluationId = dimension == 'comprehension'
          ? (evaluation?.compreId ?? 0)
          : (evaluation?.memoId ?? 0);

      if (evaluationId > 0) {
        final letterCount = ayah.letterCount ?? 0;
        evaluationCharacterCounts[evaluationId] =
            (evaluationCharacterCounts[evaluationId] ?? 0) + letterCount;
        evaluationVerseCounts[evaluationId] =
            (evaluationVerseCounts[evaluationId] ?? 0) + 1;
        evaluatedAyahIds.add(ayahId);
      }
    }

    final evaluationMap = {
      for (final evaluation in evaluations)
        if (evaluation.id != null) evaluation.id!: evaluation,
    };
    final denominator = totalCharacters == 0 ? 1 : totalCharacters;

    final result = evaluationCharacterCounts.entries
        .map((entry) {
          final evaluation = evaluationMap[entry.key];
          final verseCount = evaluationVerseCounts[entry.key] ?? 0;
          return {
            'evaluationId': entry.key,
            'name': evaluation?.name ?? const {'ar': 'غير مصنف'},
            'code': evaluation?.code ?? '!',
            'color': evaluation?.color,
            'characterCount': entry.value,
            'verseCount': verseCount,
            'percentage':
                double.parse(((entry.value / denominator) * 100).toStringAsFixed(2)),
          };
        })
        .toList(growable: true);

    final unevaluatedAyat = filteredAyat
        .where((ayah) => ayah.id == null || !evaluatedAyahIds.contains(ayah.id))
        .toList(growable: false);
    if (unevaluatedAyat.isNotEmpty) {
      final unevaluatedCharacterCount = unevaluatedAyat.fold<int>(
        0,
        (sum, ayah) => sum + (ayah.letterCount ?? 0),
      );
      result.add({
        'evaluationId': 0,
        'name': const {'ar': 'غير مصنف'},
        'code': '!',
        'color': null,
        'characterCount': unevaluatedCharacterCount,
        'verseCount': unevaluatedAyat.length,
        'percentage': double.parse(
          ((unevaluatedCharacterCount / denominator) * 100).toStringAsFixed(2),
        ),
      });
    }

    result.sort((left, right) =>
        (right['characterCount'] as int).compareTo(left['characterCount'] as int));

    return {
      'dimension': dimension,
      'totalCharacters': totalCharacters,
      'totalVerses': totalVerses,
      'evaluations': result,
      'filters': filters.toQueryParameters(),
    };
  }

  List<Ayat> filterAyat(
    List<Ayat> allAyat,
    QuranChartFilters filters, {
    Set<int>? allowedSchoolAyahIds,
  }) {
    final effectiveJuzs = _effectiveJuzs(filters).toSet();
    final surahIds = filters.surahIds.toSet();
    final ayahTypes = filters.ayahTypes.toSet();
    final subjectKeys = filters.subjectKeys.toSet();
    final schoolLevelPairs = filters.schoolLevelPairs.toSet();
    final schoolIds = filters.schoolIds.toSet();

    return allAyat.where((ayah) {
      if (surahIds.isNotEmpty && !surahIds.contains(ayah.surah.id)) {
        return false;
      }
      if (effectiveJuzs.isNotEmpty && !effectiveJuzs.contains(ayah.juz)) {
        return false;
      }
      if (ayahTypes.isNotEmpty && !ayahTypes.contains(ayah.ayahType ?? '')) {
        return false;
      }
      if (subjectKeys.isNotEmpty) {
        final ayahSubjects = ayah.subjects ?? const <String>[];
        if (!ayahSubjects.any(subjectKeys.contains)) {
          return false;
        }
      }
      if (schoolLevelPairs.isNotEmpty || schoolIds.isNotEmpty) {
        if (allowedSchoolAyahIds != null) {
          final ayahId = ayah.id;
          if (ayahId == null || !allowedSchoolAyahIds.contains(ayahId)) {
            return false;
          }
        } else {
          final levels = ayah.schoolLevels ?? const [];
          final matchesSchoolId = schoolIds.isEmpty
              ? false
              : levels.any((level) =>
                  level.schoolId != null && schoolIds.contains(level.schoolId));
          final matchesPair = schoolLevelPairs.isEmpty
              ? false
              : levels.any((level) {
                  final schoolId = level.schoolId;
                  final levelNumber = level.level;
                  if (schoolId == null || levelNumber == null) {
                    return false;
                  }
                  return schoolLevelPairs.contains('$schoolId:$levelNumber');
                });
          if (!matchesSchoolId && !matchesPair) {
            return false;
          }
        }
      }
      return true;
    }).toList(growable: false);
  }

  Map<int, UserEvaluation> _latestEvaluationsByAyahId(
    Iterable<UserEvaluation> userEvaluations,
  ) {
    final evaluationsByAyahId = <int, UserEvaluation>{};
    for (final evaluation in userEvaluations) {
      final ayahId = evaluation.ayah?.id ?? evaluation.ayahId;
      if (ayahId == null) {
        continue;
      }
      evaluationsByAyahId[ayahId] = evaluation;
    }
    return evaluationsByAyahId;
  }

  List<int> _effectiveJuzs(QuranChartFilters filters) {
    final selectedJuzs = filters.juzs.toSet();
    final thirdsJuzs = <int>{};

    for (final third in filters.thirds) {
      switch (third) {
        case 'first':
          thirdsJuzs.addAll(List<int>.generate(10, (index) => index + 1));
          break;
        case 'second':
          thirdsJuzs.addAll(List<int>.generate(10, (index) => index + 11));
          break;
        case 'third':
          thirdsJuzs.addAll(List<int>.generate(10, (index) => index + 21));
          break;
      }
    }

    if (thirdsJuzs.isEmpty) {
      final result = selectedJuzs.toList(growable: false);
      result.sort();
      return result;
    }

    final result = selectedJuzs.isEmpty
        ? thirdsJuzs.toList(growable: false)
        : thirdsJuzs.intersection(selectedJuzs).toList(growable: false);
    result.sort();
    return result;
  }
}