// ============================================================
// sync_log_service.dart
// تسجيل التعديلات في sync_log لإرسالها للسيرفر لاحقاً
// ============================================================

import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SyncLogService {
  // الجداول التي لا نُزامنها (جداول نظام داخلية)
  static const _skipTables = {
    'sync_log',
    'app_settings',
    'device_registry',
    'user_sessions',
    'audit_logs',
    'notifications',
    'pending_requests',
  };

  /// تسجيل عملية (insert/update/delete) في sync_log
  static Future<void> logChange({
    required Database db,
    required String deviceId,
    required String tableName,
    required int? recordId,
    required String operation, // 'insert' | 'update' | 'delete'
    required Map<String, dynamic> dataJson,
  }) async {
    if (_skipTables.contains(tableName)) return;
    if (deviceId.isEmpty) return;

    try {
      await db.insert('sync_log', {
        'device_id': deviceId,
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'data_json': jsonEncode(dataJson),
        'synced': 0,
      });
    } catch (_) {}
  }

  /// جلب الإدخالات غير المُزامَنة بعد للسيرفر
  static Future<List<Map<String, dynamic>>> getUnsynced(
      Database db) async {
    try {
      return await db.query(
        'sync_log',
        where: 'synced = 0',
        orderBy: 'id ASC',
        limit: 500,
      );
    } catch (_) {
      return [];
    }
  }

  /// تعليم إدخالات على أنها مُزامَنة
  static Future<void> markSynced(
      Database db, List<int> ids, int maxServerId) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    try {
      await db.rawUpdate(
        'UPDATE sync_log SET synced = 1, server_id = ? '
        'WHERE id IN ($placeholders)',
        [maxServerId, ...ids],
      );
    } catch (_) {}
  }

  /// آخر server_id مُستلَم (للسحب من هذا الرقم للأمام)
  static Future<int> getLastServerSeq(Database db) async {
    try {
      // أولاً: من app_settings (أحدث قيمة محفوظة بعد pull)
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['last_pull_seq'],
      );
      if (rows.isNotEmpty) {
        return int.tryParse(rows.first['value']?.toString() ?? '0') ?? 0;
      }
      // ثانياً: من sync_log مباشرة
      final logRows = await db.rawQuery(
        'SELECT MAX(server_id) AS last_seq FROM sync_log '
        'WHERE server_id IS NOT NULL',
      );
      return (logRows.first['last_seq'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// عدد الإدخالات المعلّقة (غير مُزامَنة)
  static Future<int> getPendingCount(Database db) async {
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM sync_log WHERE synced = 0',
      );
      return (rows.first['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
