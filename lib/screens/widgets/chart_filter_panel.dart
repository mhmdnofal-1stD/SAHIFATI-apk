import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../models/ayat.dart';
import '../../providers/evaluations_provider.dart';
import '../../services/evaluations_services.dart';
import '../../services/local_quran_chart_service.dart';
import '../../services/school_filter_scope_service.dart';
import 'quran_filter_runtime.dart';
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
  final QuranFilterAvailabilityBuilder _availabilityBuilder =
      const QuranFilterAvailabilityBuilder();
  final LocalQuranChartService _localQuranChartService =
      const LocalQuranChartService();
  final SchoolFilterScopeService _schoolFilterScopeService =
      const SchoolFilterScopeService();

  Future<void> _openFilterPopup() async {
    await _ensureAvailableDataLoaded();
    if (!mounted || _availableData == null) {
      return;
    }

    final provider = context.read<EvaluationsProvider>();
    final selection = await showQuranFilterSurface(
      context,
      initial: unifiedSelectionFromChartFilters(provider.chartFilters),
      available: _availableData!,
      presentation: QuranFilterPresentation.popup,
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
      final availableData = await _availabilityBuilder.build(
        filters: provider.chartFilters,
        loadScopedAyat: _loadScopedEvaluatedAyat,
        memorizationEvaluations: provider.memorizationEvaluations,
        comprehensionEvaluations: provider.comprehensionEvaluations,
      );

      if (!mounted) return;
      setState(() {
        _availableData = availableData;
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

    final allowedSchoolAyahIds = await _schoolFilterScopeService
        .resolveAllowedAyahIds(filters);

    return _localQuranChartService.filterAyat(
      allAyat,
      filters,
      allowedSchoolAyahIds: allowedSchoolAyahIds,
    );
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvaluationsProvider>();
    final activeCount = activeDimensionCountForChartFilters(
      provider.chartFilters,
    );

    return QuranFilterTrigger.card(
      title: 'chart_filter_title'.tr,
      activeCount: activeCount,
      isBusy: _availableDataLoading || _applying,
      onTap: _availableDataLoading || _applying ? null : _openFilterPopup,
      margin: widget.margin,
    );
  }
}
