import '../controllers/ayat_controller.dart';
import 'evaluations_services.dart';
import 'school_services.dart';

class SchoolFilterScope {
  const SchoolFilterScope({
    required this.ayahIdsBySchoolId,
    required this.ayahIdsBySchoolLevelPair,
  });

  final Map<int, Set<int>> ayahIdsBySchoolId;
  final Map<String, Set<int>> ayahIdsBySchoolLevelPair;

  Set<int>? resolveAllowedAyahIds(QuranChartFilters filters) {
    if (filters.schoolIds.isEmpty && filters.schoolLevelPairs.isEmpty) {
      return null;
    }

    final allowedAyahIds = <int>{};
    for (final schoolId in filters.schoolIds) {
      allowedAyahIds.addAll(ayahIdsBySchoolId[schoolId] ?? const <int>{});
    }
    for (final schoolLevelPair in filters.schoolLevelPairs) {
      allowedAyahIds.addAll(
        ayahIdsBySchoolLevelPair[schoolLevelPair] ?? const <int>{},
      );
    }

    return allowedAyahIds;
  }
}

class SchoolFilterScopeService {
  const SchoolFilterScopeService();

  static Future<SchoolFilterScope>? _cachedScopeFuture;

  Future<Set<int>?> resolveAllowedAyahIds(QuranChartFilters filters) async {
    if (filters.schoolIds.isEmpty && filters.schoolLevelPairs.isEmpty) {
      return null;
    }

    final scope = await loadScope();
    return scope.resolveAllowedAyahIds(filters);
  }

  Future<SchoolFilterScope> loadScope() {
    _cachedScopeFuture ??= _buildScope();
    return _cachedScopeFuture!;
  }

  Future<SchoolFilterScope> _buildScope() async {
    final ayatController = AyatController();
    final schools = await SchoolServices().getAllSchools();
    final ayahIdsBySchoolId = <int, Set<int>>{};
    final ayahIdsBySchoolLevelPair = <String, Set<int>>{};

    for (final school in schools) {
      final schoolId = school.id;
      if (schoolId == null) {
        continue;
      }

      for (final level in school.levels) {
        final levelNumber = level.level;
        if (levelNumber == null) {
          continue;
        }

        final matchedAyahIds = <int>{};
        for (final content in level.content) {
          final ayahs = await ayatController.loadAyatForContent(content);
          for (final ayah in ayahs) {
            final ayahId = ayah.id;
            if (ayahId != null) {
              matchedAyahIds.add(ayahId);
            }
          }
        }

        if (matchedAyahIds.isEmpty) {
          continue;
        }

        ayahIdsBySchoolLevelPair['$schoolId:$levelNumber'] = matchedAyahIds;
        (ayahIdsBySchoolId[schoolId] ??= <int>{}).addAll(matchedAyahIds);
      }
    }

    return SchoolFilterScope(
      ayahIdsBySchoolId: {
        for (final entry in ayahIdsBySchoolId.entries)
          entry.key: Set<int>.unmodifiable(entry.value),
      },
      ayahIdsBySchoolLevelPair: {
        for (final entry in ayahIdsBySchoolLevelPair.entries)
          entry.key: Set<int>.unmodifiable(entry.value),
      },
    );
  }
}