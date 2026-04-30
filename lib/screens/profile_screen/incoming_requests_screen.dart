import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/typography/app_typography.dart';
import '../../services/teacher_supervisions_services.dart';

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
    final results = await Future.wait([
      _service.listIncomingRequests(),
      _service.getLimits(),
    ]);
    return _RequestsBundle(
      requests: results[0] as List<Map<String, dynamic>>,
      limits: results[1] as Map<String, dynamic>,
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
              backgroundColor: const Color(0xFF132A4A),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4ED),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF132A4A)),
        centerTitle: true,
        title: Text(
          'supervision_incoming_screen_title'.tr,
          style: AppTypography.of(context)
              .appBarTitle
              .copyWith(color: const Color(0xFF132A4A)),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<_RequestsBundle>(
          future: _bundleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF132A4A)),
              );
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final bundle = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _LimitsCard(limits: bundle.limits),
                  const SizedBox(height: 16),
                  if (bundle.requests.isEmpty)
                    const _EmptyState()
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestsBundle {
  const _RequestsBundle({required this.requests, required this.limits});
  final List<Map<String, dynamic>> requests;
  final Map<String, dynamic> limits;
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
        color: const Color(0xFF132A4A),
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
                  color: Color(0xFF132A4A),
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
                          .copyWith(color: const Color(0xFF132A4A)),
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
                    backgroundColor: const Color(0xFF132A4A),
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
              color: Color(0xFF132A4A),
            ),
            label: Text(
              'supervision_action_one_time_review'.tr,
              style: AppTypography.of(context)
                  .buttonSecondary
                  .copyWith(color: const Color(0xFF132A4A)),
            ),
          ),
        ],
      ),
    );
  }
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
                  .copyWith(color: const Color(0xFF132A4A), fontSize: 16),
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
                  return RadioListTile<int>(
                    value: id,
                    groupValue: _selectedId,
                    onChanged: (v) => setState(() => _selectedId = v),
                    title: Text(
                      name,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.of(context)
                          .listTileTitle
                          .copyWith(color: const Color(0xFF132A4A)),
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
                          .copyWith(color: const Color(0xFF132A4A)),
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
  const _EmptyState();

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
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF132A4A),
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'supervision_incoming_empty_title'.tr,
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: const Color(0xFF132A4A), fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'supervision_incoming_empty_body'.tr,
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
                  .copyWith(color: const Color(0xFF132A4A)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF132A4A),
              ),
              label: Text(
                'profile_qr_retry'.tr,
                style: AppTypography.of(context)
                    .buttonSecondary
                    .copyWith(color: const Color(0xFF132A4A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
