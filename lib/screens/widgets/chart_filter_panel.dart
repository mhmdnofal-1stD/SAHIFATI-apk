import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
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

  Future<void> _ensureAvailableDataLoaded() async {
    if (_availableData != null || _availableDataLoading) {
      return;
    }
    final provider = context.read<EvaluationsProvider>();
    setState(() => _availableDataLoading = true);
    try {
      final results = await Future.wait(<Future<Object>>[
        _loadSubjectLabels(),
        _loadSchoolGroups(),
      ]);
      if (!mounted) return;
      final subjects = results[0] as Map<String, String>;
      final schoolGroups = results[1] as List<UnifiedFilterSchoolGroup>;
      setState(() {
        _availableData = UnifiedFilterAvailableData(
          subjects: subjects,
          schoolGroups: schoolGroups,
          memorizationEvaluations: provider.memorizationEvaluations,
          comprehensionEvaluations: provider.comprehensionEvaluations,
        );
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
      });
    } finally {
      if (mounted) {
        setState(() => _availableDataLoading = false);
      }
    }
  }

  Future<Map<String, String>> _loadSubjectLabels() async {
    final hierarchy = await SubjectsLookupService.instance.loadHierarchy();
    final locale = Get.locale?.languageCode ?? 'ar';
    final entries = <String, String>{};
    for (final subject in hierarchy) {
      final key = subject.key.trim();
      if (key.isEmpty) continue;
      final label = subject.displayName(locale).trim();
      entries[key] = label.isEmpty ? key : label;
    }
    return entries;
  }

  Future<List<UnifiedFilterSchoolGroup>> _loadSchoolGroups() async {
    final schools = await SchoolServices().getAllSchools();
    final locale = Get.locale?.languageCode ?? 'ar';
    final groups = <UnifiedFilterSchoolGroup>[];

    for (final school in schools) {
      final schoolId = school.id;
      if (schoolId == null) continue;
      final groupLabel = _localizedSchoolName(school, locale);
      final levels = <UnifiedFilterSchoolLevel>[];

      for (final level in school.levels) {
        final number = level.level;
        if (number == null) continue;
        final translationKey = 'level_$number';
        final translated = translationKey.tr;
        final levelLabel = _localizedLevelName(level.name, locale) ??
            (translated == translationKey ? number.toString() : translated);
        levels.add(UnifiedFilterSchoolLevel(
          key: '$schoolId:$number',
          label: levelLabel,
          level: number,
        ));
      }

      if (levels.isEmpty) continue;
      levels.sort((a, b) => a.level.compareTo(b.level));
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
