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
  });

  final int userId;

  @override
  State<ChartFilterPanel> createState() => _ChartFilterPanelState();
}

class _ChartFilterPanelState extends State<ChartFilterPanel> {
  bool _expanded = false;
  bool _applying = false;
  bool _availableDataLoading = false;
  UnifiedFilterAvailableData? _availableData;
  String? _availableDataScopeKey;

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
      final scopedAyat = await _loadScopedAyat(provider.chartFilters);
      final results = await Future.wait(<Future<Object>>[
        _loadSubjectData(scopedAyat),
        _loadSchoolGroups(scopedAyat),
      ]);
      if (!mounted) return;
      final subjectData = results[0] as _SubjectData;
      final schoolGroups = results[1] as List<UnifiedFilterSchoolGroup>;
      setState(() {
        _availableData = UnifiedFilterAvailableData(
          subjects: subjectData.labels,
          subjectHierarchy: subjectData.hierarchy,
          schoolGroups: schoolGroups,
          memorizationEvaluations: provider.memorizationEvaluations,
          comprehensionEvaluations: provider.comprehensionEvaluations,
        );
        _availableDataScopeKey = scopeKey;
      });
    } catch (_) {
      // Fall back to evaluation-only filters if subject/school lookups fail.
      if (!mounted) return;
      setState(() {
        _availableData = UnifiedFilterAvailableData(
          subjects: const <String, String>{},
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
    final scopeFilters = QuranChartFilters(
      thirds: filters.thirds,
      surahIds: filters.surahIds,
      juzs: filters.juzs,
      ayahTypes: filters.ayahTypes,
    );
    return '${Get.locale?.languageCode ?? 'ar'}:${scopeFilters.toCacheKey()}';
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

  Future<List<Ayat>> _loadScopedAyat(QuranChartFilters filters) async {
    final allAyat = await AyatController().loadAllAyat();
    final effectiveJuzs = _effectiveJuzs(filters).toSet();
    final surahIds = filters.surahIds.toSet();
    final ayahTypes = filters.ayahTypes.toSet();

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
      return true;
    }).toList(growable: false);
  }

  Future<_SubjectData> _loadSubjectData(List<Ayat> scopedAyat) async {
    final hierarchy = await SubjectsLookupService.instance.loadHierarchy();
    final locale = Get.locale?.languageCode ?? 'ar';
    final availableKeys = <String>{};
    for (final ayah in scopedAyat) {
      availableKeys.addAll(ayah.subjects ?? const <String>[]);
    }

    final hierarchyByKey = {
      for (final subject in hierarchy) subject.key.trim(): subject,
    };
    final entries = <String, String>{};
    for (final key in availableKeys) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) continue;
      final subject = hierarchyByKey[normalizedKey];
      final label = subject?.displayName(locale).trim() ?? normalizedKey;
      entries[normalizedKey] = label.isEmpty ? normalizedKey : label;
    }
    return _SubjectData(labels: entries, hierarchy: hierarchy);
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
    final schools = await SchoolServices().getAllSchools();
    final schoolById = <int, School>{
      for (final school in schools)
        if (school.id != null) school.id!: school,
    };
    final levelsBySchool = <int, Set<int>>{};
    final schoolLabelFallbacks = <int, String>{};
    final levelLabelFallbacks = <String, String>{};

    for (final ayah in scopedAyat) {
      for (final level in ayah.schoolLevels ?? const []) {
        final schoolId = level.schoolId;
        final number = level.level;
        if (schoolId == null || number == null) {
          continue;
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
        ));
      }

      if (levels.isEmpty) continue;
      groups.add(UnifiedFilterSchoolGroup(label: groupLabel, levels: levels));
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

    if (_expanded &&
        _availableDataScopeKey != _availableDataKey(provider.chartFilters) &&
        !_availableDataLoading) {
      unawaited(_ensureAvailableDataLoaded());
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 920),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16, bottom: 8),
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
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) {
                unawaited(_ensureAvailableDataLoaded());
              }
            },
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
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (_availableData == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    UnifiedQuranFilterBody(
                      key: ValueKey(provider.chartFilters.toCacheKey()),
                      initial: unifiedSelectionFromChartFilters(
                        provider.chartFilters,
                      ),
                      available: _availableData!,
                      headerStyle: UnifiedFilterHeaderStyle.inline,
                      applyButtonLabel: 'chart_filter_apply'.tr,
                      applyInProgress: _applying,
                      onApply: _applySelection,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectData {
  const _SubjectData({required this.labels, required this.hierarchy});
  final Map<String, String> labels;
  final List<SubjectHierarchyItem> hierarchy;
}
