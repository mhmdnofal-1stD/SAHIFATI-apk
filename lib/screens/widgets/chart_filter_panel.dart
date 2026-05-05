import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../controllers/ayat_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../models/ayat.dart';
import '../../models/school.dart';
import '../../providers/evaluations_provider.dart';
import '../../services/evaluations_services.dart';
import '../../services/local_quran_chart_service.dart';
import '../../services/school_services.dart';
import '../../services/subjects_lookup_service.dart';
import 'unified_quran_filter_sheet.dart';

/// Browse-page chart filter. Collapsed header + expandable body that mounts
/// the shared [UnifiedQuranFilterBody]. The user composes a selection inside
/// the body; pressing Apply converts the selection to [QuranChartFilters]
/// and triggers [EvaluationsProvider.applyChartFilters], which re-queries
/// the bar chart data.
class ChartFilterPanel extends StatefulWidget {
  const ChartFilterPanel({
    super.key,
    required this.userId,
    this.margin = const EdgeInsets.only(top: 16, bottom: 8),
  });

  final int userId;
  final EdgeInsetsGeometry margin;

  @override
  State<ChartFilterPanel> createState() => _ChartFilterPanelState();
}

class _ChartFilterPanelState extends State<ChartFilterPanel> {
  bool _applying = false;
  bool _availableDataLoading = false;
  UnifiedFilterAvailableData? _availableData;
  String? _availableDataScopeKey;
  final LocalQuranChartService _localQuranChartService =
      const LocalQuranChartService();

  Future<void> _openFilterPopup() async {
    await _ensureAvailableDataLoaded();
    if (!mounted || _availableData == null) {
      return;
    }

    final provider = context.read<EvaluationsProvider>();
    final selection = await showUnifiedQuranFilterPopup(
      context,
      initial: unifiedSelectionFromChartFilters(provider.chartFilters),
      available: _availableData!,
      applyButtonLabel: 'chart_filter_apply'.tr,
    );
    if (selection == null || !mounted) {
      return;
    }

    await _applySelection(selection);
  }

