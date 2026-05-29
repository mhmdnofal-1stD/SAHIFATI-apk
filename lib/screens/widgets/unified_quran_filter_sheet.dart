import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;

import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../core/utils/localized_value.dart';
import '../../core/utils/surah_localization.dart';
import '../../models/evaluation.dart';
import '../../services/evaluations_services.dart';
import '../../services/subjects_lookup_service.dart';

/// Single school in the unified filter — labelled by school name with the
/// list of selectable levels under it.
class UnifiedFilterSchoolGroup {
  const UnifiedFilterSchoolGroup({
    required this.label,
    required this.levels,
    this.availableAyahCount = 0,
  });

  final String label;
  final List<UnifiedFilterSchoolLevel> levels;
  final int availableAyahCount;
}

class UnifiedFilterSchoolLevel {
  const UnifiedFilterSchoolLevel({
    required this.key,
    required this.label,
    required this.level,
    this.availableAyahCount = 0,
  });

  /// Composite "schoolId:level" key used for selection equality and for
  /// per-ayah matching in the reader.
  final String key;
  final String label;
  final int level;
  final int availableAyahCount;
}

/// All "what is selectable" data the unified sheet needs in order to render
/// the dimension chips. The widget is purely visual — it does not load this
/// data itself.
class UnifiedFilterAvailableData {
  const UnifiedFilterAvailableData({
    required this.subjects,
    required this.schoolGroups,
    required this.memorizationEvaluations,
    required this.comprehensionEvaluations,
    this.subjectAyahCounts = const <String, int>{},
    this.showRevelation = true,
    this.subjectHierarchy = const <SubjectHierarchyItem>[],
  });

  /// Subject key → localized display label.
  final Map<String, String> subjects;
  final Map<String, int> subjectAyahCounts;

  /// Full subject hierarchy (includes level and parent info).
  final List<SubjectHierarchyItem> subjectHierarchy;
  final List<UnifiedFilterSchoolGroup> schoolGroups;
  final List<Evaluation> memorizationEvaluations;
  final List<Evaluation> comprehensionEvaluations;
  final bool showRevelation;

  static const empty = UnifiedFilterAvailableData(
    subjects: <String, String>{},
    subjectAyahCounts: <String, int>{},
    subjectHierarchy: <SubjectHierarchyItem>[],
    schoolGroups: <UnifiedFilterSchoolGroup>[],
    memorizationEvaluations: <Evaluation>[],
    comprehensionEvaluations: <Evaluation>[],
  );
}

/// The single, canonical filter selection model shared by the chart panel
/// (browse) and the reader display sheet (read).
///
/// Encoding choices:
///   * thirds: ints 1..3 (reader-native). Converted to `'first'/'second'/
///     'third'` only at the `QuranChartFilters` boundary.
///   * juzs / surahIds / memo / compre: ints.
///   * ayahTypes: lowercase `'makki'/'madani'/'debatable'`. Capitalized at
///     the chart-filter boundary.
///   * subjectKeys: subject hierarchy keys (strings).
///   * schoolLevelIds: composite `'schoolId:level'` strings.
class UnifiedFilterSelection {
  UnifiedFilterSelection({
    Set<int>? thirds,
    Set<int>? juzs,
    Set<int>? surahIds,
    Set<String>? ayahTypes,
    Set<String>? subjectKeys,
    Set<String>? schoolLevelIds,
    Set<int>? memoEvaluationIds,
    Set<int>? compreEvaluationIds,
  })  : thirds = thirds ?? <int>{},
        juzs = juzs ?? <int>{},
        surahIds = surahIds ?? <int>{},
        ayahTypes = ayahTypes ?? <String>{},
        subjectKeys = subjectKeys ?? <String>{},
        schoolLevelIds = schoolLevelIds ?? <String>{},
        memoEvaluationIds = memoEvaluationIds ?? <int>{},
        compreEvaluationIds = compreEvaluationIds ?? <int>{};

  factory UnifiedFilterSelection.empty() => UnifiedFilterSelection();

