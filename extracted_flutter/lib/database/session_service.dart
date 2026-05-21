// ============================================================
// session_service.dart
// تتبع جلسات الدخول والخروج
// ضعه في: lib/database/session_service.dart
// ============================================================

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SessionService {
  final Database db;
  SessionService(this.db);

  int? _currentSessionId;

  // ── تسجيل الدخول ─────────────────────────────────────────
  Future<void> onLogin(int userId) async {
    try {
      _currentSessionId = await db.insert('user_sessions', {
        'user_id': userId,
        'login_at': DateTime.now().toIso8601String(),
        'device_info': Platform.operatingSystem,
      });

      // تسجيل في audit_logs
      final user = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      final name = user.isNotEmpty
          ? user.first['employee_name']?.toString() ?? '-'
          : '-';

      await db.insert('audit_logs', {
        'user_id': userId,
        'user_name': name,
        'operation': 'login',
        'target_table': 'users',
        'target_id': userId,
        'device_info': Platform.operatingSystem,
      });
    } catch (_) {
      // لا نوقف التطبيق عند فشل تسجيل الجلسة
    }
  }

  // ── تسجيل الخروج ─────────────────────────────────────────
  Future<void> onLogout(int userId) async {
    try {
      if (_currentSessionId != null) {
        await db.update(
          'user_sessions',
          {'logout_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [_currentSessionId],
        );
        _currentSessionId = null;
      }

      // تسجيل في audit_logs
      final user = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      final name = user.isNotEmpty
          ? user.first['employee_name']?.toString() ?? '-'
          : '-';

      await db.insert('audit_logs', {
        'user_id': userId,
        'user_name': name,
        'operation': 'logout',
        'target_table': 'users',
        'target_id': userId,
        'device_info': Platform.operatingSystem,
      });
    } catch (_) {}
  }

  // ── إغلاق الجلسة عند إغلاق التطبيق (استدعِها في dispose) ──
  Future<void> onAppClose(int userId) => onLogout(userId);
}
