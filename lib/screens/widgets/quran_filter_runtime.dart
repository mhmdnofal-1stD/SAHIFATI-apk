import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/controllers/ayat_controller.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/school.dart';
import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/core/utils/localized_value.dart';
import 'package:sahifaty/services/evaluations_services.dart';
import 'package:sahifaty/services/subjects_lookup_service.dart';
import 'package:sahifaty/services/school_services.dart';

import 'unified_quran_filter_sheet.dart';

enum QuranFilterPresentation { popup, sheet }

enum QuranFilterTriggerVariant { card, icon }

class QuranFilterTrigger extends StatelessWidget {
  const QuranFilterTrigger.card({
    super.key,
    required this.title,
    required this.onTap,
    this.activeCount = 0,
    this.isBusy = false,
    this.margin,
  })  : variant = QuranFilterTriggerVariant.card,
        tooltip = null,
        isDarkMode = false,
        flat = false;

  const QuranFilterTrigger.icon({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.isDarkMode,
    this.activeCount = 0,
    this.isBusy = false,
    this.flat = false,
  })  : variant = QuranFilterTriggerVariant.icon,
        title = null,
        margin = null;

  final QuranFilterTriggerVariant variant;
  final String? title;
  final String? tooltip;
  final VoidCallback? onTap;
  final int activeCount;
  final bool isBusy;
  final bool isDarkMode;
  final bool flat;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case QuranFilterTriggerVariant.card:
        return _FilterCardTrigger(
          title: title ?? '',
          activeCount: activeCount,
          isBusy: isBusy,
          onTap: onTap,
          margin: margin,
        );
      case QuranFilterTriggerVariant.icon:
        return _FilterIconTrigger(
          tooltip: tooltip ?? '',
          activeCount: activeCount,
          isBusy: isBusy,
          isDarkMode: isDarkMode,
          flat: flat,
          onTap: onTap,
        );
    }
  }
}

int activeDimensionCountForChartFilters(QuranChartFilters filters) {
  return unifiedSelectionFromChartFilters(filters).activeDimensionCount;
}

QuranChartFilters filtersWithoutSchool(QuranChartFilters filters) {
  return QuranChartFilters(
    thirds: filters.thirds,
    surahIds: filters.surahIds,
    juzs: filters.juzs,
    ayahTypes: filters.ayahTypes,
    subjectKeys: filters.subjectKeys,
    memoEvaluationIds: filters.memoEvaluationIds,
    comprehensionEvaluationIds: filters.comprehensionEvaluationIds,
  );
}

Future<UnifiedFilterSelection?> showQuranFilterSurface(
  BuildContext context, {
  required UnifiedFilterSelection initial,
  required UnifiedFilterAvailableData available,
  required QuranFilterPresentation presentation,
  String? applyButtonLabel,
}) {
  switch (presentation) {
    case QuranFilterPresentation.popup:
      return showUnifiedQuranFilterPopup(
        context,
        initial: initial,
        available: available,
        applyButtonLabel: applyButtonLabel,
      );
    case QuranFilterPresentation.sheet:
      return showUnifiedQuranFilterSheet(
        context,
        initial: initial,
        available: available,
      );
  }
}

class QuranFilterAvailabilityBuilder {
  const QuranFilterAvailabilityBuilder();

  Future<UnifiedFilterAvailableData> build({
    required QuranChartFilters filters,
    required Future<List<Ayat>> Function(QuranChartFilters filters)
        loadScopedAyat,
    required List<Evaluation> memorizationEvaluations,
    required List<Evaluation> comprehensionEvaluations,
  }) async {
    final scopedAyat = await loadScopedAyat(filters);
    final schoolScopedAyat = await loadScopedAyat(
      filtersWithoutSchool(filters),
    );

    _SubjectData subjectData;
    try {
      subjectData = await _loadSubjectData(scopedAyat);
    } catch (_) {
      subjectData = _fallbackSubjectData(scopedAyat);
    }

    List<UnifiedFilterSchoolGroup> schoolGroups;
    try {
      schoolGroups = await _loadSchoolGroups(schoolScopedAyat);
    } catch (_) {
      schoolGroups = const <UnifiedFilterSchoolGroup>[];
    }

    return UnifiedFilterAvailableData(
      subjects: subjectData.labels,
      subjectAyahCounts: subjectData.counts,
      subjectHierarchy: subjectData.hierarchy,
      schoolGroups: schoolGroups,
      memorizationEvaluations: memorizationEvaluations,
      comprehensionEvaluations: comprehensionEvaluations,
    );
  }

