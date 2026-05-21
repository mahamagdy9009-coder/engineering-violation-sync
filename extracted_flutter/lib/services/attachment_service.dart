// ============================================================
// attachment_service.dart — خدمة المرفقات الموحّدة
// ضعه في: lib/services/attachment_service.dart
// ============================================================
// التعديل: الصور المُستلمة من السكانر تذهب لطلب اعتماد
//          عند المدير بدلاً من الحفظ المباشر
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_service.dart';
import 'attachment_server.dart';

// ── نموذج المرفق ─────────────────────────────────────────────
class AttachmentRecord {
  final int? id;
  final int? caseId;
  final String filePath;
  final String fileName;
  final String attachmentType;
  final String? uploadedBy;
  final String createdAt;

  const AttachmentRecord({
    this.id,
    this.caseId,
    required this.filePath,
    required this.fileName,
    required this.attachmentType,
    this.uploadedBy,
    required this.createdAt,
  });

  factory AttachmentRecord.fromMap(Map<String, dynamic> m) =>
      AttachmentRecord(
        id: m['id'] as int?,
        caseId: m['case_id'] as int?,
        filePath: m['file_path']?.toString() ?? '',
        fileName: m['file_name']?.toString() ?? '',
        attachmentType: m['attachment_type']?.toString() ?? 'other',
        uploadedBy: m['uploaded_by']?.toString(),
        createdAt: m['created_at']?.toString() ?? '',
      );

  bool get fileExists => File(filePath).existsSync();
  bool get isImage {
    final ext = p.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.bmp'].contains(ext);
  }

  String get typeLabel {
    switch (attachmentType) {
      case 'report':    return 'صورة المحضر';
      case 'id_card':   return 'صورة الهوية';
      case 'removal':   return 'قرار الإزالة';
      default:          return 'مستند آخر';
    }
  }
}

// ─────────────────────────────────────────────────────────────
class AttachmentService {
  AttachmentService._();
  static final AttachmentService instance = AttachmentService._();

  final AttachmentServer _server = AttachmentServer();

  // ── Stream يُبثّ إشعاراً عند وصول صورة جديدة (معلّقة للاعتماد)
  final _controller = StreamController<AttachmentRecord>.broadcast();
  Stream<AttachmentRecord> get onNewAttachment => _controller.stream;

  bool get serverRunning => _server.isRunning;

