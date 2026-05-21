// ============================================================
// database_service_additions.dart
//
// أضف هذه الدوال داخل DatabaseService الموجود لديك.
// لا تحذف أي دوال قديمة — فقط أضف هذه الدوال الجديدة.
//
// ستحتاج أيضًا إلى تعديل initDatabase() كما هو موضح أدناه.
// ============================================================

// ─────────────────────────────────────────────────────────────
// 1. تعديل initDatabase() — أضف هذا السطر داخل onUpgrade
// ─────────────────────────────────────────────────────────────
//
//  static Future<Database> initDatabase() async {
//    ...
//    return openDatabase(
//      path,
//      version: DatabaseMigrations.targetVersion,   // ← غيّر الرقم هنا
//      onCreate: (db, version) async {
//        // ... إنشاء الجداول القديمة ...
//        await DatabaseMigrations.runMigrations(db, 0, version); // ← أضف هذا
//      },
//      onUpgrade: (db, oldVersion, newVersion) async {
//        await DatabaseMigrations.runMigrations(db, oldVersion, newVersion); // ← أضف هذا
//      },
//    );
//  }
//
// ─────────────────────────────────────────────────────────────
// 2. الدوال الجديدة — أضفها داخل class DatabaseService
// ─────────────────────────────────────────────────────────────

// import 'package:your_app/services/approval_service.dart';
// import 'package:your_app/services/notification_service.dart';

// ── Lazy singletons للخدمات ────────────────────────────────────
//
//  static ApprovalService? _approvalService;
//  static NotificationService? _notificationService;
//
//  static Future<ApprovalService> getApprovalService() async {
//    final db = await _database;
//    return _approvalService ??= ApprovalService(db);
//  }
//
//  static Future<NotificationService> getNotificationService() async {
//    final db = await _database;
//    return _notificationService ??= NotificationService(db);
//  }
//
// ─────────────────────────────────────────────────────────────

// ── تعديل submitCaseChangeRequest ─────────────────────────────
// استبدل الدالة الموجودة بهذه:
//
//  static Future<void> submitCaseChangeRequest({
//    required String requestType,
//    int? targetId,
//    Map<String, dynamic>? before,
//    Map<String, dynamic>? after,
//    int? requestedBy,
//  }) async {
//    final svc = await getApprovalService();
//    await svc.createRequest(
//      requestType: requestType,
//      targetTable: 'criminal_cases',
//      targetId: targetId,
//      before: before,
//      after: after,
//      requestedBy: requestedBy ?? 0,
//    );
//  }
//
// ─────────────────────────────────────────────────────────────

// ── getDashboardStats — أضف total_pending ─────────────────────
// تأكد أن getDashboardStats تُعيد total_pending:
//
//  static Future<Map<String, dynamic>> getDashboardStats() async {
//    final db = await _database;
//    final cases     = await db.rawQuery("SELECT COUNT(*) AS c FROM criminal_cases");
//    final drains    = await db.rawQuery("SELECT COUNT(*) AS c FROM drains");
//    final types     = await db.rawQuery("SELECT COUNT(*) AS c FROM violation_types");
//    final pending   = await db.rawQuery(
//      "SELECT COUNT(*) AS c FROM pending_requests WHERE status = 'pending'"
//    );
//    return {
//      'total_cases':   (cases.first['c']   as int? ?? 0),
//      'total_drains':  (drains.first['c']  as int? ?? 0),
//      'total_types':   (types.first['c']   as int? ?? 0),
//      'total_pending': (pending.first['c'] as int? ?? 0),
//    };
//  }
//
// ─────────────────────────────────────────────────────────────

// ── login — تأكد أنه يُعيد role ───────────────────────────────
// تأكد أن دالة login ترجع كل حقول جدول users:
//
//  static Future<Map<String, dynamic>?> login({
//    required String username,
//    required String password,
//  }) async {
//    final db = await _database;
//    final rows = await db.query(
//      'users',
//      where: 'username = ? AND password_hash = ? AND is_active = 1',
//      whereArgs: [username, password],
//    );
//    if (rows.isEmpty) return null;
//    return rows.first;
//  }
//
// ─────────────────────────────────────────────────────────────

// ── GIS pending — حفظ رسومات GIS معلّقة ──────────────────────
//
//  static Future<void> submitGisDrawingRequest({
//    required Map<String, dynamic> drawing,
//    required int requestedBy,
//  }) async {
//    final svc = await getApprovalService();
//    final requestId = await svc.createRequest(
//      requestType: 'gis_add',
//      targetTable: 'gis_drawings',
//      after: drawing,
//      requestedBy: requestedBy,
//    );
//    final db = await _database;
//    await db.insert('gis_pending_drawings', {
//      'request_id':   requestId,
//      'draw_type':    drawing['type'] ?? 'polyline',
//      'geojson':      drawing['geojson'] ?? '',
//      'name':         drawing['name'],
//      'project_type': drawing['projectType'],
//      'description':  drawing['description'],
//      'offender_name':drawing['offenderName'],
//      'report_number':drawing['reportNumber'],
//      'report_year':  drawing['reportYear'],
//      'notes':        drawing['notes'],
//      'color_value':  drawing['colorValue'] ?? 4284624870,
//    });
//  }
//
//  static Future<List<Map<String, dynamic>>> getApprovedGisDrawings() async {
//    final db = await _database;
//    return db.query(
//      'gis_pending_drawings',
//      where: "status = 'approved'",
//    );
//  }
//
// ─────────────────────────────────────────────────────────────

// ── Audit log helper ───────────────────────────────────────────
//
//  static Future<void> writeAuditLog({
//    required int userId,
//    required String userName,
//    required String operation,
//    required String targetTable,
//    int? targetId,
//    String? beforeData,
//    String? afterData,
//  }) async {
//    final db = await _database;
//    await db.insert('audit_logs', {
//      'user_id':      userId,
//      'user_name':    userName,
//      'operation':    operation,
//      'target_table': targetTable,
//      'target_id':    targetId,
//      'before_data':  beforeData,
//      'after_data':   afterData,
//      'device_info':  Platform.operatingSystem,
//    });
//  }
