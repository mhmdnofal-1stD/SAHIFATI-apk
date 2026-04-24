import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';

class TeacherRecommendationBadge extends StatelessWidget {
  final List<TeacherRecommendation> recommendations;
  final Future<bool> Function(TeacherRecommendation recommendation)? onDelete;
  final bool compact;

  const TeacherRecommendationBadge({
    super.key,
    required this.recommendations,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final badge = Tooltip(
      message: 'teacher_recommendation_badge_tooltip'.trParams({
        'count': '${recommendations.length}',
      }),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE0B04A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: compact ? 14 : 16,
              color: const Color(0xFF8A5A00),
            ),
            SizedBox(width: compact ? 2 : 4),
            Text(
              recommendations.length.toString(),
              style: TextStyle(
                color: const Color(0xFF8A5A00),
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10 : 12,
              ),
            ),
          ],
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showRecommendationsSheet(context),
      child: badge,
    );
  }

  Future<void> _showRecommendationsSheet(BuildContext context) async {
    final localRecommendations = <TeacherRecommendation>[...recommendations];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'teacher_recommendation_badge_sheet_title'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (localRecommendations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'teacher_recommendation_badge_empty'.tr,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.45,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: localRecommendations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final recommendation = localRecommendations[index];
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE6D9BD),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Color(0xFFFFF3D9),
                                      child: Icon(
                                        Icons.school_outlined,
                                        color: Color(0xFF8A5A00),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recommendation
                                                    .teacher?.displayName ??
                                                'teacher_recommendation_badge_unknown_teacher'
                                                    .tr,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _statusText(
                                              context,
                                              recommendation,
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.hintTextColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (onDelete != null)
                                      IconButton(
                                        tooltip:
                                            'teacher_recommendation_badge_delete'
                                                .tr,
                                        onPressed: () async {
                                          final deleted =
                                              await onDelete!(recommendation);
                                          if (!context.mounted || !deleted) {
                                            return;
                                          }

                                          setSheetState(() {
                                            localRecommendations.removeWhere(
                                              (item) =>
                                                  item.id == recommendation.id,
                                            );
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.errorColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _statusText(
    BuildContext context,
    TeacherRecommendation recommendation,
  ) {
    final source = recommendation.source == 'teacher'
        ? 'teacher_recommendation_badge_source_teacher'.tr
        : recommendation.source;
    final notified = recommendation.notified == 'seen'
        ? 'teacher_recommendation_badge_status_seen'.tr
        : recommendation.notified == 'sent'
            ? 'teacher_recommendation_badge_status_sent'.tr
            : recommendation.notified == 'failed'
                ? 'teacher_recommendation_badge_status_failed'.tr
                : 'teacher_recommendation_badge_status_pending'.tr;

    return '$source • $notified';
  }
}