  // ── تهيئة جدول case_attachments ──────────────────────────
  static Future<void> ensureTable(Database db) async {
    await db.execute('''
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
  }

  // ── بدء الخادم ────────────────────────────────────────────
  Future<void> start() async {
    if (_server.isRunning) return;
    await _server.start(
      onReceived: (filePath, attachmentType, reportId) async {
        // ✅ بدلاً من الحفظ المباشر، نُنشئ طلب اعتماد للمدير
        await _submitApprovalRequest(
          filePath: filePath,
          attachmentType: attachmentType,
          reportId: reportId,
        );
      },
    );
  }

  // ── إنشاء طلب اعتماد للصورة الواردة من السكانر ────────────
  Future<void> _submitApprovalRequest({
    required String filePath,
    required String attachmentType,
    required String reportId,
  }) async {
    try {
      final caseId  = int.tryParse(reportId);
      final fileName = p.basename(filePath);
      final db      = await DatabaseService.database;

      // حفظ بيانات المرفق كـ JSON في حقل after_data
      final afterJson = jsonEncode({
        'case_id':         caseId,
        'file_path':       filePath,
        'file_name':       fileName,
        'attachment_type': attachmentType,
        'uploaded_by':     'scanner',
        'created_at':      DateTime.now().toIso8601String(),
      });

      // إدراج الطلب في جدول pending_requests
      final requestId = await db.insert('pending_requests', {
        'request_type': 'attachment_add',
        'target_table': 'case_attachments',
        'target_id':    caseId,
        'before_data':  '{}',
        'after_data':   afterJson,
        'requested_by': 0,       // 0 = السكانر (نظام)
        'status':       'pending',
      });

      // إرسال إشعار للمديرين
      try {
        final approvalSvc = await DatabaseService.getApprovalService();
        await approvalSvc.notifyManagersOfNewRequest(
          requestId:   requestId,
          requestType: 'attachment_add',
          requestedBy: 0,
        );
      } catch (_) {}

      // إبلاغ الشاشات بوجود طلب معلّق (ليس مرفقاً مقبولاً بعد)
      _controller.add(AttachmentRecord(
        caseId:         caseId,
        filePath:       filePath,
        fileName:       fileName,
        attachmentType: attachmentType,
        uploadedBy:     'scanner',
        createdAt:      DateTime.now().toIso8601String(),
      ));
    } catch (_) {
      // Fallback: في حالة خطأ فادح، نحفظ مباشرة
      final caseId = int.tryParse(reportId);
      final record = await _saveToDb(
        filePath:       filePath,
        attachmentType: attachmentType,
        caseId:         caseId,
        uploadedBy:     'scanner',
      );
      if (record != null) _controller.add(record);
    }
  }

  // ── إيقاف الخادم ──────────────────────────────────────────
  Future<void> stop() async {
    await _server.stop();
  }

  // ── حفظ مرفق مباشرة في قاعدة البيانات (fallback أو يدوي) ─
  Future<AttachmentRecord?> _saveToDb({
    required String filePath,
    required String attachmentType,
    int? caseId,
    String? uploadedBy,
  }) async {
    try {
      final db = await DatabaseService.database;
      await ensureTable(db);

      final fileName = p.basename(filePath);
      final id = await db.insert('case_attachments', {
        'case_id':         caseId,
        'file_path':       filePath,
        'file_name':       fileName,
        'attachment_type': attachmentType,
        'uploaded_by':     uploadedBy,
        'created_at':      DateTime.now().toIso8601String(),
      });

      return AttachmentRecord(
        id:             id,
        caseId:         caseId,
        filePath:       filePath,
        fileName:       fileName,
        attachmentType: attachmentType,
        uploadedBy:     uploadedBy,
        createdAt:      DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── إضافة مرفق يدوياً (من file_picker مثلاً) ─────────────
  // ملاحظة: هذه الدالة تُرسل طلب اعتماد أيضاً
  Future<void> addManualWithApproval({
    required String filePath,
    required String attachmentType,
    required int caseId,
    required int requestedBy,
  }) async {
    try {
      final fileName = p.basename(filePath);
      final db = await DatabaseService.database;

      final afterJson = jsonEncode({
        'case_id':         caseId,
        'file_path':       filePath,
        'file_name':       fileName,
        'attachment_type': attachmentType,
        'uploaded_by':     requestedBy.toString(),
        'created_at':      DateTime.now().toIso8601String(),
      });

      final requestId = await db.insert('pending_requests', {
        'request_type': 'attachment_add',
        'target_table': 'case_attachments',
        'target_id':    caseId,
        'before_data':  '{}',
        'after_data':   afterJson,
        'requested_by': requestedBy,
        'status':       'pending',
      });

      try {
        final approvalSvc = await DatabaseService.getApprovalService();
        await approvalSvc.notifyManagersOfNewRequest(
          requestId:   requestId,
          requestType: 'attachment_add',
          requestedBy: requestedBy,
        );
      } catch (_) {}
    } catch (_) {}
  }

  // ── إضافة مرفق يدوياً بدون اعتماد (للمدير مباشرة) ─────────
  Future<AttachmentRecord?> addManual({
    required String filePath,
    required String attachmentType,
    required int caseId,
    String? uploadedBy,
  }) async {
    final record = await _saveToDb(
      filePath:       filePath,
      attachmentType: attachmentType,
      caseId:         caseId,
      uploadedBy:     uploadedBy,
    );
    if (record != null) _controller.add(record);
    return record;
  }

  // ── جلب مرفقات قضية معينة (المعتمدة فقط) ────────────────
  Future<List<AttachmentRecord>> getForCase(int caseId) async {
    try {
      final db = await DatabaseService.database;
      await ensureTable(db);
      final rows = await db.query(
        'case_attachments',
        where: 'case_id = ?',
        whereArgs: [caseId],
        orderBy: 'created_at DESC',
      );
      return rows.map(AttachmentRecord.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  // ── حذف مرفق ─────────────────────────────────────────────
  Future<void> delete(AttachmentRecord record) async {
    try {
      final db = await DatabaseService.database;
      if (record.id != null) {
        await db.delete('case_attachments',
            where: 'id = ?', whereArgs: [record.id]);
      }
      final file = File(record.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void dispose() {
    _controller.close();
    _server.stop();
  }
}
