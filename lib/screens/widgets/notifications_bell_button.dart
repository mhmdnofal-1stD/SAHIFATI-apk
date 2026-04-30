import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/models/user_notification_item.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsBellButton extends StatefulWidget {
  const NotificationsBellButton({super.key});

  @override
  State<NotificationsBellButton> createState() => _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<UsersProvider>().ensureNotificationsLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsersProvider>(
      builder: (context, usersProvider, _) {
        final unreadCount = usersProvider.unreadNotificationsCount;
        final isLoading = usersProvider.isNotificationsLoading;
        final parentContext = this.context;
        final backgroundColor = Theme.of(parentContext).colorScheme.surface;

        return IconButton(
          tooltip: 'notifications_title'.tr,
          onPressed: usersProvider.selectedUser == null
              ? null
              : () async {
                  usersProvider.ensureNotificationsLoaded(forceRefresh: true);
                  if (!mounted) {
                    return;
                  }
                  await showModalBottomSheet<void>(
                    context: parentContext,
                    isScrollControlled: true,
                    showDragHandle: true,
                    backgroundColor: backgroundColor,
                    builder: (_) => const _NotificationsSheet(),
                  );
                },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isLoading ? Icons.notifications_active_outlined : Icons.notifications_none_outlined,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -6,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC2483D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: AppTypography.of(context)
                          .badgeCount
                          .copyWith(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<UsersProvider>(
      builder: (context, usersProvider, _) {
        final notifications = usersProvider.notifications;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'notifications_title'.tr,
                          style: AppTypography.of(context).pageHeading.copyWith(fontSize: 20),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => usersProvider.ensureNotificationsLoaded(
                          forceRefresh: true,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('notifications_refresh'.tr),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'notifications_unread_count'.trParams({
                        'count': usersProvider.unreadNotificationsCount.toString(),
                      }),
                      style: AppTypography.of(context)
                          .bodyDefault
                          .copyWith(color: const Color(0xFF5A645E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: usersProvider.isNotificationsLoading && notifications.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : notifications.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Text(
                                  'notifications_empty'.tr,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.of(context)
                                      .bodyDefault
                                      .copyWith(color: const Color(0xFF5A645E)),
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => usersProvider.ensureNotificationsLoaded(
                                forceRefresh: true,
                              ),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                itemCount: notifications.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final notification = notifications[index];
                                  return _NotificationCard(notification: notification);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final UserNotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.read<UsersProvider>();
    final ctaUrl = _extractCtaUrl();
    final subtitleParts = <String>[];
    final ayahId = notification.meta['ayahId'];
    if (ayahId != null && ayahId.toString().isNotEmpty) {
      subtitleParts.add(
        'notifications_ayah_reference'.trParams({'ayahId': ayahId.toString()}),
      );
    }
    final timestamp = _formatDate(notification.createdAt);
    if (timestamp.isNotEmpty) {
      subtitleParts.add(timestamp);
    }

    return Material(
      color: notification.isRead ? const Color(0xFFF5F5F0) : const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          if (!notification.isRead) {
            await usersProvider.markNotificationRead(notification.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: notification.isRead ? const Color(0xFFDCE2DA) : const Color(0xFFE3C98F),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notification.isRead ? const Color(0xFFE3E8E2) : const Color(0xFFF4DFA8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.isRead ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
                  color: AppColors.buttonColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.of(context)
                                .listTileTitle
                                .copyWith(fontSize: 15),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC2483D),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: AppTypography.of(context)
                          .bodyDefault
                          .copyWith(color: const Color(0xFF39433D)),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitleParts.join(' • '),
                        style: AppTypography.of(context)
                            .badgeLabel
                            .copyWith(color: const Color(0xFF6E786F)),
                      ),
                    ],
                    if (!notification.isRead || ctaUrl != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!notification.isRead)
                              OutlinedButton.icon(
                                onPressed: () => usersProvider.markNotificationRead(notification.id),
                                icon: const Icon(Icons.done_rounded, size: 18),
                                label: Text('notifications_mark_read'.tr),
                              ),
                            if (ctaUrl != null)
                              FilledButton.tonalIcon(
                                onPressed: () => _openCtaUrl(context, ctaUrl),
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                label: Text('notifications_open_cta'.tr),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String? _extractCtaUrl() {
    final rawValue = notification.meta['ctaUrl'];
    if (rawValue is! String) {
      return null;
    }

    final trimmed = rawValue.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _openCtaUrl(BuildContext context, String ctaUrl) async {
    final uri = Uri.tryParse(ctaUrl);
    if (uri == null) {
      _showLaunchFailure(context);
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showLaunchFailure(context);
    }
  }

  void _showLaunchFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('notifications_cta_launch_failed'.tr),
      ),
    );
  }
}
