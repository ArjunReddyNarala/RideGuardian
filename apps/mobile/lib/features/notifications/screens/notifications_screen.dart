import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/india_time.dart';
import '../models/app_notification.dart';
import '../services/notifications_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.notificationsApiService,
    required this.onUnreadCountChanged,
  });

  final NotificationsApiService notificationsApiService;
  final ValueChanged<int> onUnreadCountChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  bool _markingAllRead = false;
  int _unreadCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await widget.notificationsApiService
          .getNotifications(limit: 100);
      final unreadCount = await widget.notificationsApiService.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _loading = false;
        _error = null;
      });
      _notifyUnreadCount();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _notifyUnreadCount() {
    widget.onUnreadCountChanged(_unreadCount);
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await widget.notificationsApiService.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(isRead: true, readAt: DateTime.now())
                  : item,
            )
            .toList();
        if (_unreadCount > 0) _unreadCount--;
      });
      _notifyUnreadCount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notification: $error')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0 || _markingAllRead) return;
    setState(() => _markingAllRead = true);
    try {
      await widget.notificationsApiService.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item.copyWith(isRead: true, readAt: DateTime.now()))
            .toList();
        _unreadCount = 0;
      });
      _notifyUnreadCount();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not mark notifications as read: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _unreadCount == 0 || _markingAllRead
                ? null
                : _markAllAsRead,
            child: _markingAllRead
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _notifications.isEmpty
          ? _buildError(colors)
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? _buildEmptyState(colors)
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = _accentFor(notification.type);
    final createdAt = toIndiaStandardTime(notification.createdAt);
    final time =
        '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}  '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')} IST';

    return Material(
      color: notification.isRead
          ? colors.surface
          : AppColors.primary.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _markAsRead(notification),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.isRead
                  ? colors.outlineVariant
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
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

  Widget _buildEmptyState(ColorScheme colors) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(28),
    children: [
      const SizedBox(height: 100),
      Icon(
        Icons.notifications_none_rounded,
        size: 58,
        color: colors.onSurfaceVariant,
      ),
      const SizedBox(height: 16),
      Text(
        'You’re all caught up',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Ride updates, guardian invitations, and safety alerts will appear here.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: colors.onSurfaceVariant),
      ),
    ],
  );

  Widget _buildError(ColorScheme colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          const Text('Could not load notifications'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _loadNotifications();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  IconData _iconFor(String type) {
    if (type == 'ALERT_RESOLVED' || type == 'RIDE_ENDED') {
      return Icons.check_circle_outline_rounded;
    }
    if (type.contains('SPEED') ||
        type.contains('SAFETY') ||
        type.contains('ALERT')) {
      return Icons.warning_amber_rounded;
    }
    if (type.contains('INVITATION')) return Icons.person_add_alt_1_rounded;
    return Icons.route_rounded;
  }

  Color _accentFor(String type) {
    if (type == 'ALERT_RESOLVED' || type == 'RIDE_ENDED') {
      return AppColors.primary;
    }
    if (type.contains('SPEED') ||
        type.contains('SAFETY') ||
        type.contains('ALERT')) {
      return AppColors.warning;
    }
    if (type.contains('INVITATION')) return const Color(0xFF8B5CF6);
    return AppColors.primary;
  }
}
