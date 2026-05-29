import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/models/ayat.dart';
import '../widgets/soft_pattern_background.dart';
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';

class ResultsScreen extends StatelessWidget {
  final int totalAyahs;
  final Map<int, int> assessments; // ayahId -> rating
  final List<Ayat> ayahs;
  final bool isGuestMode;
  final List<Evaluation>? evaluations;

  const ResultsScreen({
    required this.totalAyahs,
    required this.assessments,
    required this.ayahs,
    this.isGuestMode = false,
    this.evaluations,
    super.key,
  });

  static const Map<int, Color> _fallbackColors = {
    0: Color(0xFF1D6652),
    1: Color(0xFF0369A1),
    2: Color(0xFFEA580C),
    3: Color(0xFFDC2626),
  };

  static const Map<int, String> _fallbackLabels = {
    0: 'متمكن',
    1: 'مراجعة',
    2: 'سهل',
    3: 'صعب',
  };

  static const Map<String, String> _typeTitles = {
    'memorization': 'مسار الحفظ',
    'comprehension': 'مسار الفهم',
  };

  List<Evaluation> _effectiveEvaluations() {
    if (evaluations != null && evaluations!.isNotEmpty) {
      final sorted = [...evaluations!];
      sorted.sort((first, second) => (first.id ?? 0).compareTo(second.id ?? 0));
      return sorted;
    }

    return List<Evaluation>.generate(
      4,
      (index) => Evaluation(
        id: index,
        code: '$index',
        name: {'ar': _fallbackLabels[index] ?? 'تقييم'},
      ),
    );
  }

  Color _resolveColor(int index, Evaluation evaluation) {
    final raw = evaluation.color?.trim() ?? '';
    if (raw.isNotEmpty) {
      final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
      final fullHex = normalized.length == 6 ? 'FF$normalized' : normalized;
      try {
        return Color(int.parse(fullHex, radix: 16));
      } catch (_) {}
    }
    return _fallbackColors[index] ?? Colors.grey;
  }

  Map<String, dynamic> _calculateTypeStats({
    required Map<int, int> sectionAssessments,
    required List<Ayat> sectionAyahs,
    required List<Evaluation> activeEvaluations,
  }) {
    final weights = <int, double>{
      for (final evaluation in activeEvaluations) if (evaluation.id != null) evaluation.id!: 0,
    };
    final counts = <int, int>{
      for (final evaluation in activeEvaluations) if (evaluation.id != null) evaluation.id!: 0,
    };
    final ayahById = <int, Ayat>{
      for (final ayah in sectionAyahs)
        if (ayah.id != null) ayah.id!: ayah,
    };
    double assessedWeight = 0;

    for (final entry in sectionAssessments.entries) {
      final ayah = ayahById[entry.key];
      if (ayah == null) {
        continue;
      }
      final evaluationId = entry.value;
      final weight = ayah.weight ?? 0;
      assessedWeight += weight;

      if (weights.containsKey(evaluationId)) {
        weights[evaluationId] = (weights[evaluationId] ?? 0) + weight;
        counts[evaluationId] = (counts[evaluationId] ?? 0) + 1;
      }
    }

    return {
      'weights': weights,
      'counts': counts,
      'assessedWeight': assessedWeight,
    };
  }

  List<_ResultSection> _buildSections(List<Evaluation> activeEvaluations) {
    final ayahById = <int, Ayat>{
      for (final ayah in ayahs)
        if (ayah.id != null) ayah.id!: ayah,
    };
    final assessmentsByType = <String, Map<int, int>>{};

    for (final entry in assessments.entries) {
      final ayah = ayahById[entry.key];
      if (ayah == null) {
        continue;
      }
      final type = ayah.evaluationType ?? 'memorization';
      assessmentsByType.putIfAbsent(type, () => <int, int>{})[entry.key] = entry.value;
    }

    final sections = <_ResultSection>[];
    for (final typeEntry in assessmentsByType.entries) {
      final type = typeEntry.key;
      final sectionEvaluations = activeEvaluations
          .where((evaluation) => evaluation.type == type)
          .toList(growable: false);
      if (sectionEvaluations.isEmpty) {
        continue;
      }

      final sectionAyahs = ayahs
          .where((ayah) => (ayah.evaluationType ?? 'memorization') == type)
          .toList(growable: false);
      final stats = _calculateTypeStats(
        sectionAssessments: typeEntry.value,
        sectionAyahs: sectionAyahs,
        activeEvaluations: sectionEvaluations,
      );
      final weights = stats['weights'] as Map<int, double>;
      final counts = stats['counts'] as Map<int, int>;
      final assessedWeight = stats['assessedWeight'] as double;

      final entries = List<_ResultEntry>.generate(sectionEvaluations.length, (index) {
        final evaluation = sectionEvaluations[index];
        final evaluationId = evaluation.id ?? -1;
        return _ResultEntry(
          label: evaluation.name['ar'] ?? 'تقييم',
          percentage: weights[evaluationId] ?? 0,
          count: counts[evaluationId] ?? 0,
          color: _resolveColor(index, evaluation),
        );
      })
        ..sort((left, right) => right.percentage.compareTo(left.percentage));

      sections.add(
        _ResultSection(
          type: type,
          title: _typeTitles[type] ?? 'المسار',
          subtitle: '',
          assessedWeight: assessedWeight,
          entries: entries,
          accentColor: entries.isEmpty ? const Color(0xFF1D6652) : entries.first.color,
          leadingIcon: type == 'comprehension'
              ? Icons.lightbulb_outline_rounded
              : Icons.auto_stories_rounded,
        ),
      );
    }

    sections.sort((left, right) {
      if (left.type == right.type) {
        return 0;
      }
      if (left.type == 'memorization') {
        return -1;
      }
      return 1;
    });
    return sections;
  }