  factory UnifiedFilterSelection.copy(UnifiedFilterSelection source) {
    return UnifiedFilterSelection(
      thirds: {...source.thirds},
      juzs: {...source.juzs},
      surahIds: {...source.surahIds},
      ayahTypes: {...source.ayahTypes},
      subjectKeys: {...source.subjectKeys},
      schoolLevelIds: {...source.schoolLevelIds},
      memoEvaluationIds: {...source.memoEvaluationIds},
      compreEvaluationIds: {...source.compreEvaluationIds},
    );
  }

  UnifiedFilterSelection copyWith({
    Set<int>? thirds,
    Set<int>? juzs,
    Set<int>? surahIds,
    Set<String>? ayahTypes,
    Set<String>? subjectKeys,
    Set<String>? schoolLevelIds,
    Set<int>? memoEvaluationIds,
    Set<int>? compreEvaluationIds,
  }) {
    return UnifiedFilterSelection(
      thirds: thirds ?? Set.from(this.thirds),
      juzs: juzs ?? Set.from(this.juzs),
      surahIds: surahIds ?? Set.from(this.surahIds),
      ayahTypes: ayahTypes ?? Set.from(this.ayahTypes),
      subjectKeys: subjectKeys ?? Set.from(this.subjectKeys),
      schoolLevelIds: schoolLevelIds ?? Set.from(this.schoolLevelIds),
      memoEvaluationIds: memoEvaluationIds ?? Set.from(this.memoEvaluationIds),
      compreEvaluationIds:
          compreEvaluationIds ?? Set.from(this.compreEvaluationIds),
    );
  }

  final Set<int> thirds;
  final Set<int> juzs;
  final Set<int> surahIds;
  final Set<String> ayahTypes;
  final Set<String> subjectKeys;
  final Set<String> schoolLevelIds;
  final Set<int> memoEvaluationIds;
  final Set<int> compreEvaluationIds;

  /// Number of *dimensions* (not individual chips) currently active. Used
  /// for the "N filters active" badge.
  int get activeDimensionCount {
    var n = 0;
    if (thirds.isNotEmpty || juzs.isNotEmpty || surahIds.isNotEmpty) n++;
    if (ayahTypes.isNotEmpty) n++;
    if (subjectKeys.isNotEmpty) n++;
    if (schoolLevelIds.isNotEmpty) n++;
    if (memoEvaluationIds.isNotEmpty) n++;
    if (compreEvaluationIds.isNotEmpty) n++;
    return n;
  }

  bool get isEmpty => activeDimensionCount == 0;
}

const Map<int, String> _kThirdIntToKey = {
  1: 'first',
  2: 'second',
  3: 'third',
};

const Map<String, int> _kThirdKeyToInt = {
  'first': 1,
  'second': 2,
  'third': 3,
};

/// Convert a [UnifiedFilterSelection] to a [QuranChartFilters] suitable for
/// `EvaluationsProvider.applyChartFilters`. Performs the encoding translations
/// (int thirds → string, lowercase ayahTypes → capitalised, composite school
/// keys → schoolLevelPairs).
QuranChartFilters unifiedSelectionToChartFilters(
  UnifiedFilterSelection selection,
) {
  final schoolLevelPairs = <String>{};
  for (final composite in selection.schoolLevelIds) {
    final parts = composite.split(':');
    if (parts.length != 2) continue;
    final schoolId = int.tryParse(parts[0]);
    final level = int.tryParse(parts[1]);
    if (schoolId == null || level == null) continue;
    schoolLevelPairs.add('$schoolId:$level');
  }

  return QuranChartFilters(
    thirds: selection.thirds
        .map((t) => _kThirdIntToKey[t])
        .whereType<String>()
        .toList(),
    juzs: selection.juzs.toList(),
    surahIds: selection.surahIds.toList(),
    ayahTypes: selection.ayahTypes
        .map((value) => value.isEmpty
            ? value
            : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}')
        .toList(),
    subjectKeys: selection.subjectKeys.toList(),
    schoolLevelPairs: schoolLevelPairs.toList(),
    memoEvaluationIds: selection.memoEvaluationIds.toList(),
    comprehensionEvaluationIds: selection.compreEvaluationIds.toList(),
  );
}