  _SubjectData _fallbackSubjectData(List<Ayat> scopedAyat) {
    final labels = <String, String>{};
    final counts = <String, int>{};

    for (final ayah in scopedAyat) {
      final seenForAyah = <String>{};
      for (final rawKey in ayah.subjects ?? const <String>[]) {
        final normalizedKey = rawKey.trim();
        if (normalizedKey.isEmpty || !seenForAyah.add(normalizedKey)) {
          continue;
        }

        labels[normalizedKey] = normalizedKey;
        counts[normalizedKey] = (counts[normalizedKey] ?? 0) + 1;
      }
    }

    return _SubjectData(
      labels: labels,
      hierarchy: const <SubjectHierarchyItem>[],
      counts: counts,
    );
  }

  Future<_SubjectData> _loadSubjectData(List<Ayat> scopedAyat) async {
    List<SubjectHierarchyItem> hierarchy;
    try {
      hierarchy = await SubjectsLookupService.instance.loadHierarchy();
    } catch (_) {
      return _fallbackSubjectData(scopedAyat);
    }

    final locale = Get.locale?.languageCode ?? 'ar';
    final availableKeys = <String>{};
    final directCounts = <String, int>{};
    final hierarchyByKey = {
      for (final subject in hierarchy) subject.key.trim(): subject,
    };

    for (final ayah in scopedAyat) {
      final seenForAyah = <String>{};
      for (final rawKey in ayah.subjects ?? const <String>[]) {
        final normalizedKey = rawKey.trim();
        if (normalizedKey.isEmpty || !seenForAyah.add(normalizedKey)) {
          continue;
        }
        availableKeys.add(normalizedKey);
        directCounts[normalizedKey] = (directCounts[normalizedKey] ?? 0) + 1;
      }
    }

    final counts = <String, int>{};
    for (final entry in directCounts.entries) {
      String? currentKey = entry.key;
      while (currentKey != null && currentKey.isNotEmpty) {
        counts[currentKey] = (counts[currentKey] ?? 0) + entry.value;
        final parent = hierarchyByKey[currentKey]?.parent?.trim();
        if (parent == null || parent.isEmpty || parent == '0') {
          break;
        }
        currentKey = parent;
      }
    }

    final entries = <String, String>{};
    for (final key in availableKeys) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) {
        continue;
      }
      final subject = hierarchyByKey[normalizedKey];
      final label = subject?.displayName(locale).trim() ?? normalizedKey;
      entries[normalizedKey] = label.isEmpty ? normalizedKey : label;
    }

    return _SubjectData(labels: entries, hierarchy: hierarchy, counts: counts);
  }

  Future<List<UnifiedFilterSchoolGroup>> _loadSchoolGroups(
    List<Ayat> scopedAyat,
  ) async {
    final locale = Get.locale?.languageCode ?? 'ar';
    final ayatController = AyatController();
    final scopedAyahIds = scopedAyat
        .where((ayah) => ayah.id != null)
        .map((ayah) => ayah.id!)
        .toSet();
    // Use cache-first loading (with automatic background refresh) to avoid
    // a blocking network round-trip every time the filter panel is opened.
    final schools = await SchoolServices().getAllSchools();
    final schoolById = <int, School>{
      for (final school in schools)
        if (school.id != null) school.id!: school,
    };
    final levelsBySchool = <int, Set<int>>{};
    final levelCounts = <String, int>{};
    final schoolLabelFallbacks = <int, String>{};
    final levelLabelFallbacks = <String, String>{};

    for (final school in schools) {
      final schoolId = school.id;
      if (schoolId == null) {
        continue;
      }

      for (final level in school.levels) {
        final number = level.level;
        if (number == null) {
          continue;
        }

        final matchedAyahIds = <int>{};
        for (final content in level.content) {
          final ayahs = await ayatController.loadAyatForContent(content);
          for (final ayah in ayahs) {
            final ayahId = ayah.id;
            if (ayahId != null && scopedAyahIds.contains(ayahId)) {
              matchedAyahIds.add(ayahId);
            }
          }
        }

        final pairKey = '$schoolId:$number';
        levelCounts[pairKey] = matchedAyahIds.length;
        if (matchedAyahIds.isNotEmpty) {
          (levelsBySchool[schoolId] ??= <int>{}).add(number);
        }
      }
    }

    for (final ayah in scopedAyat) {
      final seenPairsForAyah = <String>{};
      for (final level in ayah.schoolLevels ?? const <SchoolLevel>[]) {
        final schoolId = level.schoolId;
        final number = level.level;
        if (schoolId == null || number == null) {
          continue;
        }

        final pairKey = '$schoolId:$number';
        if (seenPairsForAyah.add(pairKey) && !levelCounts.containsKey(pairKey)) {
          levelCounts[pairKey] = (levelCounts[pairKey] ?? 0) + 1;
        }

        (levelsBySchool[schoolId] ??= <int>{}).add(number);

        final schoolName = level.schoolName?.trim();
        if (schoolName != null && schoolName.isNotEmpty) {
          schoolLabelFallbacks.putIfAbsent(schoolId, () => schoolName);
        }

        final localizedLevel = _localizedLevelName(level.name, locale)?.trim();
        if (localizedLevel != null && localizedLevel.isNotEmpty) {
          levelLabelFallbacks['$schoolId:$number'] = localizedLevel;
        }
      }
    }

    final groups = <UnifiedFilterSchoolGroup>[];

    for (final school in schools) {
      final schoolId = school.id;
      if (schoolId == null) {
        continue;
      }

      final levels = <UnifiedFilterSchoolLevel>[];
      final seenLevels = <int>{};
      final catalogLevels = school.levels.toList()
        ..sort((left, right) {
          final leftValue = left.level ?? 0;
          final rightValue = right.level ?? 0;
          return leftValue.compareTo(rightValue);
        });

      for (final level in catalogLevels) {
        final number = level.level;
        if (number == null || !seenLevels.add(number)) {
          continue;
        }
        final translationKey = 'level_$number';
        final translated = translationKey.tr;
        final levelLabel = _localizedLevelName(level.name, locale) ??
            levelLabelFallbacks['$schoolId:$number'] ??
            _schoolLevelNameFromCatalog(school, number, locale) ??
            (translated == translationKey ? number.toString() : translated);
        levels.add(
          UnifiedFilterSchoolLevel(
            key: '$schoolId:$number',
            label: levelLabel,
            level: number,
            availableAyahCount: levelCounts['$schoolId:$number'] ?? 0,
          ),
        );
      }

      final extraLevels = (levelsBySchool[schoolId] ?? const <int>{})
          .where((number) => !seenLevels.contains(number))
          .toList()
        ..sort();
      for (final number in extraLevels) {
        final translationKey = 'level_$number';
        final translated = translationKey.tr;
        final levelLabel = levelLabelFallbacks['$schoolId:$number'] ??
            _schoolLevelNameFromCatalog(school, number, locale) ??
            (translated == translationKey ? number.toString() : translated);
        levels.add(
          UnifiedFilterSchoolLevel(
            key: '$schoolId:$number',
            label: levelLabel,
            level: number,
            availableAyahCount: levelCounts['$schoolId:$number'] ?? 0,
          ),
        );
      }

      if (levels.isEmpty) {
        continue;
      }

      groups.add(
        UnifiedFilterSchoolGroup(
          label: _localizedSchoolName(school, locale),
          levels: levels,
          availableAyahCount: levels.fold<int>(
            0,
            (sum, level) => sum + level.availableAyahCount,
          ),
        ),
      );
    }

    for (final entry in levelsBySchool.entries) {
      final schoolId = entry.key;
      if (schoolById.containsKey(schoolId)) {
        continue;
      }
      final school = schoolById[schoolId];
      final groupLabel = school != null
          ? _localizedSchoolName(school, locale)
          : (schoolLabelFallbacks[schoolId] ?? schoolId.toString());
      final levels = <UnifiedFilterSchoolLevel>[];

      final sortedLevels = entry.value.toList()..sort();
      for (final number in sortedLevels) {
        final translationKey = 'level_$number';
        final translated = translationKey.tr;
        final levelLabel = levelLabelFallbacks['$schoolId:$number'] ??
            _schoolLevelNameFromCatalog(school, number, locale) ??
            (translated == translationKey ? number.toString() : translated);
        levels.add(
          UnifiedFilterSchoolLevel(
            key: '$schoolId:$number',
            label: levelLabel,
            level: number,
            availableAyahCount: levelCounts['$schoolId:$number'] ?? 0,
          ),
        );
      }

      if (levels.isEmpty) {
        continue;
      }
      groups.add(
        UnifiedFilterSchoolGroup(
          label: groupLabel,
          levels: levels,
          availableAyahCount: levels.fold<int>(
            0,
            (sum, level) => sum + level.availableAyahCount,
          ),
        ),
      );
    }

    groups.sort((left, right) => left.label.compareTo(right.label));
    return groups;
  }

  String _localizedSchoolName(School school, String locale) {
    final resolved = localizedValue(
      localizedStringMapFromDynamic(school.schoolName),
      preferredLocale: locale,
    );
    if (resolved.isNotEmpty) {
      return resolved;
    }

    return school.id?.toString() ?? '';
  }

  String? _localizedLevelName(Map<String, dynamic>? raw, String locale) {
    if (raw == null) {
      return null;
    }

    final resolved = localizedValue(
      localizedStringMapFromDynamic(raw),
      preferredLocale: locale,
    );
    return resolved.isEmpty ? null : resolved;
  }

  String? _schoolLevelNameFromCatalog(
    School? school,
    int levelNumber,
    String locale,
  ) {
    if (school == null) {
      return null;
    }

    for (final level in school.levels) {
      if (level.level == levelNumber) {
        return _localizedLevelName(level.name, locale);
      }
    }

    return null;
  }

  /// Loads all subjects and schools from their cached services without
  /// fetching or computing any scoped-ayah statistics. The popup opens
  /// instantly; result counts are computed only when the user presses Apply.
  ///
  /// [onProgress] is called with a value in [0.0, 1.0] and a display label
  /// so callers can show a loading indicator (e.g. AppProgressOverlay).
  Future<UnifiedFilterAvailableData> buildForDisplay({
    required List<Evaluation> memorizationEvaluations,
    required List<Evaluation> comprehensionEvaluations,
    void Function(double progress, String label)? onProgress,
  }) async {
    final locale = Get.locale?.languageCode ?? 'ar';

    onProgress?.call(0.1, 'filter_loading_data'.tr);

    _SubjectData subjectData;
    try {
      onProgress?.call(0.2, 'filter_loading_subjects'.tr);
      subjectData = await _loadAllSubjectData(locale);
      onProgress?.call(0.55, 'filter_loading_subjects'.tr);
    } catch (_) {
      subjectData = const _SubjectData(
        labels: <String, String>{},
        hierarchy: <SubjectHierarchyItem>[],
        counts: <String, int>{},
      );
    }

    List<UnifiedFilterSchoolGroup> schoolGroups;
    try {
      onProgress?.call(0.6, 'filter_loading_schools'.tr);
      schoolGroups = await _loadAllSchoolGroupsFromCatalog(locale);
      onProgress?.call(0.95, 'filter_loading_schools'.tr);
    } catch (_) {
      schoolGroups = const <UnifiedFilterSchoolGroup>[];
    }

    onProgress?.call(1.0, '');

    return UnifiedFilterAvailableData(
      subjects: subjectData.labels,
      subjectAyahCounts: subjectData.counts,
      subjectHierarchy: subjectData.hierarchy,
      schoolGroups: schoolGroups,
      memorizationEvaluations: memorizationEvaluations,
      comprehensionEvaluations: comprehensionEvaluations,
    );
  }

  Future<_SubjectData> _loadAllSubjectData(String locale) async {
    final results = await Future.wait([
      SubjectsLookupService.instance.loadHierarchy(),
      AyatController().loadAllAyat(),
    ]);
    final hierarchy = results[0] as List<SubjectHierarchyItem>;
    final allAyat = results[1] as List<Ayat>;

    final labels = <String, String>{};
    for (final subject in hierarchy) {
      final key = subject.key.trim();
      if (key.isEmpty) continue;
      final label = subject.displayName(locale).trim();
      labels[key] = label.isEmpty ? key : label;
    }

    final counts = <String, int>{};
    for (final ayah in allAyat) {
      for (final rawKey in ayah.subjects ?? const <String>[]) {
        final key = rawKey.toString().trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return _SubjectData(
      labels: labels,
      hierarchy: hierarchy,
      counts: counts,
    );
  }

  Future<List<UnifiedFilterSchoolGroup>> _loadAllSchoolGroupsFromCatalog(
    String locale,
  ) async {
    final results = await Future.wait([
      SchoolServices().getAllSchools(),
      AyatController().loadAllAyat(),
    ]);
    final schools = results[0] as List<School>;
    final allAyat = results[1] as List<Ayat>;

    // Build per-level ayah count map from bundled data.json.
    final levelCounts = <String, int>{};
    for (final ayah in allAyat) {
      for (final sl in ayah.schoolLevels ?? const <SchoolLevel>[]) {
        final schoolId = sl.schoolId;
        final level = sl.level;
        if (schoolId == null || level == null) continue;
        final key = '$schoolId:$level';
        levelCounts[key] = (levelCounts[key] ?? 0) + 1;
      }
    }

    final groups = <UnifiedFilterSchoolGroup>[];

    for (final school in schools) {
      final schoolId = school.id;
      if (schoolId == null) continue;

      final seenLevels = <int>{};
      final levels = <UnifiedFilterSchoolLevel>[];
      final sortedCatalogLevels = school.levels.toList()
        ..sort((a, b) => (a.level ?? 0).compareTo(b.level ?? 0));

      for (final level in sortedCatalogLevels) {
        final number = level.level;
        if (number == null || !seenLevels.add(number)) continue;
        final translationKey = 'level_$number';
        final translated = translationKey.tr;
        final levelLabel = _localizedLevelName(level.name, locale) ??
            _schoolLevelNameFromCatalog(school, number, locale) ??
            (translated == translationKey ? number.toString() : translated);
        levels.add(UnifiedFilterSchoolLevel(
          key: '$schoolId:$number',
          label: levelLabel,
          level: number,
          availableAyahCount: levelCounts['$schoolId:$number'] ?? 0,
        ));
      }

      if (levels.isEmpty) continue;
      final groupCount = levels.fold<int>(
        0,
        (sum, l) => sum + l.availableAyahCount,
      );
      groups.add(UnifiedFilterSchoolGroup(
        label: _localizedSchoolName(school, locale),
        levels: levels,
        availableAyahCount: groupCount,
      ));
    }

    groups.sort((a, b) => a.label.compareTo(b.label));
    return groups;
  }
}

class _FilterCardTrigger extends StatelessWidget {
  const _FilterCardTrigger({
    required this.title,
    required this.activeCount,
    required this.isBusy,
    required this.onTap,
    this.margin,
  });

  final String title;
  final int activeCount;
  final bool isBusy;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 920),
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE2DA)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTypography.of(context).subsectionTitle,
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (activeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6, left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'chart_filter_active_count'.trParams({
                      'count': activeCount.toString(),
                    }),
                    style: AppTypography.of(context)
                        .badgeCount
                        .copyWith(color: Colors.white),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_full_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterIconTrigger extends StatelessWidget {
  const _FilterIconTrigger({
    required this.tooltip,
    required this.activeCount,
    required this.isBusy,
    required this.isDarkMode,
    required this.flat,
    required this.onTap,
  });

  final String tooltip;
  final int activeCount;
  final bool isBusy;
  final bool isDarkMode;
  final bool flat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = isDarkMode
        ? (disabled ? const Color(0xFF6B7280) : Colors.white)
        : (disabled ? AppColors.mutedText : AppColors.primaryPurple);
    final background = flat
        ? Colors.transparent
        : (isDarkMode ? const Color(0xFF1F242E) : const Color(0xFFEFEAE0));
    final isActive = activeCount > 0;
    final activeOverlay = isActive
        ? (isDarkMode
            ? Colors.white.withValues(alpha: 0.10)
            : AppColors.primaryPurple.withValues(alpha: 0.10))
        : null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: activeOverlay ?? background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: isBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        )
                      : Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: foreground,
                        ),
                ),
                if (activeCount > 0)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        activeCount > 9 ? '9+' : activeCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectData {
  const _SubjectData({
    required this.labels,
    required this.hierarchy,
    required this.counts,
  });

  final Map<String, String> labels;
  final List<SubjectHierarchyItem> hierarchy;
  final Map<String, int> counts;
}