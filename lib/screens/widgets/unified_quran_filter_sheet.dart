import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;

import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../models/evaluation.dart';
import '../../services/evaluations_services.dart';
import '../../services/subjects_lookup_service.dart';

/// Single school in the unified filter — labelled by school name with the
/// list of selectable levels under it.
class UnifiedFilterSchoolGroup {
  const UnifiedFilterSchoolGroup({
    required this.label,
    required this.levels,
  });

  final String label;
  final List<UnifiedFilterSchoolLevel> levels;
}

class UnifiedFilterSchoolLevel {
  const UnifiedFilterSchoolLevel({
    required this.key,
    required this.label,
    required this.level,
  });

  /// Composite "schoolId:level" key used for selection equality and for
  /// per-ayah matching in the reader.
  final String key;
  final String label;
  final int level;
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
    this.showRevelation = true,
    this.subjectHierarchy = const <SubjectHierarchyItem>[],
  });

  /// Subject key → localized display label.
  final Map<String, String> subjects;
  /// Full subject hierarchy (includes level and parent info).
  final List<SubjectHierarchyItem> subjectHierarchy;
  final List<UnifiedFilterSchoolGroup> schoolGroups;
  final List<Evaluation> memorizationEvaluations;
  final List<Evaluation> comprehensionEvaluations;
  final bool showRevelation;

  static const empty = UnifiedFilterAvailableData(
    subjects: <String, String>{},
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
/// keys → schoolIds + schoolLevelPairs).
QuranChartFilters unifiedSelectionToChartFilters(
  UnifiedFilterSelection selection,
) {
  final schoolIds = <int>{};
  final schoolLevelPairs = <String>{};
  for (final composite in selection.schoolLevelIds) {
    final parts = composite.split(':');
    if (parts.length != 2) continue;
    final schoolId = int.tryParse(parts[0]);
    final level = int.tryParse(parts[1]);
    if (schoolId == null || level == null) continue;
    schoolIds.add(schoolId);
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
    schoolIds: schoolIds.toList(),
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
    thirds: filters.thirds
        .map((s) => _kThirdKeyToInt[s])
        .whereType<int>()
        .toSet(),
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

  static int thirdOfJuz(int juz) => ((juz - 1) ~/ _juzsPerThird) + 1;

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

  @override
  State<UnifiedQuranFilterBody> createState() => _UnifiedQuranFilterBodyState();
}

class _UnifiedQuranFilterBodyState extends State<UnifiedQuranFilterBody> {
  late UnifiedFilterSelection _draft;

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
    final raw = evaluation.name;
    final localized = raw[locale] ?? raw['ar'] ?? raw['en'];
    if (localized != null && localized.trim().isNotEmpty) {
      return localized.trim();
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

  String _scopeBadgeText() {
    if (_draft.surahIds.isNotEmpty) {
      return _trParams('quran_reading_filter_scope_surahs_count', {
        'count': _draft.surahIds.length.toString(),
      });
    }
    if (_draft.juzs.isNotEmpty) {
      return _trParams('quran_reading_filter_scope_juzs_count', {
        'count': _draft.juzs.length.toString(),
      });
    }
    if (_draft.thirds.isNotEmpty) {
      return _trParams('quran_reading_filter_scope_thirds_count', {
        'count': _draft.thirds.length.toString(),
      });
    }
    return _tr('quran_reading_filter_scope_full_mushaf');
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor,
      checkmarkColor: checkmarkColor,
      side: side,
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor,
      checkmarkColor: checkmarkColor,
      side: side,
      onSelected: (_) => _toggleInt(selectionSet, value),
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
              style: AppTypography.of(context)
                  .sectionTitle
                  .copyWith(fontSize: 15),
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr('quran_reading_filter_scope_title'),
                        style: AppTypography.of(context)
                            .sectionTitle
                            .copyWith(fontSize: 15),
                      ),
                    ),
                    Text(
                      _scopeBadgeText(),
                      style: AppTypography.of(context)
                          .badgeLabel
                          .copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              // ── Thirds row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ToggleButtons(
                    isSelected: [
                      _draft.thirds.contains(1),
                      _draft.thirds.contains(2),
                      _draft.thirds.contains(3),
                    ],
                    onPressed: (index) {
                      final t = index + 1;
                      setState(() {
                        if (_draft.thirds.contains(t)) {
                          _draft = _draft.copyWith(
                            thirds: Set.from(_draft.thirds)..remove(t),
                          );
                          // Remove juzs that belonged to this third
                          final removed = _ScopeData.juzsInThird(t);
                          _draft = _draft.copyWith(
                            juzs: Set.from(_draft.juzs)
                              ..removeAll(removed),
                          );
                        } else {
                          _draft = _draft.copyWith(
                            thirds: Set.from(_draft.thirds)..add(t),
                          );
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    constraints: const BoxConstraints(minHeight: 36),
                    fillColor: theme.colorScheme.primary
                        .withValues(alpha: 0.12),
                    selectedColor: theme.colorScheme.primary,
                    color: theme.hintColor,
                    borderColor: theme.dividerColor,
                    selectedBorderColor: theme.colorScheme.primary,
                    children: [
                      for (var t = 1; t <= 3; t++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            _tr('quran_reading_filter_third_$t'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Juz grid (filtered by selected thirds) ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var j = 1; j <= 30; j++)
                      if (_draft.thirds.isEmpty ||
                          _draft.thirds
                              .contains(_ScopeData.thirdOfJuz(j)))
                        _filterChipInt(
                          _trParams('quran_reading_filter_juz_n', {
                            'juz': j.toString(),
                          }),
                          j,
                          _draft.juzs,
                        ),
                  ],
                ),
              ),
              // ── Surahs (filtered by selected juzs / thirds) ─────────────
              if (_availableSurahIds.isNotEmpty)
                ExpansionTile(
                  title: Text(_tr('quran_reading_filter_dim_surahs')),
                  tilePadding:
                      const EdgeInsetsDirectional.only(start: 12, end: 8),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in _availableSurahIds)
                          _filterChipInt(
                            quran.getSurahNameArabic(s),
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
    if (widget.available.schoolGroups.isEmpty) {
      return _dimensionSection(
        title: _tr('quran_reading_filter_dim_school'),
        chips: const <Widget>[],
      );
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _tr('quran_reading_filter_dim_school'),
              style: AppTypography.of(context)
                  .sectionTitle
                  .copyWith(fontSize: 15),
            ),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (final group in widget.available.schoolGroups)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: group.levels.any(
                        (level) => _draft.schoolLevelIds.contains(level.key),
                      ),
                      tilePadding: const EdgeInsetsDirectional.only(
                        start: 12,
                        end: 8,
                      ),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text(
                        group.label,
                        style: AppTypography.of(context).listTileTitle,
                      ),
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: group.levels
                                .map(
                                  (level) => _filterChipString(
                                    level.label,
                                    level.key,
                                    _draft.schoolLevelIds,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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

  Widget _hierarchicalSubjectSection() {
    final locale = Get.locale?.languageCode ?? 'ar';
    final theme = Theme.of(context);
    final hierarchy = widget.available.subjectHierarchy;

    // Separate main subjects (level 0) from children (level 1+)
    final mainSubjects =
        hierarchy.where((s) => s.level == 0).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _tr('quran_reading_filter_dim_subject'),
              style: AppTypography.of(context)
                  .sectionTitle
                  .copyWith(fontSize: 15),
            ),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: mainSubjects.map((main) {
                final children = hierarchy
                    .where((s) => s.level == 1 && s.parent == main.key)
                    .toList();
                final mainLabel = main.displayName(locale);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: _draft.subjectKeys.contains(main.key) ||
                        children.any((c) =>
                            _draft.subjectKeys.contains(c.key)),
                    tilePadding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 8,
                    ),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    title: _filterChipString(
                      mainLabel,
                      main.key,
                      _draft.subjectKeys,
                    ),
                    children: children.isEmpty
                        ? const []
                        : [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: children
                                    .map((child) => _filterChipString(
                                          child.displayName(locale),
                                          child.key,
                                          _draft.subjectKeys,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentColumn(BuildContext context) {
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
          Text(
            _tr('quran_reading_filter_title'),
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _tr('quran_reading_filter_subtitle'),
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .badgeLabel
                .copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
        ],
        _scopeTreeSection(),
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
        else
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
        _schoolDimensionSection(),
        _dimensionSection(
          title: _tr('quran_reading_filter_dim_memorization'),
          chips: _evaluationChips(
            widget.available.memorizationEvaluations,
            _draft.memoEvaluationIds,
          ),
        ),
        _dimensionSection(
          title: _tr('quran_reading_filter_dim_comprehension'),
          chips: _evaluationChips(
            widget.available.comprehensionEvaluations,
            _draft.compreEvaluationIds,
          ),
        ),
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
        Row(
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
                          UnifiedFilterSelection.copy(_draft),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSheet = widget.headerStyle == UnifiedFilterHeaderStyle.bottomSheet;

    if (!isSheet) {
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