  Future<void> _handleGoToMain(BuildContext context) async {
    if (isGuestMode) {
      // Show dialog to prompt login or continue as guest
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حفظ النتائج'),
          content: const Text(
            'يجب تسجيل الدخول لحفظ نتائج التقييم في حسابك. هل تريد تسجيل الدخول الآن؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('الإكمال كضيف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );

      if (shouldLogin == true) {
        // Navigate to login and return here after successful login
        final result = await Get.toNamed('/login');
        
        if (result == true) {
          // User logged in successfully, save the assessments
          if (context.mounted) {
            await _saveAssessments(context);
          }
        }
        // After login, go to main
        Get.offAllNamed('/main');
      } else {
        // Continue as guest - go to Quran reading
        Get.offAllNamed('/read', parameters: {
          'surahId': '1',
          'filterTypeId': '1',
        });
      }
    } else {
      // Already logged in, just go to main
      Get.offAllNamed('/main');
    }
  }

  Future<void> _saveAssessments(BuildContext context) async {
    try {
      final usersProvider = context.read<UsersProvider>();
      final evaluationsProvider = context.read<EvaluationsProvider>();
      
      final user = usersProvider.selectedUser;
      if (user == null) {
        return;
      }

      for (final entry in assessments.entries) {
        final ayah = ayahs.firstWhere(
          (item) => item.id == entry.key,
          orElse: () => ayahs.first,
        );
        final evaluationId = entry.value;
        final payload = <String, dynamic>{
          'ayahId': ayah.id,
          'userId': user.id,
        };

        if ((ayah.evaluationType ?? 'memorization') == 'comprehension') {
          payload['compre_id'] = evaluationId;
        } else {
          payload['memo_id'] = evaluationId;
        }

        await evaluationsProvider.evaluateAyah(payload);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التقييم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ التقييم: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEvaluations = _effectiveEvaluations();
    final sections = _buildSections(activeEvaluations);
    return Scaffold(
      body: SoftPatternBackground(
        child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return Padding(
              padding: EdgeInsets.fromLTRB(18, compact ? 10 : 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: AppColors.primaryPurple),
                      onPressed: () => Get.offAllNamed('/main'),
                    ),
                  ),
                  Text(
                    'نتائج التقييم السريع',
                    textAlign: TextAlign.center,
                    style: AppTypography.of(context).pageHeading.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.blackFontColor,
                        ),
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  if (sections.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'لا توجد نتائج صالحة للعرض بعد.',
                          style: AppTypography.of(context).bodyDefault,
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: compact ? 108 : 122,
                      child: Row(
                        children: List<Widget>.generate(sections.length, (index) {
                          final section = sections[index];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: index == sections.length - 1 ? 0 : 10,
                              ),
                              child: _HeroTrackCard(section: section),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List<Widget>.generate(sections.length, (index) {
                          final section = sections[index];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: index == sections.length - 1 ? 0 : 10,
                              ),
                              child: _SectionJourneyCard(section: section),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleGoToMain(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.explore_rounded, color: Colors.white),
                      label: Text(
                        isGuestMode ? 'أكمل رحلتك من الرئيسية' : 'تابع الجولة التالية',
                        style: AppTypography.of(context).buttonPrimary.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _HeroTrackCard extends StatelessWidget {
  final _ResultSection section;

  const _HeroTrackCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            section.accentColor.withValues(alpha: 0.16),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: section.accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(section.leadingIcon, color: section.accentColor, size: 22),
          const SizedBox(height: 6),
          Text(
            '${(section.assessedWeight * 100).toStringAsFixed(2)}%',
            style: AppTypography.of(context).sectionTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackFontColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            section.title,
            style: AppTypography.of(context).bodySmall.copyWith(
                  color: AppColors.blackFontColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            'من المصحف تم تقييمه',
            style: AppTypography.of(context).bodySmall.copyWith(
                  color: AppColors.mutedText,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionJourneyCard extends StatelessWidget {
  final _ResultSection section;

  const _SectionJourneyCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final visibleEntries = section.entries.take(3).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4EBE1)),
        boxShadow: [
          BoxShadow(
            color: section.accentColor.withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: section.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.leadingIcon, color: section.accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppTypography.of(context).bodyDefault.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.blackFontColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: List<Widget>.generate(visibleEntries.length, (index) {
                final entry = visibleEntries[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: index == visibleEntries.length - 1 ? 0 : 8),
                    child: _ResultProgressRow(entry: entry),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultProgressRow extends StatelessWidget {
  final _ResultEntry entry;

  const _ResultProgressRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final progress = entry.percentage.clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  style: AppTypography.of(context).bodySmall.copyWith(
                        color: AppColors.blackFontColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '${(entry.percentage * 100).toStringAsFixed(2)}%',
                style: AppTypography.of(context).bodySmall.copyWith(
                      color: AppColors.blackFontColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(entry.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'عدد البطاقات: ${entry.count}',
            style: AppTypography.of(context).bodySmall.copyWith(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection {
  final String type;
  final String title;
  final String subtitle;
  final double assessedWeight;
  final List<_ResultEntry> entries;
  final Color accentColor;
  final IconData leadingIcon;

  const _ResultSection({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.assessedWeight,
    required this.entries,
    required this.accentColor,
    required this.leadingIcon,
  });
}

class _ResultEntry {
  final String label;
  final double percentage;
  final int count;
  final Color color;

  const _ResultEntry({
    required this.label,
    required this.percentage,
    required this.count,
    required this.color,
  });
}
