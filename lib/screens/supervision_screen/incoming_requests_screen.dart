import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../widgets/soft_pattern_background.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/evaluations_provider.dart';
import '../../services/evaluations_services.dart';
import '../../services/teacher_supervisions_services.dart';
import 'supervision_metric_utils.dart';
import 'supervision_student_overview_screen.dart';

/// Resolves the human-facing identity for a supervision student payload.
///
/// `username` is the live primary identity; `email` and `_id` are only used
/// as secondary disambiguators. Legacy display-only identity keys are
/// intentionally not honoured so stale cached payloads cannot drive live
/// identity again.
String resolveSupervisionStudentName(
  Map<String, dynamic> student, {
  required String fallback,
}) {
  final username = (student['username'] as String?)?.trim();
  if (username != null && username.isNotEmpty) {
    return username;
  }
  final email = (student['email'] as String?)?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }
  final id = student['_id'];
  if (id != null) {
    return '#$id';
  }
  return fallback;
}

class IncomingRequestsScreen extends StatefulWidget {
  static const String routeName = '/supervision-dashboard';

  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  final TeacherSupervisionsService _service = TeacherSupervisionsService();
  late Future<_RequestsBundle> _bundleFuture;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  Future<_RequestsBundle> _load() async {
    final requests = await _service.listIncomingRequests().catchError(
      (_) => <Map<String, dynamic>>[],
    );
    final limits = await _service.getLimits().catchError(
      (_) => <String, dynamic>{},
    );
    final links = await _service.listLinks().catchError(
      (_) => <Map<String, dynamic>>[],
    );

    return _RequestsBundle(
      requests: requests,
      limits: limits,
      links: links,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _bundleFuture = _load();
    });
    await _bundleFuture;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleAccept(Map<String, dynamic> request) async {
    final id = (request['_id'] as num).toInt();
    try {
      await _service.acceptRequest(id);
      _showSnack('supervision_request_accepted'.tr);
      await _reload();
    } on TeacherLimitReachedException {
      await _runAcceptWithRemoveFlow(id);
    } on StudentLimitReachedException catch (e) {
      _showSnack(
        'supervision_student_limit_reached'.trParams({
          'current': e.current.toString(),
          'max': e.max.toString(),
        }),
      );
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _runAcceptWithRemoveFlow(int requestId) async {
    final List<Map<String, dynamic>> links;
    try {
      links = await _service.listLinks();
    } catch (e) {
      _showSnack(e.toString());
      return;
    }
    final teacherLinks = links
        .where((l) => l['roleInLink'] == 'teacher' && l['status'] == 'active')
        .toList(growable: false);
    if (teacherLinks.isEmpty) {
      _showSnack('supervision_teacher_no_links'.tr);
      return;
    }
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickStudentToRemoveSheet(links: teacherLinks),
    );
    if (selected == null) return;
    try {
      await _service.acceptRequestWithRemove(requestId, selected);
      _showSnack('supervision_request_accepted'.tr);
      await _reload();
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _handleReject(Map<String, dynamic> request) async {
    final id = (request['_id'] as num).toInt();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('supervision_reject_confirm_title'.tr),
        content: Text(
          'supervision_reject_confirm_body'.tr,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('supervision_preview_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'supervision_reject_confirm_action'.tr,
              style: AppTypography.of(ctx)
                  .buttonSecondary
                  .copyWith(color: const Color(0xFFB13030)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.rejectRequest(id);
      _showSnack('supervision_request_rejected'.tr);
      await _reload();
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _handleOneTimeReview(Map<String, dynamic> request) async {
    final id = (request['_id'] as num).toInt();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'supervision_one_time_review_confirm_title'.tr,
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'supervision_one_time_review_confirm_body'.tr,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('supervision_preview_cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            child: Text(
              'supervision_one_time_review_confirm_action'.tr,
              style: AppTypography.of(ctx)
                  .buttonPrimary
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.startOneTimeReview(id);
      _showSnack('supervision_one_time_review_started'.tr);
      await _reload();
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _openStudentWorkspace(Map<String, dynamic> link) async {
    final student =
        Map<String, dynamic>.from((link['student'] as Map?) ?? const {});
    final rawId = student['id'] ?? student['_id'];
    final studentId =
        rawId is num ? rawId.toInt() : int.tryParse('${rawId ?? ''}');
    if (studentId == null) {
      _showSnack('profile_unknown_user'.tr);
      return;
    }

    if (!mounted) {
      return;
    }

    await Get.to(
      () => SupervisionStudentOverviewScreen(
        studentId: studentId,
        studentName: resolveSupervisionStudentName(
          student,
          fallback: 'profile_unknown_user'.tr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftPatternBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryPurple),
        centerTitle: true,
        title: Text(
          'supervision_dashboard_screen_title'.tr,
          style: AppTypography.of(context)
              .appBarTitle
              .copyWith(color: AppColors.primaryPurple),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<_RequestsBundle>(
          future: _bundleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryPurple),
              );
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final bundle = snapshot.data!;
            final teacherLinks = bundle.links
                .where(
                  (link) =>
                      link['roleInLink'] == 'teacher' &&
                      link['status'] == 'active',
                )
                .toList(growable: false);
            final studentLinks = bundle.links
                .where(
                  (link) =>
                      link['roleInLink'] == 'student' &&
                      link['status'] == 'active',
                )
                .toList(growable: false);
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _LimitsCard(limits: bundle.limits),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'supervision_incoming_screen_title'.tr,
                    icon: Icons.inbox_outlined,
                    count: bundle.requests.length,
                  ),
                  const SizedBox(height: 12),
                  if (bundle.requests.isEmpty)
                    const _EmptyState(
                      icon: Icons.inbox_outlined,
                      titleKey: 'supervision_incoming_empty_title',
                      bodyKey: 'supervision_incoming_empty_body',
                    )
                  else
                    ...bundle.requests.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestCard(
                          request: r,
                          onAccept: () => _handleAccept(r),
                          onReject: () => _handleReject(r),
                          onOneTimeReview: () => _handleOneTimeReview(r),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'supervision_limits_students_label'.tr,
                    icon: Icons.groups_rounded,
                    count: teacherLinks.length,
                  ),
                  const SizedBox(height: 12),
                  if (teacherLinks.isEmpty)
                    const _EmptyState(
                      icon: Icons.groups_rounded,
                      titleKey: 'supervision_students_empty_title',
                      bodyKey: 'supervision_students_empty_body',
                    )
                  else
                    ...teacherLinks.map(
                      (link) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LinkCard(
                          link: link,
                          onOpenStudentWorkspace: () =>
                              _openStudentWorkspace(link),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'supervision_limits_teachers_label'.tr,
                    icon: Icons.school_rounded,
                    count: studentLinks.length,
                  ),
                  const SizedBox(height: 12),
                  if (studentLinks.isEmpty)
                    const _EmptyState(
                      icon: Icons.school_rounded,
                      titleKey: 'supervision_teachers_empty_title',
                      bodyKey: 'supervision_teachers_empty_body',
                    )
                  else
                    ...studentLinks.map(
                      (link) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LinkCard(link: link),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ));
  }
}

class _RequestsBundle {
  const _RequestsBundle({
    required this.requests,
    required this.limits,
    required this.links,
  });
  final List<Map<String, dynamic>> requests;
  final Map<String, dynamic> limits;
  final List<Map<String, dynamic>> links;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  final String title;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEFEAE0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primaryPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.primaryPurple, fontSize: 16),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count.toString(),
            style: AppTypography.of(context)
                .badgeCount
                .copyWith(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _LimitsCard extends StatelessWidget {
  const _LimitsCard({required this.limits});
  final Map<String, dynamic> limits;

  @override
  Widget build(BuildContext context) {
    final teacherCount = (limits['teacherActiveCount'] as num?)?.toInt() ?? 0;
    final teacherMax = (limits['teacherMax'] as num?)?.toInt() ?? 25;
    final studentCount = (limits['studentActiveCount'] as num?)?.toInt() ?? 0;
    final studentMax = (limits['studentMax'] as num?)?.toInt() ?? 5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LimitTile(
              icon: Icons.school_rounded,
              label: 'supervision_limits_students_label'.tr,
              count: teacherCount,
              max: teacherMax,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: Colors.white.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: _LimitTile(
              icon: Icons.person_pin_circle_rounded,
              label: 'supervision_limits_teachers_label'.tr,
              count: studentCount,
              max: studentMax,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.max,
  });
  final IconData icon;
  final String label;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context).badgeLabel.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count / $max',
                style: AppTypography.of(context)
                    .badgeCount
                    .copyWith(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onOneTimeReview,
  });
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onOneTimeReview;

  @override
  Widget build(BuildContext context) {
    final student = (request['student'] as Map?) ?? const {};
    final studentMap = Map<String, dynamic>.from(student);
    final studentDisplayName = resolveSupervisionStudentName(
      studentMap,
      fallback: 'profile_unknown_user'.tr,
    );
    final email = (student['email'] as String?) ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DFD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEAE0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentDisplayName,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.of(context)
                          .listTileTitle
                          .copyWith(color: AppColors.primaryPurple),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        textDirection: TextDirection.ltr,
                        style: AppTypography.of(context)
                            .bodySmall
                            .copyWith(color: const Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(42),
                  ),
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'supervision_action_accept'.tr,
                    style: AppTypography.of(context)
                        .buttonPrimary
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB13030)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(42),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFFB13030),
                  ),
                  label: Text(
                    'supervision_action_reject'.tr,
                    style: AppTypography.of(context)
                        .buttonSecondary
                        .copyWith(color: const Color(0xFFB13030)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOneTimeReview,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0x40132A4A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(42),
            ),
            icon: const Icon(
              Icons.timer_outlined,
              size: 18,
              color: AppColors.primaryPurple,
            ),
            label: Text(
              'supervision_action_one_time_review'.tr,
              style: AppTypography.of(context)
                  .buttonSecondary
                  .copyWith(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link, this.onOpenStudentWorkspace});

  final Map<String, dynamic> link;
  final VoidCallback? onOpenStudentWorkspace;

  @override
  Widget build(BuildContext context) {
    final roleInLink = (link['roleInLink'] as String?) ?? '';
    final counterpart = Map<String, dynamic>.from(
      ((roleInLink == 'teacher' ? link['student'] : link['teacher']) as Map?) ??
          const {},
    );
    final title = resolveSupervisionStudentName(
      counterpart,
      fallback: 'profile_unknown_user'.tr,
    );
    final studentId = counterpart['_id'] is num
        ? (counterpart['_id'] as num).toInt()
        : (counterpart['id'] is num
            ? (counterpart['id'] as num).toInt()
            : int.tryParse('${counterpart['_id'] ?? counterpart['id'] ?? ''}'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DFD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.of(context)
                      .listTileTitle
                      .copyWith(color: AppColors.primaryPurple),
                ),
                if (roleInLink == 'teacher' && studentId != null) ...[
                  const SizedBox(height: 8),
                  _StudentMemorizationStats(studentId: studentId),
                ],
              ],
            ),
          ),
          if (roleInLink == 'teacher' && onOpenStudentWorkspace != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: onOpenStudentWorkspace,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEFEAE0),
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.person_search_rounded,
                color: AppColors.primaryPurple,
              ),
              tooltip: 'supervision_limits_students_label'.tr,
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentMemorizationStats extends StatefulWidget {
  const _StudentMemorizationStats({required this.studentId});

  final int studentId;

  @override
  State<_StudentMemorizationStats> createState() =>
      _StudentMemorizationStatsState();
}

class _StudentMemorizationStatsState extends State<_StudentMemorizationStats> {
  final EvaluationsServices _evaluationsServices = EvaluationsServices();
  late Future<_StudentMemorizationSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StudentMemorizationSnapshot> _load() async {
    final evaluationsProvider = context.read<EvaluationsProvider>();
    Map<String, dynamic> payload;
    try {
      payload = await _evaluationsServices.getQuranChartPayload(
        widget.studentId,
        dimension: 'memorization',
      );
    } catch (_) {
      payload = await evaluationsProvider.buildOfflineQuranChartPayload(
        widget.studentId,
        dimension: 'memorization',
      );
    }
    final totalVerses = (payload['totalVerses'] as num?)?.toInt() ?? 0;
    final rawEvaluations = payload['evaluations'] as List? ?? const [];

    int proficientCount = 0;
    num proficientPercentage = 0;
    int revisionCount = 0;
    num revisionPercentage = 0;

    for (final item in rawEvaluations.whereType<Map>()) {
      final normalized = Map<String, dynamic>.from(item);
      if (supervisionIsProficientEvaluation(normalized)) {
        proficientCount = (normalized['verseCount'] as num?)?.toInt() ?? 0;
        proficientPercentage = (normalized['percentage'] as num?) ?? 0;
      } else if (supervisionIsReviewEvaluation(normalized)) {
        revisionCount = (normalized['verseCount'] as num?)?.toInt() ?? 0;
        revisionPercentage = (normalized['percentage'] as num?) ?? 0;
      }
    }

    return _StudentMemorizationSnapshot(
      totalVerses: totalVerses,
      proficientCount: proficientCount,
      proficientPercentage: proficientPercentage,
      revisionCount: revisionCount,
      revisionPercentage: revisionPercentage,
    );
  }

  String _formatPercent(num value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StudentMemorizationSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Text(
            '...',
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: const Color(0xFF4B5563)),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        final summary =
            'متمكن ${data.proficientCount} آية (${_formatPercent(data.proficientPercentage)}%) / '
            'مراجعة ${data.revisionCount} آية (${_formatPercent(data.revisionPercentage)}%)';

        return Text(
          summary,
          textDirection: TextDirection.rtl,
          style: AppTypography.of(context)
              .bodySecondary
              .copyWith(color: const Color(0xFF4B5563)),
        );
      },
    );
  }
}

class _StudentMemorizationSnapshot {
  const _StudentMemorizationSnapshot({
    required this.totalVerses,
    required this.proficientCount,
    required this.proficientPercentage,
    required this.revisionCount,
    required this.revisionPercentage,
  });

  final int totalVerses;
  final int proficientCount;
  final num proficientPercentage;
  final int revisionCount;
  final num revisionPercentage;
}

class _PickStudentToRemoveSheet extends StatefulWidget {
  const _PickStudentToRemoveSheet({required this.links});
  final List<Map<String, dynamic>> links;

  @override
  State<_PickStudentToRemoveSheet> createState() =>
      _PickStudentToRemoveSheetState();
}

class _PickStudentToRemoveSheetState extends State<_PickStudentToRemoveSheet> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'supervision_pick_remove_title'.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .sectionTitle
                  .copyWith(color: AppColors.primaryPurple, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'supervision_pick_remove_body'.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .bodySecondary
                  .copyWith(color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.links.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final link = widget.links[i];
                  final id = (link['_id'] as num).toInt();
                  final student = (link['student'] as Map?) ?? const {};
                  final name = resolveSupervisionStudentName(
                    Map<String, dynamic>.from(student),
                    fallback: '#$id',
                  );
                  final selected = _selectedId == id;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: const Color(0x0D132A4A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => setState(() => _selectedId = id),
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: AppColors.primaryPurple,
                    ),
                    title: Text(
                      name,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.of(context)
                          .listTileTitle
                          .copyWith(color: AppColors.primaryPurple),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x40132A4A)),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'supervision_preview_cancel'.tr,
                      style: AppTypography.of(context)
                          .buttonSecondary
                          .copyWith(color: AppColors.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedId == null
                        ? null
                        : () => Navigator.of(context).pop(_selectedId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB13030),
                      minimumSize: const Size.fromHeight(46),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'supervision_pick_remove_confirm'.tr,
                      style: AppTypography.of(context)
                          .buttonPrimary
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DFD2)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primaryPurple,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            titleKey.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.primaryPurple, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            bodyKey.tr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_tethering_error_rounded,
              color: Color(0xFFB13030),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: AppTypography.of(context)
                  .bodyDefault
                  .copyWith(color: AppColors.primaryPurple),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.primaryPurple,
              ),
              label: Text(
                'profile_qr_retry'.tr,
                style: AppTypography.of(context)
                    .buttonSecondary
                    .copyWith(color: AppColors.primaryPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
