import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;

import '../../controllers/evaluations_controller.dart';
import '../../core/constants/colors.dart';
import '../../models/evaluation.dart';
import '../../providers/evaluations_provider.dart';
import '../../services/evaluations_services.dart';

/// Editable mirror of [QuranChartFilters] used while the user composes a
/// filter selection inside the panel before applying it.
class _DraftFilters {
  _DraftFilters.from(QuranChartFilters source)
      : thirds = {...source.thirds},
        juzs = {...source.juzs},
        surahIds = {...source.surahIds},
        ayahTypes = {...source.ayahTypes},
        memoEvaluationIds = {...source.memoEvaluationIds},
        comprehensionEvaluationIds = {...source.comprehensionEvaluationIds};

  final Set<String> thirds;
  final Set<int> juzs;
  final Set<int> surahIds;
  final Set<String> ayahTypes;
  final Set<int> memoEvaluationIds;
  final Set<int> comprehensionEvaluationIds;

  bool get hasAny =>
      thirds.isNotEmpty ||
      juzs.isNotEmpty ||
      surahIds.isNotEmpty ||
      ayahTypes.isNotEmpty ||
      memoEvaluationIds.isNotEmpty ||
      comprehensionEvaluationIds.isNotEmpty;

  QuranChartFilters toQuranChartFilters() {
    return QuranChartFilters(
      thirds: thirds.toList(),
      juzs: juzs.toList(),
      surahIds: surahIds.toList(),
      ayahTypes: ayahTypes.toList(),
      memoEvaluationIds: memoEvaluationIds.toList(),
      comprehensionEvaluationIds: comprehensionEvaluationIds.toList(),
    );
  }
}

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
  late _DraftFilters _draft;
  QuranChartFilters _lastSyncedFrom = const QuranChartFilters();

  @override
  void initState() {
    super.initState();
    final provider = context.read<EvaluationsProvider>();
    _lastSyncedFrom = provider.chartFilters;
    _draft = _DraftFilters.from(provider.chartFilters);
  }

  void _maybeResyncDraft(EvaluationsProvider provider) {
    if (identical(provider.chartFilters, _lastSyncedFrom)) {
      return;
    }
    _lastSyncedFrom = provider.chartFilters;
    _draft = _DraftFilters.from(provider.chartFilters);
  }

  Future<void> _apply() async {
    final provider = context.read<EvaluationsProvider>();
    setState(() => _applying = true);
    try {
      await provider.applyChartFilters(
        widget.userId,
        _draft.toQuranChartFilters(),
      );
    } catch (_) {
      // Errors are surfaced through provider.chartLoadError elsewhere.
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  Future<void> _reset() async {
    final provider = context.read<EvaluationsProvider>();
    setState(() {
      _draft = _DraftFilters.from(const QuranChartFilters());
      _applying = true;
    });
    try {
      await provider.clearChartFilters(widget.userId);
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    final provider = context.watch<EvaluationsProvider>();
    _maybeResyncDraft(provider);

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
            onTap: () => setState(() => _expanded = !_expanded),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
                  _buildSection(
                    title: 'chart_filter_thirds'.tr,
                    child: _buildThirdsChips(isArabic),
                  ),
                  _buildSection(
                    title: 'chart_filter_juzs'.tr,
                    child: _buildJuzsChips(),
                  ),
                  _buildSection(
                    title: 'chart_filter_surahs'.tr,
                    child: _buildSurahsPicker(isArabic),
                  ),
                  _buildSection(
                    title: 'chart_filter_ayah_types'.tr,
                    child: _buildAyahTypesChips(),
                  ),
                  _buildSection(
                    title: 'chart_filter_memorization_evaluations'.tr,
                    child: _buildEvaluationChips(
                      provider.memorizationEvaluations,
                      _draft.memoEvaluationIds,
                    ),
                  ),
                  _buildSection(
                    title: 'chart_filter_comprehension_evaluations'.tr,
                    child: _buildEvaluationChips(
                      provider.comprehensionEvaluations,
                      _draft.comprehensionEvaluationIds,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _applying ? null : _reset,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('chart_filter_reset'.tr),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _applying ? null : _apply,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                          ),
                          icon: _applying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text('chart_filter_apply'.tr),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _activeCount(QuranChartFilters filters) {
    return filters.thirds.length +
        filters.juzs.length +
        filters.surahIds.length +
        filters.ayahTypes.length +
        filters.memoEvaluationIds.length +
        filters.comprehensionEvaluationIds.length;
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF132A4A),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildThirdsChips(bool isArabic) {
    final thirds = <Map<String, String>>[
      {'key': 'first', 'label': 'first_third'.tr},
      {'key': 'second', 'label': 'second_third'.tr},
      {'key': 'third', 'label': 'third_third'.tr},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: thirds.map((entry) {
        final selected = _draft.thirds.contains(entry['key']);
        return FilterChip(
          label: Text(entry['label']!),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _draft.thirds.add(entry['key']!);
              } else {
                _draft.thirds.remove(entry['key']);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildJuzsChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List<Widget>.generate(30, (index) {
        final juz = index + 1;
        final selected = _draft.juzs.contains(juz);
        return FilterChip(
          label: Text(juz.toString()),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _draft.juzs.add(juz);
              } else {
                _draft.juzs.remove(juz);
              }
            });
          },
        );
      }),
    );
  }

  Widget _buildSurahsPicker(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openSurahMultiPicker(isArabic),
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(
            _draft.surahIds.isEmpty
                ? 'chart_filter_surahs_all'.tr
                : 'chart_filter_surahs_selected'.trParams({
                    'count': _draft.surahIds.length.toString(),
                  }),
          ),
        ),
        if (_draft.surahIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _draft.surahIds.map((id) {
              final name = isArabic
                  ? quran.getSurahNameArabic(id)
                  : quran.getSurahNameEnglish(id);
              return InputChip(
                label: Text(name),
                onDeleted: () {
                  setState(() => _draft.surahIds.remove(id));
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _openSurahMultiPicker(bool isArabic) async {
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _SurahMultiSelectDialog(
        initiallySelected: _draft.surahIds,
        isArabic: isArabic,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _draft.surahIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Widget _buildAyahTypesChips() {
    final entries = <Map<String, String>>[
      {'key': 'Makki', 'label': 'chart_filter_ayah_type_makki'.tr},
      {'key': 'Madani', 'label': 'chart_filter_ayah_type_madani'.tr},
      {'key': 'Debatable', 'label': 'chart_filter_ayah_type_debatable'.tr},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: entries.map((entry) {
        final selected = _draft.ayahTypes.contains(entry['key']);
        return FilterChip(
          label: Text(entry['label']!),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _draft.ayahTypes.add(entry['key']!);
              } else {
                _draft.ayahTypes.remove(entry['key']);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildEvaluationChips(
    List<Evaluation> evaluations,
    Set<int> selectedSet,
  ) {
    if (evaluations.isEmpty) {
      return Text(
        'chart_filter_no_options'.tr,
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      );
    }
    final controller = EvaluationsController();
    final langCode = Get.locale?.languageCode ?? 'ar';
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: evaluations.where((e) => e.id != null && e.id != 0).map((evaluation) {
        final id = evaluation.id!;
        final selected = selectedSet.contains(id);
        final color = controller.getColorForEvaluationId(id);
        final label = evaluation.name[langCode] ??
            evaluation.name['ar'] ??
            evaluation.name['en'] ??
            evaluation.code;
        return FilterChip(
          label: Text(label),
          selected: selected,
          selectedColor: color.withValues(alpha: 0.25),
          checkmarkColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          onSelected: (value) {
            setState(() {
              if (value) {
                selectedSet.add(id);
              } else {
                selectedSet.remove(id);
              }
            });
          },
        );
      }).toList(),
    );
  }
}

class _SurahMultiSelectDialog extends StatefulWidget {
  const _SurahMultiSelectDialog({
    required this.initiallySelected,
    required this.isArabic,
  });

  final Set<int> initiallySelected;
  final bool isArabic;

  @override
  State<_SurahMultiSelectDialog> createState() =>
      _SurahMultiSelectDialogState();
}

class _SurahMultiSelectDialogState extends State<_SurahMultiSelectDialog> {
  late final Set<int> _selected = {...widget.initiallySelected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final entries = List<int>.generate(114, (i) => i + 1).where((id) {
      if (query.isEmpty) return true;
      final ar = quran.getSurahNameArabic(id).toLowerCase();
      final en = quran.getSurahNameEnglish(id).toLowerCase();
      return ar.contains(query) || en.contains(query) || id.toString() == query;
    }).toList();

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'chart_filter_surahs_picker_title'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'surah_picker_search_hint'.tr,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, index) {
                    final id = entries[index];
                    final selected = _selected.contains(id);
                    return CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                      title: Text(
                        widget.isArabic
                            ? quran.getSurahNameArabic(id)
                            : quran.getSurahNameEnglish(id),
                        textDirection: widget.isArabic
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                      secondary: Text(id.toString()),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(_selected.clear);
                        },
                        child: Text('chart_filter_clear'.tr),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                        ),
                        onPressed: () => Navigator.of(context).pop(_selected),
                        child: Text('chart_filter_done'.tr),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
