// ============================================================
// approval_service.dart
// خدمة إدارة طلبات الموافقة — تُستدعى من DatabaseService
// ============================================================

import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ApprovalService {
  final Database db;

  ApprovalService(this.db);

  // ------------------------------------------------------------------
  // إنشاء طلب جديد (يُستدعى من الموظف)
  // ------------------------------------------------------------------
  Future<int> createRequest({
    required String requestType,   // 'create' | 'update' | 'delete' | 'gis_add' | ...
    required String targetTable,   // 'criminal_cases' | 'gis_drawings'
    int? targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    required int requestedBy,
  }) async {
    final requestId = await db.insert('pending_requests', {
      'request_type': requestType,
      'target_table': targetTable,
      'target_id': targetId,
      'before_data': before != null ? jsonEncode(before) : null,
      'after_data': after != null ? jsonEncode(after) : null,
      'requested_by': requestedBy,
      'status': 'pending',
    });

    // إرسال إشعار لجميع المديرين
    await _notifyManagers(
      requestId: requestId,
      requestType: requestType,
      requestedBy: requestedBy,
    );

    return requestId;
  }

  // ------------------------------------------------------------------
  // الموافقة على طلب (المدير)
  // ------------------------------------------------------------------
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

    final afterData = req['after_data'] != null
        ? jsonDecode(req['after_data'].toString()) as Map<String, dynamic>
        : null;

    // تطبيق التعديل على الجدول الأصلي
    final table = req['target_table']?.toString() ?? 'criminal_cases';
    final targetId = req['target_id'] as int?;
    final type = req['request_type']?.toString() ?? '';

    await db.transaction((txn) async {
      if (type == 'create' && afterData != null) {
        await txn.insert(table, afterData);
      } else if (type == 'update' && afterData != null && targetId != null) {
        await txn.update(
          table,
          afterData,
          where: 'id = ?',
          whereArgs: [targetId],
        );
      } else if (type == 'delete' && targetId != null) {
        await txn.delete(table, where: 'id = ?', whereArgs: [targetId]);
      } else if (type == 'gis_add') {
        // تفعيل رسمة GIS المعلّقة
        await txn.update(
          'gis_pending_drawings',
          {'status': 'approved'},
          where: 'request_id = ?',
          whereArgs: [requestId],
        );
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
      final reviewer = await txn.query('users', where: 'id = ?', whereArgs: [reviewedBy]);
      final reviewerName = reviewer.isNotEmpty
          ? reviewer.first['employee_name']?.toString() ?? '-'
          : '-';

      await txn.insert('audit_logs', {
        'user_id': reviewedBy,
        'user_name': reviewerName,
        'operation': 'approve',
        'target_table': table,
        'target_id': targetId,
        'after_data': req['after_data'],
      });
    });

    // إشعار للموظف بالموافقة
    final requestedBy = req['requested_by'] as int;
    final typeLabel = _requestTypeLabel(type);
    await db.insert('notifications', {
      'user_id': requestedBy,
      'title': 'تمت الموافقة على طلبك',
      'body': 'تمت الموافقة على $typeLabel الخاص بك.',
      'type': 'approved',
      'related_request_id': requestId,
      'is_read': 0,
    });
  }

  // ------------------------------------------------------------------
  // رفض طلب (المدير)
  // ------------------------------------------------------------------
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

    await db.transaction((txn) async {
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

      final reviewer = await txn.query('users', where: 'id = ?', whereArgs: [reviewedBy]);
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
    });

    // إشعار للموظف بالرفض
    final requestedBy = req['requested_by'] as int;
    final type = req['request_type']?.toString() ?? '';
    await db.insert('notifications', {
      'user_id': requestedBy,
      'title': 'تم رفض طلبك',
      'body': 'تم رفض ${_requestTypeLabel(type)}. السبب: $reason',
      'type': 'rejected',
      'related_request_id': requestId,
      'is_read': 0,
    });
  }

  // ------------------------------------------------------------------
  // جلب الطلبات المعلّقة (للمدير)
  // ------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    return db.rawQuery('''
      SELECT
        pr.*,
        u_req.employee_name  AS requested_by_name,
        u_rev.employee_name  AS reviewed_by_name
      FROM pending_requests pr
      JOIN users u_req ON u_req.id = pr.requested_by
      LEFT JOIN users u_rev ON u_rev.id = pr.reviewed_by
      ORDER BY pr.created_at DESC
    ''');
  }

  // ------------------------------------------------------------------
  // جلب طلبات موظف بعينه
  // ------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getMyRequests(int userId) async {
    return db.rawQuery('''
      SELECT
        pr.*,
        u_req.employee_name  AS requested_by_name,
        u_rev.employee_name  AS reviewed_by_name
      FROM pending_requests pr
      JOIN users u_req ON u_req.id = pr.requested_by
      LEFT JOIN users u_rev ON u_rev.id = pr.reviewed_by
      WHERE pr.requested_by = ?
      ORDER BY pr.created_at DESC
    ''', [userId]);
  }

  // ------------------------------------------------------------------
  // عدد الطلبات المعلّقة (للـ badge)
  // ------------------------------------------------------------------
  Future<int> getPendingCount() async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM pending_requests WHERE status = 'pending'",
    );
    return (result.first['cnt'] as int? ?? 0);
  }

  // ------------------------------------------------------------------
  // مساعدات
  // ------------------------------------------------------------------
  Future<void> _notifyManagers({
    required int requestId,
    required String requestType,
    required int requestedBy,
  }) async {
    final managers = await db.query(
      'users',
      where: "role = 'manager' AND is_active = 1",
    );
    final requester = await db.query('users', where: 'id = ?', whereArgs: [requestedBy]);
    final requesterName = requester.isNotEmpty
        ? requester.first['employee_name']?.toString() ?? 'موظف'
        : 'موظف';

    for (final mgr in managers) {
      await db.insert('notifications', {
        'user_id': mgr['id'],
        'title': 'طلب جديد: ${_requestTypeLabel(requestType)}',
        'body': 'قدّم $requesterName طلب ${_requestTypeLabel(requestType)} ويحتاج مراجعتك.',
        'type': 'request_new',
        'related_request_id': requestId,
        'is_read': 0,
      });
    }
  }

  String _requestTypeLabel(String type) {
    switch (type) {
      case 'create':
        return 'إضافة محضر';
      case 'update':
        return 'تعديل محضر';
      case 'delete':
        return 'حذف محضر';
      case 'gis_add':
        return 'إضافة GIS';
      case 'gis_update':
        return 'تعديل GIS';
      case 'gis_delete':
        return 'حذف GIS';
      default:
        return type;
    }
  }
}