  Future<void> _ensureAvailableDataLoaded() async {
    final provider = context.read<EvaluationsProvider>();
    final scopeKey = _availableDataKey(provider.chartFilters);
    if ((_availableData != null && _availableDataScopeKey == scopeKey) ||
        _availableDataLoading) {
      return;
    }
    setState(() => _availableDataLoading = true);
    try {
      if (provider.evaluations.isEmpty) {
        try {
          await provider.getAllEvaluations();
        } catch (_) {
          // Keep going so the filter can still render any locally available data.
        }
      }
      final scopedAyat = await _loadScopedEvaluatedAyat(provider.chartFilters);
      final schoolScopedAyat = await _loadScopedEvaluatedAyat(
        _filtersWithoutSchool(provider.chartFilters),
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

      if (!mounted) return;
      setState(() {
        _availableData = UnifiedFilterAvailableData(
          subjects: subjectData.labels,
          subjectAyahCounts: subjectData.counts,
          subjectHierarchy: subjectData.hierarchy,
          schoolGroups: schoolGroups,
          memorizationEvaluations: provider.memorizationEvaluations,
          comprehensionEvaluations: provider.comprehensionEvaluations,
        );
        _availableDataScopeKey = scopeKey;
      });
    } catch (_) {
      // Fall back to evaluation-only filters only when the scoped ayah load
      // itself fails. Subject and school lookups degrade independently above.
      if (!mounted) return;
      setState(() {
        _availableData = UnifiedFilterAvailableData(
          subjects: const <String, String>{},
          subjectAyahCounts: const <String, int>{},
          schoolGroups: const <UnifiedFilterSchoolGroup>[],
          memorizationEvaluations: provider.memorizationEvaluations,
          comprehensionEvaluations: provider.comprehensionEvaluations,
        );
        _availableDataScopeKey = scopeKey;
      });
    } finally {
      if (mounted) {
        setState(() => _availableDataLoading = false);
      }
    }
  }

  String _availableDataKey(QuranChartFilters filters) {
    return '${Get.locale?.languageCode ?? 'ar'}:${filters.toCacheKey()}';
  }

  QuranChartFilters _filtersWithoutSchool(QuranChartFilters filters) {
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

  Future<List<Ayat>> _loadScopedEvaluatedAyat(QuranChartFilters filters) async {
    final provider = context.read<EvaluationsProvider>();
    final userEvaluations = await provider.loadResolvedUserEvaluations(
      widget.userId,
    );
    final memoEvaluationIds = filters.memoEvaluationIds.toSet();
    final comprehensionEvaluationIds =
        filters.comprehensionEvaluationIds.toSet();
    final allAyat = userEvaluations
        .where((evaluation) {
          if (memoEvaluationIds.isNotEmpty &&
              !memoEvaluationIds.contains(evaluation.memoId)) {
            return false;
          }
          if (comprehensionEvaluationIds.isNotEmpty &&
              !comprehensionEvaluationIds.contains(evaluation.compreId)) {
            return false;
          }
          return true;
        })
        .map((evaluation) => evaluation.ayah)
        .whereType<Ayat>()
        .fold<Map<int, Ayat>>(<int, Ayat>{}, (acc, ayah) {
      final ayahId = ayah.id;
      if (ayahId != null) {
        acc[ayahId] = ayah;
      }
      return acc;
    })
        .values
        .toList(growable: false);

    return _localQuranChartService.filterAyat(allAyat, filters);
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
      if (normalizedKey.isEmpty) continue;
      final subject = hierarchyByKey[normalizedKey];
      final label = subject?.displayName(locale).trim() ?? normalizedKey;
      entries[normalizedKey] = label.isEmpty ? normalizedKey : label;
    }
    return _SubjectData(labels: entries, hierarchy: hierarchy, counts: counts);
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

  Future<List<UnifiedFilterSchoolGroup>> _loadSchoolGroups(
    List<Ayat> scopedAyat,
  ) async {
    final locale = Get.locale?.languageCode ?? 'ar';
    final ayatController = AyatController();
    final scopedAyahIds = scopedAyat
        .where((ayah) => ayah.id != null)
        .map((ayah) => ayah.id!)
        .toSet();
    final schools = await SchoolServices().getAllSchools(
      forceRefresh: true,
    );
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
      for (final level in ayah.schoolLevels ?? const []) {
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
        levels.add(UnifiedFilterSchoolLevel(
          key: '$schoolId:$number',
          label: levelLabel,
          level: number,
          availableAyahCount: levelCounts['$schoolId:$number'] ?? 0,
        ));
      }

      if (levels.isEmpty) continue;
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

    groups.sort((a, b) => a.label.compareTo(b.label));
    return groups;
  }

  String _localizedSchoolName(School school, String locale) {
    final raw = school.schoolName;
    final preferred = raw[locale];
    if (preferred is String && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }
    for (final candidate in raw.values) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return school.id?.toString() ?? '';
  }

  String? _localizedLevelName(Map<String, dynamic>? raw, String locale) {
    if (raw == null) return null;
    final preferred = raw[locale];
    if (preferred is String && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }
    for (final candidate in raw.values) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  Future<void> _applySelection(UnifiedFilterSelection selection) async {
    final provider = context.read<EvaluationsProvider>();
    setState(() => _applying = true);
    try {
      await provider.applyChartFilters(
        widget.userId,
        unifiedSelectionToChartFilters(selection),
      );
    } catch (_) {
      // Errors are surfaced through provider.chartLoadError elsewhere.
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  int _activeCount(QuranChartFilters filters) {
    var n = 0;
    if (filters.thirds.isNotEmpty ||
        filters.juzs.isNotEmpty ||
        filters.surahIds.isNotEmpty) {
      n++;
    }
    if (filters.ayahTypes.isNotEmpty) n++;
    if (filters.subjectKeys.isNotEmpty) n++;
    if (filters.schoolLevelPairs.isNotEmpty || filters.schoolIds.isNotEmpty) {
      n++;
    }
    if (filters.memoEvaluationIds.isNotEmpty) n++;
    if (filters.comprehensionEvaluationIds.isNotEmpty) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvaluationsProvider>();
    final activeCount = _activeCount(provider.chartFilters);

    return Container(
      constraints: const BoxConstraints(maxWidth: 920),
      width: double.infinity,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE2DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _availableDataLoading || _applying ? null : _openFilterPopup,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primaryPurple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'chart_filter_title'.tr,
                      style: AppTypography.of(context).subsectionTitle,
                    ),
                  ),
                  if (_availableDataLoading || _applying)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (activeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6, left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                  const Icon(
                    Icons.open_in_full_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
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
