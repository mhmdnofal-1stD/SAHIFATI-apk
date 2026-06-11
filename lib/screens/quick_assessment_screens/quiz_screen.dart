import 'package:flutter/material.dart';

import '../widgets/soft_pattern_background.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/core/utils/size_config.dart';
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart';

class QuizScreen extends StatefulWidget {
  final Ayat ayah;
  final int currentIndex;
  final int totalAyahs;
  final Function(int rating) onRatingSelected;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final String? customTitle;
  final List<Evaluation>? evaluations;

  const QuizScreen({
    super.key,
    required this.ayah,
    required this.currentIndex,
    required this.totalAyahs,
    required this.onRatingSelected,
    required this.onSkip,
    required this.onBack,
    this.customTitle,
    this.evaluations,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Offset _cardPosition = Offset.zero;
  double _cardRotation = 0.0;
  int? _highlightedRating;

  // Fallback rating colors if no evaluations provided
  static const Map<int, Color> fallbackRatingColors = {
    0: Color(0xFF1D6652), // متمكن - أخضر غامق
    1: Color(0xFF0369A1), // مراجعة - أزرق غامق  
    2: Color(0xFFEA580C), // سهل - برتقالي غامق
    3: Color(0xFFDC2626), // صعب - أحمر غامق
  };

  static const Map<int, String> fallbackRatingLabels = {
    0: 'متمكن',
    1: 'مراجعة',
    2: 'سهل',
    3: 'صعب',
  };

  static const IconData _approveIcon = Icons.keyboard_double_arrow_right_rounded;
  static const IconData _declineIcon = Icons.keyboard_double_arrow_left_rounded;
  static const IconData _easyIcon = Icons.keyboard_double_arrow_right_rounded;
  static const IconData _hardIcon = Icons.keyboard_double_arrow_left_rounded;
  static const IconData _saveIcon = Icons.keyboard_double_arrow_up_rounded;
  static const IconData _undoIcon = Icons.keyboard_double_arrow_down_rounded;

  bool get _isBinaryMode => widget.evaluations != null && widget.evaluations!.length == 2;

  int get _effectiveRatingCount {
    final count = widget.evaluations?.length ?? fallbackRatingLabels.length;
    if (count == 2 || count == 4) {
      return count;
    }
    return fallbackRatingLabels.length;
  }

  int _resolveSelectedEvaluationId(int index) {
    if (widget.evaluations != null && index < widget.evaluations!.length) {
      return widget.evaluations![index].id ?? index;
    }
    return index;
  }

  Color _parseEvaluationColor(String colorHex, int fallbackIndex) {
    final normalized = colorHex.trim();
    if (normalized.isEmpty) {
      return fallbackRatingColors[fallbackIndex] ?? Colors.grey;
    }

    final withoutHash = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized;
    final withAlpha = withoutHash.length == 6 ? 'FF$withoutHash' : withoutHash;

    try {
      return Color(int.parse(withAlpha, radix: 16));
    } catch (_) {
      return fallbackRatingColors[fallbackIndex] ?? Colors.grey;
    }
  }

  Color _getRatingColor(int index) {
    if (widget.evaluations != null && index < widget.evaluations!.length) {
      final colorHex = widget.evaluations![index].color;
      if (colorHex != null && colorHex.isNotEmpty) {
        return _parseEvaluationColor(colorHex, index);
      }
    }
    return fallbackRatingColors[index] ?? Colors.grey;
  }

  String _getRatingLabel(int index) {
    if (widget.evaluations != null && index < widget.evaluations!.length) {
      return widget.evaluations![index].name['ar'] ?? fallbackRatingLabels[index]!;
    }
    return fallbackRatingLabels[index] ?? '';
  }

  Widget _buildDirectionalCue({
    required Alignment alignment,
    required String label,
    required IconData icon,
    required Color color,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    final baseColor = color.withValues(alpha: isHighlighted ? 0.18 : 0.08);
    final borderColor = color.withValues(alpha: isHighlighted ? 0.55 : 0.22);
    final iconColor = color.withValues(alpha: isHighlighted ? 1.0 : 0.72);
    final textColor = color.withValues(alpha: isHighlighted ? 0.95 : 0.8);

    // All direction cues use Column (icon on top, label below) to save horizontal space
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.1),
                boxShadow: isHighlighted
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeIndicators() {
    if (_isBinaryMode) {
      return Stack(
        children: [
          _buildDirectionalCue(
            alignment: Alignment.centerRight,
            label: _getRatingLabel(0),
            icon: _approveIcon,
            color: _getRatingColor(0),
            isHighlighted: _highlightedRating == 0,
            onTap: () => widget.onRatingSelected(_resolveSelectedEvaluationId(0)),
          ),
          _buildDirectionalCue(
            alignment: Alignment.centerLeft,
            label: _getRatingLabel(1),
            icon: _declineIcon,
            color: _getRatingColor(1),
            isHighlighted: _highlightedRating == 1,
            onTap: () => widget.onRatingSelected(_resolveSelectedEvaluationId(1)),
          ),
        ],
      );
    }

    return Stack(
      children: [
        _buildDirectionalCue(
          alignment: Alignment.topCenter,
          label: _getRatingLabel(0),
          icon: _saveIcon,
          color: _getRatingColor(0),
          isHighlighted: _highlightedRating == 0,
          onTap: () => widget.onRatingSelected(_resolveSelectedEvaluationId(0)),
        ),
        _buildDirectionalCue(
          alignment: Alignment.bottomCenter,
          label: _getRatingLabel(1),
          icon: _undoIcon,
          color: _getRatingColor(1),
          isHighlighted: _highlightedRating == 1,
          onTap: () => widget.onRatingSelected(_resolveSelectedEvaluationId(1)),
        ),
        _buildDirectionalCue(
          alignment: Alignment.centerRight,
          label: _getRatingLabel(2),
          icon: _easyIcon,
          color: _getRatingColor(2),
          isHighlighted: _highlightedRating == 2,
          onTap: () => widget.onRatingSelected(_resolveSelectedEvaluationId(2)),
        ),
        _buildDirectionalCue(
          alignment: Alignment.centerLeft,
          label: _getRatingLabel(3),
          icon: _hardIcon,
          color: _getRatingColor(3),
          isHighlighted: _highlightedRating == 3,
          onTap: () => widget.onRatingSelected(_resolveSelectedEvaluationId(3)),
        ),
      ],
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _cardPosition += details.delta;
      _cardRotation = _cardPosition.dx / 1000;

      const threshold = 50.0;
      if (_isBinaryMode) {
        if (_cardPosition.dx < -threshold) {
          _highlightedRating = 1;
        } else if (_cardPosition.dx > threshold) {
          _highlightedRating = 0;
        } else {
          _highlightedRating = null;
        }
      } else {
        if (_cardPosition.dy < -threshold) {
          _highlightedRating = 0;
        } else if (_cardPosition.dy > threshold) {
          _highlightedRating = 1;
        } else if (_cardPosition.dx > threshold) {
          _highlightedRating = 2;
        } else if (_cardPosition.dx < -threshold) {
          _highlightedRating = 3;
        } else {
          _highlightedRating = null;
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    const threshold = 100.0;
    int? selectedRating;

    if (_isBinaryMode) {
      if (_cardPosition.dx < -threshold) {
        selectedRating = 1;
      } else if (_cardPosition.dx > threshold) {
        selectedRating = 0;
      }
    } else {
      if (_cardPosition.dy.abs() > _cardPosition.dx.abs()) {
        if (_cardPosition.dy < -threshold) {
          selectedRating = 0;
        } else if (_cardPosition.dy > threshold) {
          selectedRating = 1;
        }
      } else {
        if (_cardPosition.dx > threshold) {
          selectedRating = 2;
        } else if (_cardPosition.dx < -threshold) {
          selectedRating = 3;
        }
      }
    }

    if (selectedRating != null) {
      widget.onRatingSelected(_resolveSelectedEvaluationId(selectedRating));
    }

    setState(() {
      _cardPosition = Offset.zero;
      _cardRotation = 0.0;
      _highlightedRating = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usesFallbackLabels =
        widget.evaluations == null || widget.evaluations!.length != _effectiveRatingCount;
    final levelTitle = widget.customTitle?.trim().isNotEmpty == true
        ? widget.customTitle!.trim()
        : widget.ayah.surah.nameAr;

    return SoftPatternBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          levelTitle,
          style: AppTypography.of(context).sectionTitle,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (widget.currentIndex + 1) / widget.totalAyahs,
                  backgroundColor: AppColors.lineColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الآية ${widget.currentIndex + 1} من ${widget.totalAyahs}',
                  style: AppTypography.of(context).bodyDefault,
                ),
              ],
            ),
          ),

          // Card area with floating card and edge direction cues.
          Expanded(
            flex: 3,
            child: Stack(
              children: [

                Center(
                  child: GestureDetector(
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Transform.translate(
                      offset: _cardPosition,
                      child: Transform.rotate(
                        angle: _cardRotation,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: SizeConfig.getResponsiveDialogWidth(mobilePercent: 0.85, tabletMaxWidth: 420),
                            minHeight: 340,
                          ),
                          margin: const EdgeInsets.fromLTRB(56, 80, 56, 80),
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A17352A),
                                blurRadius: 28,
                                offset: Offset(0, 14),
                              ),
                              BoxShadow(
                                color: Color(0x12264A3F),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (!widget.ayah.showAyahText) {
                                      return Center(
                                        child: Text(
                                          widget.ayah.text,
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                            height: 1.75,
                                            color: AppColors.primaryPurple,
                                          ),
                                          textAlign: TextAlign.center,
                                          textDirection: TextDirection.rtl,
                                        ),
                                      );
                                    }

                                    const double verseFontSize = 28.0;

                                    return SingleChildScrollView(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight > 0 ? constraints.maxHeight : 0,
                                        ),
                                        child: Center(
                                          child: Text(
                                            widget.ayah.text,
                                            textAlign: TextAlign.center,
                                            textDirection: TextDirection.rtl,
                                            softWrap: true,
                                            maxLines: null,
                                            textHeightBehavior: const TextHeightBehavior(
                                              applyHeightToFirstAscent: true,
                                              applyHeightToLastDescent: false,
                                            ),
                                            style: const TextStyle(
                                              fontFamily: AppFonts.versesFont,
                                              fontSize: verseFontSize,
                                              fontWeight: FontWeight.w500,
                                              height: 1.2,
                                              letterSpacing: 0,
                                              color: AppColors.primaryPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _isBinaryMode
                                    ? 'مرر يمينًا للقبول ويسارًا للرفض'
                                    : 'مرر نحو الحافة المطلوبة أو اضغط المؤشر المناسب',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildEdgeIndicators(),
                if (usesFallbackLabels)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'تم استخدام ترتيب التقييم الافتراضي لعدم توافق عدد التقييمات مع نمط السحب.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onSkip,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.lineColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      foregroundColor: AppColors.primaryPurple,
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: Text(
                      'تخطي',
                      style: AppTypography.of(context).buttonPrimary.copyWith(
                            color: AppColors.primaryPurple,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.currentIndex == 0 ? null : widget.onBack,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.lineColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      foregroundColor: AppColors.primaryPurple,
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      'العودة',
                      style: AppTypography.of(context).buttonPrimary.copyWith(
                            color: AppColors.primaryPurple,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    ));
  }
}