/// Inverse of [unifiedSelectionToChartFilters], used to seed the unified
/// sheet from the currently-applied chart filters.
UnifiedFilterSelection unifiedSelectionFromChartFilters(
  QuranChartFilters filters,
) {
  return UnifiedFilterSelection(
    thirds:
        filters.thirds.map((s) => _kThirdKeyToInt[s]).whereType<int>().toSet(),
    juzs: filters.juzs.toSet(),
    surahIds: filters.surahIds.toSet(),
    ayahTypes: filters.ayahTypes.map((v) => v.toLowerCase()).toSet(),
    subjectKeys: filters.subjectKeys.toSet(),
    schoolLevelIds: filters.schoolLevelPairs.toSet(),
    memoEvaluationIds: filters.memoEvaluationIds.toSet(),
    compreEvaluationIds: filters.comprehensionEvaluationIds.toSet(),
  );
}

/// Helper for cascading scope lookups (Thirds → Juz → Surahs).
class _ScopeData {
  static const int _juzsPerThird = 10;
  static Map<int, List<int>>? _juzToSurahs;

  static Iterable<int> juzsInThird(int third) {
    final start = (third - 1) * _juzsPerThird + 1;
    final end = third * _juzsPerThird;
    return Iterable<int>.generate(end - start + 1, (i) => start + i);
  }

  static Map<int, List<int>> _ensureJuzToSurahs() {
    final cached = _juzToSurahs;
    if (cached != null) return cached;
    final map = <int, Set<int>>{};
    for (var s = 1; s <= quran.totalSurahCount; s++) {
      final firstJuz = quran.getJuzNumber(s, 1);
      final lastJuz = quran.getJuzNumber(s, quran.getVerseCount(s));
      for (var j = firstJuz; j <= lastJuz; j++) {
        (map[j] ??= <int>{}).add(s);
      }
    }
    final sorted = <int, List<int>>{
      for (final entry in map.entries)
        entry.key: (entry.value.toList()..sort()),
    };
    _juzToSurahs = sorted;
    return sorted;
  }

  static Set<int> surahsInJuzs(Iterable<int> juzs) {
    final out = <int>{};
    final table = _ensureJuzToSurahs();
    for (final j in juzs) {
      final list = table[j];
      if (list != null) out.addAll(list);
    }
    return out;
  }
}

/// Visual chrome around the unified filter body.
///
/// * [bottomSheet] adds a drag-handle, centered title and subtitle, and is
///   intended for the modal sheet used by the reader.
/// * [inline] omits the chrome so the body can be embedded inside another
///   panel (e.g. the chart filter panel on /browse).
enum UnifiedFilterHeaderStyle { bottomSheet, inline }

enum UnifiedFilterActionBarPosition { top, bottom }

typedef UnifiedFilterApplyCallback = void Function(
  UnifiedFilterSelection selection,
);

/// The shared filter UI used by both the reader (`/read`) and the chart
/// panel (`/browse`).
///
/// The sheet does not know which surface mounts it — that surface decides
/// what to do with the selection by passing [onApply]. The reader fades
/// non-matching ayahs; the chart panel re-queries chart data.
class UnifiedQuranFilterBody extends StatefulWidget {
  const UnifiedQuranFilterBody({
    super.key,
    required this.initial,
    required this.available,
    required this.onApply,
    this.headerStyle = UnifiedFilterHeaderStyle.bottomSheet,
    this.applyButtonLabel,
    this.applyInProgress = false,
    this.maxHeightFactor = 0.85,
    this.actionBarPosition = UnifiedFilterActionBarPosition.bottom,
  });

  final UnifiedFilterSelection initial;
  final UnifiedFilterAvailableData available;
  final UnifiedFilterApplyCallback onApply;
  final UnifiedFilterHeaderStyle headerStyle;

