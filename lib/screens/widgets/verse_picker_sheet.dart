import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../widgets/surah_verse_chart.dart';

/// Bottom sheet that lets the user pick individual ayahs for bulk evaluation.
/// Returns `List<int>` of selected ayah IDs, or null if dismissed.
Future<List<int>?> showVersePickerSheet({
  required BuildContext context,
  required String sheetTitle,
  required List<VerseChartEntry> verseEntries,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VersePickerSheet(
      sheetTitle: sheetTitle,
      verseEntries: verseEntries,
    ),
  );
}

class VersePickerSheet extends StatefulWidget {
  const VersePickerSheet({
    super.key,
    required this.sheetTitle,
    required this.verseEntries,
  });

  final String sheetTitle;
  final List<VerseChartEntry> verseEntries;

  @override
  State<VersePickerSheet> createState() => _VersePickerSheetState();
}

class _VersePickerSheetState extends State<VersePickerSheet> {
  final Set<int> _selectedAyahIds = {};

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final entries = widget.verseEntries;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.82),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Text(
                    widget.sheetTitle,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF191919),
                    ),
                  ),
                ),
                if (_selectedAyahIds.isNotEmpty)
                  Text(
                    'تم اختيار ${_selectedAyahIds.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EBE3)),
          // ── Verse list ─────────────────────────────────────────────
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF5F2EE)),
              itemBuilder: (_, index) {
                final entry = entries[index];
                final isSelected = _selectedAyahIds.contains(entry.ayahId);
                return VersePickerRow(
                  entry: entry,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAyahIds.remove(entry.ayahId);
                      } else {
                        _selectedAyahIds.add(entry.ayahId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          // ── Bottom action ──────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedAyahIds.isEmpty
                      ? null
                      : () {
                          Navigator.of(context)
                              .pop(_selectedAyahIds.toList());
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor: const Color(0xFFD5D5D5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white),
                  label: Text(
                    _selectedAyahIds.isEmpty
                        ? 'اختر آيات للتقييم'
                        : 'تقييم ${_selectedAyahIds.length} آية',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VersePickerRow extends StatelessWidget {
  const VersePickerRow({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final VerseChartEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryPurple : Colors.white,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryPurple
                      : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            // Verse text (one line, truncated)
            Expanded(
              child: Text(
                entry.text,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: isSelected
                      ? const Color(0xFF191919)
                      : const Color(0xFF444444),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Verse number badge
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPurple.withValues(alpha: 0.1)
                    : const Color(0xFFF5F2EE),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${entry.ayahNumber}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryPurple
                      : const Color(0xFF666666),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
