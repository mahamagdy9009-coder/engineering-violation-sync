import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ApprovalService {
  final Database db;
  ApprovalService(this.db);

  // ── إشعار المديرين عند وصول طلب جديد ─────────────────────
  Future<void> notifyManagersOfNewRequest({
    required int requestId,
    required String requestType,
    required int requestedBy,
  }) async {
    try {
      List<Map<String, dynamic>> managers = [];
      try {
        managers = await db.rawQuery('''
          SELECT users.id, users.employee_name
          FROM users
          JOIN roles ON roles.id = users.role_id
          WHERE roles.role_code = 'manager' AND users.is_active = 1
        ''');
      } catch (_) {
        try {
          managers = await db.rawQuery('''
            SELECT users.id, users.employee_name
            FROM users
            JOIN roles ON roles.id = users.role_id
            WHERE roles.code = 'manager' AND users.is_active = 1
          ''');
        } catch (_) {
          managers = [];
        }
      }

      if (managers.isEmpty) return;

      // تحديد اسم المرسل — إذا كان 0 فهو السكانر
      String requesterName = 'السكانر';
      if (requestedBy > 0) {
        final requester = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [requestedBy],
          limit: 1,
        );
        requesterName = requester.isNotEmpty
            ? requester.first['employee_name']?.toString() ?? 'موظف'
            : 'موظف';
      }

      final typeLabel = _requestTypeLabel(requestType);

      for (final mgr in managers) {
        try {
          await db.insert('notifications', {
            'user_id': mgr['id'],
            'title': 'طلب جديد: $typeLabel',
            'body': 'أرسل $requesterName طلب $typeLabel ويحتاج مراجعتك.',
            'type': 'request_new',
            'related_request_id': requestId,
            'is_read': 0,
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── جلب جميع الطلبات (للمدير) ─────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingRequests({
    String? status,
  }) async {
    final where = status != null ? "WHERE cr.status = '$status'" : '';
    try {
      return await db.rawQuery('''
        SELECT
          cr.*,
          u_req.employee_name AS requested_by_name,
          u_rev.employee_name AS reviewed_by_name
        FROM pending_requests cr
        LEFT JOIN users u_req ON u_req.id = cr.requested_by
        LEFT JOIN users u_rev ON u_rev.id = cr.reviewed_by
        $where
        ORDER BY cr.id DESC
      ''');
    } catch (_) {
      return [];
    }
  }

  // ── جلب طلبات موظف بعينه ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyRequests(int userId) async {
    try {
      return await db.rawQuery('''
        SELECT
          cr.*,
          u_req.employee_name AS requested_by_name,
          u_rev.employee_name AS reviewed_by_name
        FROM pending_requests cr
        LEFT JOIN users u_req ON u_req.id = cr.requested_by
        LEFT JOIN users u_rev ON u_rev.id = cr.reviewed_by
        WHERE cr.requested_by = ? OR (cr.requested_by IS NULL AND ? = 0)
        ORDER BY cr.id DESC
      ''', [userId, userId]);
    } catch (_) {
      return [];
    }
  }

  // ── عدد الطلبات المعلّقة ───────────────────────────────────
  Future<int> getPendingCount() async {
    try {
      final result = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM pending_requests WHERE status = 'pending'",
      );
      return (result.first['cnt'] as int? ?? 0);
    } catch (_) {
      return 0;
    }
  }

  // ── الموافقة على طلب ──────────────────────────────────────
  Future<void> approveRequest({
    required int requestId,
    required int reviewedBy,
  }) async {
    final rows = await db.query(
      'pending_requests',
      where: 'id = ?',
      whereArgs: [requestId],
    );
    if (rows.isEmpty) throw Exception('الطلب غير موجود');
    final req = rows.first;
    if (req['status'] != 'pending') throw Exception('الطلب ليس في حالة انتظار');

    final rawAfter = req['after_data'];
    final afterData = rawAfter != null
        ? jsonDecode(rawAfter.toString()) as Map<String, dynamic>
        : null;

    final table    = req['target_table']?.toString() ?? 'violation_cases';
    final targetId = req['target_id'] as int?;
    final type     = req['request_type']?.toString() ?? '';

    await db.transaction((txn) async {
      if ((type == 'create' || type == 'add') && afterData != null) {
        await txn.insert(table, afterData);

      } else if ((type == 'update' || type == 'edit') && afterData != null && targetId != null) {
        // ✅ حدّث فقط الحقول التي تغيّرت فعلاً تجنُّباً لأخطاء UNIQUE constraint
        final rawBefore = req['before_data'];
        Map<String, dynamic> updateData = afterData;
        if (rawBefore != null && rawBefore.toString().trim().isNotEmpty) {
          try {
            final beforeData =
                jsonDecode(rawBefore.toString()) as Map<String, dynamic>;
            final changed = <String, dynamic>{};
            for (final e in afterData.entries) {
              if (!_vEqual(e.value, beforeData[e.key])) {
                changed[e.key] = e.value;
              }
            }
            if (changed.isNotEmpty) updateData = changed;
          } catch (_) {}
        }
        await txn.update(
          table,
          updateData,
          where: 'id = ?',
          whereArgs: [targetId],
        );

      } else if (type == 'delete' && targetId != null) {
        await txn.delete(table, where: 'id = ?', whereArgs: [targetId]);

      } else if (type == 'attachment_add' && afterData != null) {
        // ✅ إدراج المرفق في جدول case_attachments بعد موافقة المدير
        try {
          await txn.execute('''
            CREATE TABLE IF NOT EXISTS case_attachments (
              id              INTEGER PRIMARY KEY AUTOINCREMENT,
              case_id         INTEGER,
              file_path       TEXT    NOT NULL,
              file_name       TEXT    NOT NULL,
              attachment_type TEXT    NOT NULL DEFAULT 'other',
              uploaded_by     TEXT,
              created_at      TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
            )
          ''');
        } catch (_) {}
        // إزالة حقل 'id' إن وُجد لتجنب تعارض المفاتيح
        final insertData = Map<String, dynamic>.from(afterData)..remove('id');
        await txn.insert('case_attachments', insertData);
      }

      // تحديث حالة الطلب
      await txn.update(
        'pending_requests',
        {
          'status': 'approved',
          'reviewed_by': reviewedBy,
          'reviewed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );

      // تسجيل في audit_logs
      try {
        final reviewer = await txn.query(
          'users',
          where: 'id = ?',
          whereArgs: [reviewedBy],
        );
        final reviewerName = reviewer.isNotEmpty
            ? reviewer.first['employee_name']?.toString() ?? '-'
            : '-';
        await txn.insert('audit_logs', {
          'user_id': reviewedBy,
          'user_name': reviewerName,
          'operation': 'approve',
          'target_table': table,
          'target_id': targetId,
          'after_data': rawAfter,
        });
      } catch (_) {}
    });

    // إشعار الموظف بالموافقة (ما عدا السكانر)
    try {
      final requestedBy = req['requested_by'] as int?;
      if (requestedBy != null && requestedBy > 0) {
        final typeLabel = _requestTypeLabel(type);
        await db.insert('notifications', {
          'user_id': requestedBy,
          'title': 'تمت الموافقة على طلبك ✓',
          'body': 'تمت الموافقة على $typeLabel الخاص بك وتطبيقه.',
          'type': 'approved',
          'related_request_id': requestId,
          'is_read': 0,
        });
      }
    } catch (_) {}
  }

  // ── رفض طلب ───────────────────────────────────────────────
  Future<void> rejectRequest({
    required int requestId,
    required int reviewedBy,
    required String reason,
  }) async {
    final rows = await db.query(
      'pending_requests',
      where: 'id = ?',
      whereArgs: [requestId],
    );
    if (rows.isEmpty) throw Exception('الطلب غير موجود');
    final req = rows.first;
    if (req['status'] != 'pending') throw Exception('الطلب ليس في حالة انتظار');

    final type = req['request_type']?.toString() ?? '';

    await db.transaction((txn) async {
      // ✅ عند رفض مرفق — احذف الملف المحفوظ مؤقتاً
      if (type == 'attachment_add') {
        try {
          final rawAfter = req['after_data'];
          if (rawAfter != null) {
            final afterData = jsonDecode(rawAfter.toString()) as Map<String, dynamic>;
            final filePath = afterData['file_path']?.toString();
            if (filePath != null && filePath.isNotEmpty) {
              final file = File(filePath);
              if (await file.exists()) await file.delete();
            }
          }
        } catch (_) {}
      }

      await txn.update(
        'pending_requests',
        {
          'status': 'rejected',
          'reviewed_by': reviewedBy,
          'rejection_reason': reason,
          'reviewed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );

      try {
        final reviewer = await txn.query(
          'users',
          where: 'id = ?',
          whereArgs: [reviewedBy],
        );
        final reviewerName = reviewer.isNotEmpty
            ? reviewer.first['employee_name']?.toString() ?? '-'
            : '-';
        await txn.insert('audit_logs', {
          'user_id': reviewedBy,
          'user_name': reviewerName,
          'operation': 'reject',
          'target_table': req['target_table']?.toString() ?? '',
          'target_id': req['target_id'],
          'before_data': req['before_data'],
        });
      } catch (_) {}
    });

    // إشعار الموظف بالرفض (ما عدا السكانر)
    try {
      final requestedBy = req['requested_by'] as int?;
      if (requestedBy != null && requestedBy > 0) {
        await db.insert('notifications', {
          'user_id': requestedBy,
          'title': 'تم رفض طلبك ✗',
          'body': 'تم رفض ${_requestTypeLabel(type)}. السبب: $reason',
          'type': 'rejected',
          'related_request_id': requestId,
          'is_read': 0,
        });
      }
    } catch (_) {}
  }

  /// مقارنة قيمتين مع تطبيع الأرقام (0 == 0.0) والقيم الفارغة
  bool _vEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    final sa = (a?.toString() ?? '').trim();
    final sb = (b?.toString() ?? '').trim();
    if (sa == sb) return true;
    // تطبيع رقمي: 0 يساوي 0.0
    final na = num.tryParse(sa);
    final nb = num.tryParse(sb);
    if (na != null && nb != null) return na == nb;
    return false;
  }

  String _requestTypeLabel(String type) {
    switch (type) {
      case 'create':
      case 'add':
        return 'إضافة محضر';
      case 'update':
      case 'edit':
        return 'تعديل محضر';
      case 'delete':
        return 'حذف محضر';
      case 'attachment_add':
        return 'إرفاق صورة';
      default:
        return type;
    }
  }
}