  /// Optional override for the apply button's label. Defaults to the
  /// `quran_reading_filter_apply` translation.
  final String? applyButtonLabel;

  /// Show a spinner inside the apply button (used by the chart panel while
  /// the chart query is in flight).
  final bool applyInProgress;

  /// Bottom-sheet only: how much of the screen height the body may occupy.
  final double maxHeightFactor;
  final UnifiedFilterActionBarPosition actionBarPosition;

  @override
  State<UnifiedQuranFilterBody> createState() => _UnifiedQuranFilterBodyState();
}

class _UnifiedQuranFilterBodyState extends State<UnifiedQuranFilterBody> {
  late UnifiedFilterSelection _draft;
  final Set<int> _expandedThirds = <int>{};
  final Set<String> _expandedSubjectNodes = <String>{};
  final Set<String> _expandedSchoolGroups = <String>{};

  @override
  void initState() {
    super.initState();
    _draft = UnifiedFilterSelection.copy(widget.initial);
  }

  @override
  void didUpdateWidget(covariant UnifiedQuranFilterBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initial, widget.initial)) {
      _draft = UnifiedFilterSelection.copy(widget.initial);
    }
  }

  String _tr(String key) => key.tr;
  String _trParams(String key, Map<String, String> params) =>
      key.trParams(params);

    String _labelWithCount(String label, int count) =>
      count > 0 ? '$label ($count)' : label;

  void _toggleString(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  void _toggleInt(Set<int> set, int value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  String _evaluationLabel(Evaluation evaluation) {
    final locale = Get.locale?.languageCode ?? 'ar';
    final localized = localizedValue(
      evaluation.name,
      preferredLocale: locale,
    );
    if (localized.isNotEmpty) {
      return localized;
    }
    return evaluation.id?.toString() ?? '';
  }

  /// Surahs the user is allowed to pick, narrowed by Thirds/Juz selection.
  /// `surahIds > juzs > thirds` cascading rule.
  List<int> get _availableSurahIds {
    final allowedJuzs = <int>{};
    if (_draft.juzs.isNotEmpty) {
      allowedJuzs.addAll(_draft.juzs);
    } else if (_draft.thirds.isNotEmpty) {
      for (final t in _draft.thirds) {
        allowedJuzs.addAll(_ScopeData.juzsInThird(t));
      }
    }
    if (allowedJuzs.isEmpty) {
      return List<int>.generate(quran.totalSurahCount, (i) => i + 1);
    }
    final scoped = _ScopeData.surahsInJuzs(allowedJuzs).toList()..sort();
    return scoped;
  }

  String _thirdLabel(int third) {
    final translated = _tr('quran_reading_filter_third_$third');
    return translated.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  FilterChip _filterChipString(
    String label,
    String value,
    Set<String> selectionSet, {
    Color? selectedColor,
    Color? checkmarkColor,
    BorderSide? side,
  }) {
    final selected = selectionSet.contains(value);
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      selected: selected,
      selectedColor: selectedColor ?? theme.colorScheme.primary,
      checkmarkColor: checkmarkColor ?? Colors.white,
      side: side ??
          BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.7),
          ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (_) => _toggleString(selectionSet, value),
    );
  }

  FilterChip _filterChipInt(
    String label,
    int value,
    Set<int> selectionSet, {
    Color? selectedColor,
    Color? checkmarkColor,
    BorderSide? side,
  }) {
    final selected = selectionSet.contains(value);
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      selected: selected,
      selectedColor: selectedColor ?? theme.colorScheme.primary,
      checkmarkColor: checkmarkColor ?? Colors.white,
      side: side ??
          BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.7),
          ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (_) => _toggleInt(selectionSet, value),
    );
  }

  Widget _thirdSectionCard(int third) {
    final isExpanded = _expandedThirds.contains(third);
    final isSelected = _draft.thirds.contains(third);
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                final t = third;
                setState(() {
                  if (_draft.thirds.contains(t)) {
                    _draft = _draft.copyWith(
                      thirds: Set.from(_draft.thirds)..remove(t),
                    );
                    final removed = _ScopeData.juzsInThird(t);
                    _draft = _draft.copyWith(
                      juzs: Set.from(_draft.juzs)..removeAll(removed),
                    );
                  } else {
                    _draft = _draft.copyWith(
                      thirds: Set.from(_draft.thirds)..add(t),
                    );
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isSelected
                                  ? Icons.check_rounded
                                  : Icons.auto_awesome_mosaic_rounded,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _thirdLabel(third),
                              style: AppTypography.of(context)
                                  .listTileTitle
                                  .copyWith(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity:
                          const VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedThirds.remove(third);
                          } else {
                            _expandedThirds.add(third);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final juz in _ScopeData.juzsInThird(third))
                      _filterChipInt(
                        _trParams(
                          'quran_reading_filter_juz_n',
                          {'juz': juz.toString()},
                        ),
                        juz,
                        _draft.juzs,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dimensionSection({
    required String title,
    required List<Widget> chips,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style:
                  AppTypography.of(context).sectionTitle.copyWith(fontSize: 15),
            ),
          ),
          if (chips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _tr('quran_reading_filter_empty_dimension'),
                style: AppTypography.of(context)
                    .badgeLabel
                    .copyWith(color: Theme.of(context).hintColor),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
        ],
      ),
    );
  }

  Widget _expandableFilterCard({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggleExpand,
    Widget? body,
    bool isSelected = false,
    VoidCallback? onSelect,
    double indent = 0,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (onSelect != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : Icons.label_outline_rounded,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.of(context).listTileTitle.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                      ),
                    ),
                    IconButton(
                      visualDensity:
                          const VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      onPressed: onToggleExpand,
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded && body != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: body,
            ),
        ],
      ),
      ),
    );
  }

  Widget _scopeTreeSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 6.0;
                      final columns = constraints.maxWidth >= 780
                          ? 3
                          : constraints.maxWidth >= 520
                              ? 2
                              : 1;
                      final targetWidth = columns == 1
                          ? constraints.maxWidth
                          : ((constraints.maxWidth - (spacing * (columns - 1))) /
                                  columns)
                              .clamp(150.0, 240.0);
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (var t = 1; t <= 3; t++)
                            SizedBox(
                              width: targetWidth,
                              child: _thirdSectionCard(t),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Surahs (filtered by selected juzs / thirds) ─────────────
              if (_availableSurahIds.isNotEmpty)
                ExpansionTile(
                  title: Text(_tr('quran_reading_filter_dim_surahs')),
                  tilePadding:
                      const EdgeInsetsDirectional.only(start: 12, end: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in _availableSurahIds)
                          _filterChipInt(
                            localizedSurahNameById(
                              s,
                              localeCode: Get.locale?.languageCode,
                            ),
                            s,
                            _draft.surahIds,
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _schoolDimensionSection() {
    final visibleGroups = widget.available.schoolGroups
        .where((group) => group.levels.isNotEmpty)
        .toList();

    if (visibleGroups.isEmpty) {
      return _dimensionSection(
        title: _tr('quran_reading_filter_dim_school'),
        chips: const <Widget>[],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _tr('quran_reading_filter_dim_school'),
              style:
                  AppTypography.of(context).sectionTitle.copyWith(fontSize: 15),
            ),
          ),
          Column(
            children: [
              for (final group in visibleGroups)
                _expandableFilterCard(
                  title: _labelWithCount(
                    group.label,
                    group.availableAyahCount,
                  ),
                  isExpanded:
                      _expandedSchoolGroups.contains(group.label) ||
                      group.levels.any(
                        (level) => _draft.schoolLevelIds.contains(level.key),
                      ),
                  onToggleExpand: () {
                    setState(() {
                      if (_expandedSchoolGroups.contains(group.label)) {
                        _expandedSchoolGroups.remove(group.label);
                      } else {
                        _expandedSchoolGroups.add(group.label);
                      }
                    });
                  },
                  body: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.levels
                          .map(
                            (level) => _filterChipString(
                              _labelWithCount(
                                level.label,
                                level.availableAyahCount,
                              ),
                              level.key,
                              _draft.schoolLevelIds,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _evaluationChips(
    List<Evaluation> evaluations,
    Set<int> selectionSet,
  ) {
    if (evaluations.isEmpty) {
      return const <Widget>[];
    }
    final controller = EvaluationsController();
    return evaluations
        .where((e) => e.id != null && e.id != 0)
        .map((evaluation) {
      final id = evaluation.id!;
      final color = controller.getColorForEvaluationId(id);
      return _filterChipInt(
        _evaluationLabel(evaluation),
        id,
        selectionSet,
        selectedColor: color.withValues(alpha: 0.25),
        checkmarkColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      );
    }).toList();
  }

  void _resetAll() {
    setState(() {
      _draft.thirds.clear();
      _draft.juzs.clear();
      _draft.surahIds.clear();
      _draft.ayahTypes.clear();
      _draft.subjectKeys.clear();
      _draft.schoolLevelIds.clear();
      _draft.memoEvaluationIds.clear();
      _draft.compreEvaluationIds.clear();
    });
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.applyInProgress ? null : _resetAll,
              child: Text(_tr('quran_reading_filter_clear')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: widget.applyInProgress
                  ? null
                  : () => widget.onApply(
                        _normalizedSelection(),
                      ),
              child: widget.applyInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.applyButtonLabel ??
                          _tr('quran_reading_filter_apply'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _expandedSubjectSelection() {
    final selectedKeys = _draft.subjectKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    if (selectedKeys.isEmpty) {
      return const <String>{};
    }

    final availableKeys = widget.available.subjects.keys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    final childrenByParent = <String, List<String>>{};
    for (final item in widget.available.subjectHierarchy) {
      final key = item.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final parent = item.parent?.trim();
      if (parent == null || parent.isEmpty || parent == '0') {
        continue;
      }
      childrenByParent.putIfAbsent(parent, () => <String>[]).add(key);
    }

    final expanded = <String>{};

    void collect(String key) {
      if (!expanded.add(key)) {
        return;
      }
      for (final child in childrenByParent[key] ?? const <String>[]) {
        collect(child);
      }
    }

    final descendants = <String>{};
    for (final key in selectedKeys) {
      collect(key);
    }
    descendants.addAll(expanded.where(availableKeys.contains));

    if (descendants.isEmpty) {
      return selectedKeys;
    }
    return descendants;
  }

  UnifiedFilterSelection _normalizedSelection() {
    return UnifiedFilterSelection.copy(_draft).copyWith(
      subjectKeys: _expandedSubjectSelection(),
    );
  }

  Widget _hierarchicalSubjectSection() {
    final locale = Get.locale?.languageCode ?? 'ar';
    final theme = Theme.of(context);
    final hierarchy = widget.available.subjectHierarchy;
    final availableKeys = widget.available.subjects.keys
        .map((key) => key.trim())
      .where(
        (key) =>
          key.isNotEmpty &&
          (widget.available.subjectAyahCounts[key] ?? 0) > 0,
      )
        .toSet();
    final nodesByKey = <String, SubjectHierarchyItem>{
      for (final item in hierarchy)
        if (item.key.trim().isNotEmpty) item.key.trim(): item,
    };
    final visibleKeys = <String>{};

    void markVisibleChain(String key) {
      final trimmedKey = key.trim();
      if (trimmedKey.isEmpty || !visibleKeys.add(trimmedKey)) {
        return;
      }
      final parent = nodesByKey[trimmedKey]?.parent?.trim();
      if (parent != null && parent.isNotEmpty && parent != '0') {
        markVisibleChain(parent);
      }
    }

    for (final key in availableKeys) {
      markVisibleChain(key);
    }

    List<SubjectHierarchyItem> childrenOf(String? parentKey) {
      final normalizedParent = parentKey?.trim();
      final isRoot = normalizedParent == null || normalizedParent.isEmpty;
      return hierarchy.where((item) {
        final itemKey = item.key.trim();
        if (itemKey.isEmpty || !visibleKeys.contains(itemKey)) {
          return false;
        }

        final parent = item.parent?.trim();
        if (isRoot) {
          return parent == null || parent.isEmpty || parent == '0';
        }
        return parent == normalizedParent;
      }).toList()
        ..sort((left, right) {
          final levelCompare = left.level.compareTo(right.level);
          if (levelCompare != 0) {
            return levelCompare;
          }
          return left.displayName(locale).compareTo(right.displayName(locale));
        });
    }

    final rootNodes = childrenOf(null);

    bool hasSelectedDescendant(SubjectHierarchyItem node) {
      for (final child in childrenOf(node.key)) {
        final childKey = child.key.trim();
        if (_draft.subjectKeys.contains(childKey) || hasSelectedDescendant(child)) {
          return true;
        }
      }
      return false;
    }

    Widget buildSubjectNode(SubjectHierarchyItem node, {double indent = 0}) {
      final nodeKey = node.key.trim();
      final label = node.displayName(locale).trim().isEmpty
          ? nodeKey
          : node.displayName(locale).trim();
      final labelWithCount = _labelWithCount(
        label,
        widget.available.subjectAyahCounts[nodeKey] ?? 0,
      );
      final children = childrenOf(nodeKey);
      final isSelected = _draft.subjectKeys.contains(nodeKey);
      final isExpanded = _expandedSubjectNodes.contains(nodeKey) ||
          isSelected ||
          hasSelectedDescendant(node);

      if (children.isEmpty) {
        return Padding(
          padding: EdgeInsetsDirectional.only(start: indent, bottom: 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _filterChipString(
              labelWithCount,
              nodeKey,
              _draft.subjectKeys,
            ),
          ),
        );
      }

      return _expandableFilterCard(
        title: labelWithCount,
        isExpanded: isExpanded,
        isSelected: isSelected,
        indent: indent,
        onSelect: () => _toggleString(_draft.subjectKeys, nodeKey),
        onToggleExpand: () {
          setState(() {
            if (_expandedSubjectNodes.contains(nodeKey)) {
              _expandedSubjectNodes.remove(nodeKey);
            } else {
              _expandedSubjectNodes.add(nodeKey);
            }
          });
        },
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in children)
              buildSubjectNode(child, indent: indent + 12),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _tr('quran_reading_filter_dim_subject'),
              style:
                  AppTypography.of(context).sectionTitle.copyWith(fontSize: 15),
            ),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: rootNodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _tr('quran_reading_filter_empty_dimension'),
                      style: AppTypography.of(context)
                          .badgeLabel
                          .copyWith(color: theme.hintColor),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 880
                          ? 3
                          : constraints.maxWidth >= 520
                              ? 2
                              : 1;
                      const spacing = 8.0;
                      final totalSpacing = spacing * (columns - 1);
                      final itemWidth =
                          ((constraints.maxWidth - totalSpacing) / columns)
                          .clamp(180.0, constraints.maxWidth);

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final root in rootNodes)
                            SizedBox(
                              width: itemWidth,
                              child: buildSubjectNode(root),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentColumn(
    BuildContext context, {
    bool includeTopActionBar = true,
    bool includeBottomActionBar = true,
  }) {
    final isSheet = widget.headerStyle == UnifiedFilterHeaderStyle.bottomSheet;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final revelationOptions = <MapEntry<String, String>>[
      MapEntry('makki', _tr('quran_reading_filter_revelation_makki')),
      MapEntry('madani', _tr('quran_reading_filter_revelation_madani')),
      MapEntry('debatable', _tr('quran_reading_filter_revelation_debatable')),
    ];

    final subjectEntries = widget.available.subjects.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSheet) ...[
          Container(
            height: 4,
            width: 44,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (includeTopActionBar &&
            widget.actionBarPosition == UnifiedFilterActionBarPosition.top)
          _buildActionBar(),
        _scopeTreeSection(),
        if (widget.available.memorizationEvaluations.isNotEmpty)
          _dimensionSection(
            title: _tr('quran_reading_filter_dim_memorization'),
            chips: _evaluationChips(
              widget.available.memorizationEvaluations,
              _draft.memoEvaluationIds,
            ),
          ),
        if (widget.available.comprehensionEvaluations.isNotEmpty)
          _dimensionSection(
            title: _tr('quran_reading_filter_dim_comprehension'),
            chips: _evaluationChips(
              widget.available.comprehensionEvaluations,
              _draft.compreEvaluationIds,
            ),
          ),
        if (widget.available.showRevelation)
          _dimensionSection(
            title: _tr('quran_reading_filter_dim_revelation'),
            chips: revelationOptions
                .map((entry) => _filterChipString(
                      entry.value,
                      entry.key,
                      _draft.ayahTypes,
                    ))
                .toList(),
          ),
        if (widget.available.subjectHierarchy.isNotEmpty)
          _hierarchicalSubjectSection()
        else if (widget.available.subjects.isNotEmpty)
          _dimensionSection(
            title: _tr('quran_reading_filter_dim_subject'),
            chips: subjectEntries
                .map((entry) => _filterChipString(
                      entry.value,
                      entry.key,
                      _draft.subjectKeys,
                    ))
                .toList(),
          ),
        if (widget.available.schoolGroups.isNotEmpty)
          _schoolDimensionSection(),
        if (_draft.activeDimensionCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _trParams(
                'quran_reading_filter_active_summary',
                {'count': _draft.activeDimensionCount.toString()},
              ),
              style: AppTypography.of(context)
                  .badgeLabel
                  .copyWith(color: theme.hintColor),
            ),
          ),
        if (includeBottomActionBar &&
            widget.actionBarPosition == UnifiedFilterActionBarPosition.bottom)
          _buildActionBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSheet = widget.headerStyle == UnifiedFilterHeaderStyle.bottomSheet;

    if (!isSheet) {
      if (widget.actionBarPosition == UnifiedFilterActionBarPosition.top) {
        return LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionBar(),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildContentColumn(
                    context,
                    includeTopActionBar: false,
                    includeBottomActionBar: false,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return _buildContentColumn(context);
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * widget.maxHeightFactor,
          ),
          child: SingleChildScrollView(
            child: _buildContentColumn(context),
          ),
        ),
      ),
    );
  }
}

/// Convenience launcher: shows the unified filter UI as a modal bottom
/// sheet and resolves with the user's [UnifiedFilterSelection], or `null`
/// if the sheet was dismissed without applying.
Future<UnifiedFilterSelection?> showUnifiedQuranFilterSheet(
  BuildContext context, {
  required UnifiedFilterSelection initial,
  required UnifiedFilterAvailableData available,
}) {
  return showModalBottomSheet<UnifiedFilterSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => UnifiedQuranFilterBody(
      initial: initial,
      available: available,
      headerStyle: UnifiedFilterHeaderStyle.bottomSheet,
      onApply: (selection) => Navigator.of(sheetContext).pop(selection),
    ),
  );
}

Future<UnifiedFilterSelection?> showUnifiedQuranFilterPopup(
  BuildContext context, {
  required UnifiedFilterSelection initial,
  required UnifiedFilterAvailableData available,
  String? applyButtonLabel,
}) {
  return showDialog<UnifiedFilterSelection>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final width = MediaQuery.of(dialogContext).size.width;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 920,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.86,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: UnifiedQuranFilterBody(
              initial: initial,
              available: available,
              headerStyle: width >= 700
                  ? UnifiedFilterHeaderStyle.inline
                  : UnifiedFilterHeaderStyle.bottomSheet,
              actionBarPosition: UnifiedFilterActionBarPosition.top,
              applyButtonLabel: applyButtonLabel,
              onApply: (selection) =>
                  Navigator.of(dialogContext).pop(selection),
            ),
          ),
        ),
      );
    },
  );
}
