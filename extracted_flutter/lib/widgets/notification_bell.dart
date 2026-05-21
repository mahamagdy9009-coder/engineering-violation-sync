// ============================================================
// notification_bell.dart
// أيقونة الجرس مع Badge — تُضاف في أي AppBar أو Header
// ============================================================

import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/approval_service.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.notificationService,
    required this.currentUser,
    this.approvalService,
  });

  final NotificationService notificationService;
  final Map<String, dynamic> currentUser;
  final ApprovalService? approvalService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notificationService,
      builder: (context, _) {
        final count = notificationService.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'الإشعارات',
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      notificationService: notificationService,
                      currentUser: currentUser,
                      approvalService: approvalService,
                    ),
                  ),
                );
              },
            ),
            if (count > 0)
              Positioned(
                top: 6,
                left: 6,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5C07B),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: const TextStyle(
                          color: Color(0xFF05352D),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
