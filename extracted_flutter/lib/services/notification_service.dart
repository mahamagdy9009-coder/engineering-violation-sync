// ============================================================
// notification_service.dart
// خدمة الإشعارات الداخلية — تُدار عبر ChangeNotifier
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  final Database db;

  NotificationService(this.db);

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  // ------------------------------------------------------------------
  // تحميل إشعارات المستخدم
  // ------------------------------------------------------------------
  Future<void> load(int userId) async {
    final rows = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 100,
    );

    _notifications = rows.map(AppNotification.fromMap).toList();
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // تعليم إشعار كمقروء
  // ------------------------------------------------------------------
  Future<void> markRead(int notificationId, int userId) async {
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [notificationId, userId],
    );
    await load(userId);
  }

  // ------------------------------------------------------------------
  // تعليم كل الإشعارات كمقروءة
  // ------------------------------------------------------------------
  Future<void> markAllRead(int userId) async {
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await load(userId);
  }

  // ------------------------------------------------------------------
  // تحديث دوري (استدعِه كل 30 ثانية من Timer)
  // ------------------------------------------------------------------
  Future<void> refresh(int userId) => load(userId);
}
