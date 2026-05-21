// ============================================================
// notifications_screen.dart
// شاشة الإشعارات — للموظف والمدير
// ============================================================

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'approval_screen.dart';
import '../services/approval_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.notificationService,
    required this.currentUser,
    this.approvalService,
  });

  final NotificationService notificationService;
  final Map<String, dynamic> currentUser;
  final ApprovalService? approvalService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.notificationService.load(widget.currentUser['id'] as int);
  }

  Future<void> _markAllRead() async {
    await widget.notificationService.markAllRead(widget.currentUser['id'] as int);
  }

  Future<void> _openNotification(AppNotification notif) async {
    final userId = widget.currentUser['id'] as int;
    await widget.notificationService.markRead(notif.id, userId);

    if (!mounted) return;

    // إن كان هناك طلب مرتبط وكان المستخدم مديرًا، افتح شاشة الموافقة
    if (notif.relatedRequestId != null &&
        widget.currentUser['role'] == 'manager' &&
        widget.approvalService != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApprovalScreen(
            approvalService: widget.approvalService!,
            currentUser: widget.currentUser,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF05352D),
          foregroundColor: Colors.white,
          title: const Text('الإشعارات'),
          actions: [
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'تعليم الكل كمقروء',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: widget.notificationService,
          builder: (context, _) {
            final notifs = widget.notificationService.notifications;
            if (notifs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 64, color: Color(0xFF0B6B55)),
                    SizedBox(height: 12),
                    Text(
                      'لا توجد إشعارات',
                      style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF05352D),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final notif = notifs[i];
                return _NotificationTile(
                  notification: notif,
                  onTap: () => _openNotification(notif),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Single notification tile ───────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  Color get _typeColor {
    switch (notification.type) {
      case 'approved':
        return const Color(0xFF0B6B55);
      case 'rejected':
        return const Color(0xFFB42318);
      case 'request_new':
        return const Color(0xFF05352D);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF0FFF8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE5DCC8)
                : const Color(0xFF0B6B55).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForType(notification.type),
                color: _typeColor,
                size: 20,
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
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF05352D),
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B6B55),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'request_new':
        return Icons.pending_actions_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
