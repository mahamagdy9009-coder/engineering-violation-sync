import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NotificationItem {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type;
  final int? relatedRequestId;
  final bool isRead;
  final String createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedRequestId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'info',
      relatedRequestId: map['related_request_id'] as int?,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: map['created_at']?.toString() ?? '',
    );
  }
}

class NotificationService extends ChangeNotifier {
  final Database db;
  NotificationService(this.db);

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> load(int userId) async {
    final rows = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 100,
    );
    _notifications = rows.map(NotificationItem.fromMap).toList();
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markRead(int notificationId, int userId) async {
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [notificationId, userId],
    );
    await load(userId);
  }

  Future<void> markAllRead(int userId) async {
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await load(userId);
  }

  Future<void> refresh(int userId) => load(userId);
}
