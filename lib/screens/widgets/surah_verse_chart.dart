import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────
// Public model  – one entry per verse
// ─────────────────────────────────────────────────────────

/// A single verse's contribution to the chart.
///
/// [letterCount] determines the bar's width (proportional to total surah
/// letter count).  [score] maps to bar height:
///   3  → متمكن
///   2  → مراجعة
///   1  → سهل
///   0  → غير مصنف
///  -1  → صعب
///
/// [color] comes directly from the admin evaluation settings – never hardcoded
/// in this widget.  [evaluationLabel] and [text] are shown in the popup dialog.
class VerseChartEntry {
  const VerseChartEntry({
    required this.ayahId,
    required this.ayahNumber,
    required this.letterCount,
    required this.score,
    required this.color,
    required this.evaluationLabel,
    required this.text,
  });

  final int ayahId;
  final int ayahNumber;
  final int letterCount;

  /// Numerical score: 3 / 2 / 1 / 0 / -1
  final double score;

  /// Resolved from the admin evaluation color field – not hardcoded here.
  final Color color;

  /// Arabic display name of the evaluation, e.g. 'متمكن', 'غير مصنف'.
  final String evaluationLabel;

  /// Full verse text (Arabic script), shown in the popup.
  final String text;
}

// ─────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────

/// A lightweight variable-width bar chart that shows how each verse in a
/// surah has been evaluated.  Designed to be placed inside an expandable card.
/// No external charting libraries are required.
///
/// Tap a bar to open a popup with the verse text and evaluation label.
/// The legend is derived from the actual entries so colors always match the
/// admin configuration.
class SurahVerseChart extends StatelessWidget {
  const SurahVerseChart({
    super.key,
    required this.entries,
    this.height = 120,
    this.showLegend = true,
  });

  final List<VerseChartEntry> entries;
  final double height;
  final bool showLegend;

  // ── hit-test helper ──────────────────────────────────────
  VerseChartEntry? _findTappedEntry(
    TapUpDetails details,
    BoxConstraints constraints,
  ) {
    if (entries.isEmpty) return null;
    final totalLetters =
        entries.fold<int>(0, (sum, e) => sum + e.letterCount);
    if (totalLetters <= 0) return null;

    const double scoreMin = -1.0;
    const double scoreRange = 4.0; // 3 - (-1)

    final w = constraints.maxWidth;
    final h = height;
    final scaleX = w / totalLetters;
    final scaleY = h / scoreRange;
    final zeroY = h - ((0 - scoreMin) * scaleY);

    double currentLetters = 0;
    for (final entry in entries) {
      final barW = entry.letterCount * scaleX;
      final right = w - (currentLetters * scaleX);
      final left = right - barW;

      if (details.localPosition.dx >= left - 1 &&
          details.localPosition.dx <= right + 1) {
        final top = h - ((entry.score - scoreMin) * scaleY);
        final rectTop = (top < zeroY ? top : zeroY) - 6;
        final rectBottom = (top > zeroY ? top : zeroY) + 6;

        if (details.localPosition.dy >= rectTop &&
            details.localPosition.dy <= rectBottom) {
          return entry;
        }
      }
      currentLetters += entry.letterCount;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (lbCtx, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final entry = _findTappedEntry(d, constraints);
              if (entry != null) {
                showDialog<void>(
                  context: lbCtx,
                  builder: (_) => _VersePopupDialog(entry: entry),
                );
              }
            },
            child: SizedBox(
              height: height,
              child: CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _VerseChartPainter(entries),
              ),
            ),
          ),
        ),
        if (showLegend) _DynamicLegend(entries: entries),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// CustomPainter
// ─────────────────────────────────────────────────────────

class _VerseChartPainter extends CustomPainter {
  const _VerseChartPainter(this.entries);

  final List<VerseChartEntry> entries;

  static const double _scoreMax = 3.0;
  static const double _scoreMin = -1.0;
  static const double _scoreRange = _scoreMax - _scoreMin; // 4

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final totalLetters =
        entries.fold<int>(0, (sum, e) => sum + e.letterCount);
    if (totalLetters <= 0) return;

    final scaleX = size.width / totalLetters;
    final scaleY = size.height / _scoreRange;
    final zeroY = size.height - ((0 - _scoreMin) * scaleY);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF7F3EE),
    );

    final barPaint = Paint()..style = PaintingStyle.fill;
    final dividerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double currentLetters = 0;

    // Bars are drawn RTL: verse 1 starts from the right edge.
    for (final entry in entries) {
      final barWidthPx = entry.letterCount * scaleX;
      final right = size.width - (currentLetters * scaleX);
      final left = right - barWidthPx;

      final topPx = size.height - ((entry.score - _scoreMin) * scaleY);
      final bottomPx = zeroY;

      var rect = Rect.fromLTRB(
        left,
        topPx < bottomPx ? topPx : bottomPx,
        right,
        topPx > bottomPx ? topPx : bottomPx,
      );

      // Ensure minimum visible stub for score == 0
      if (rect.height < 2) {
        rect = Rect.fromLTWH(rect.left, zeroY - 2, rect.width, 2);
      }

      // Color comes directly from entry (admin-sourced); no overrides here.
      barPaint.color = entry.color;
      canvas.drawRect(rect, barPaint);
      canvas.drawRect(rect, dividerPaint);

      currentLetters += entry.letterCount;
    }

    // Zero baseline
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = const Color(0xFFCBC8C2)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _VerseChartPainter old) =>
      old.entries != entries;
}

// ─────────────────────────────────────────────────────────
// Verse popup dialog
// ─────────────────────────────────────────────────────────

class _VersePopupDialog extends StatelessWidget {
  const _VersePopupDialog({required this.entry});

  final VerseChartEntry entry;

  /// Convert an integer to Arabic-Indic numerals, e.g. 135 → ١٣٥
  static String _toArabicNumerals(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n
        .toString()
        .runes
        .map((r) => digits[r - 48])
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final bg = entry.color;
    final onBg =
        bg.computeLuminance() > 0.45 ? const Color(0xFF1A1A1A) : Colors.white;

    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Evaluation badge ─────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                entry.evaluationLabel,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onBg,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFEEE9E2)),
            const SizedBox(height: 18),
            // ── Verse text + number ──────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Text(
                  '${entry.text} ﴿${_toArabicNumerals(entry.ayahNumber)}﴾',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 2.0,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── Close ────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'إغلاق',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7C5DFA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Dynamic legend (derived from actual entry colors & labels)
// ─────────────────────────────────────────────────────────

class _DynamicLegend extends StatelessWidget {
  const _DynamicLegend({required this.entries});

  final List<VerseChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Collect unique label → color while preserving encounter order.
    final seen = <String>{};
    final items = <({String label, Color color})>[];
    for (final e in entries) {
      if (seen.add(e.evaluationLabel)) {
        items.add((label: e.evaluationLabel, color: e.color));
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        textDirection: TextDirection.rtl,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
