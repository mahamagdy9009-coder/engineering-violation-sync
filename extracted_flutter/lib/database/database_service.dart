// ============================================================
// database_service.dart  — نسخة معدّلة
// التعديلات:
//   1. getDashboardStats() — إحصائيات أشمل للداشبورد
//   2. إضافة جدولي regularization_files و license_files
//      (لعدّ ملفات التقنين والتراخيص مستقبلاً)
// كل الكود الأصلي محفوظ كما هو
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/case_filter.dart';

// ── خدمات الإشعارات والاعتمادات ───────────────────────────────
import '../notifications/notification_service.dart';
import '../notifications/approval_service.dart';

class DatabaseService {
  static Database? _database;
  static bool _newTablesReady = false;
  static String? lastSetupError;

  // ── Singletons للخدمات ────────────────────────────────────
  static NotificationService? _notificationService;
  static ApprovalService? _approvalService;

  static Future<Database> get database async {
    if (_database == null) {
      _database = await _initDatabase();
      try { await _ensureDefaultAdmin(_database!); } catch (_) {}
      try { await _ensureManagerAccount(_database!); } catch (_) {}
    }
    if (!_newTablesReady) {
      try {
        await _initNewTables(_database!);
      } catch (_) {}
      _newTablesReady = true;
    }
    return _database!;
  }

  static Future<NotificationService> getNotificationService() async {
    final db = await database;
    return _notificationService ??= NotificationService(db);
  }

  static Future<ApprovalService> getApprovalService() async {
    final db = await database;
    return _approvalService ??= ApprovalService(db);
  }

  // ── إنشاء الجداول (الأصلية + الجديدة) ────────────────────
  static Future<void> _initNewTables(Database db) async {
    // ── جدول الطلبات المعلّقة (pending_requests) ──────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_requests (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        request_type     TEXT    NOT NULL,
        target_table     TEXT    NOT NULL DEFAULT 'violation_cases',
        target_id        INTEGER,
        before_data      TEXT,
        after_data       TEXT,
        requested_by     INTEGER,
        reviewed_by      INTEGER,
        status           TEXT    NOT NULL DEFAULT 'pending',
        rejection_reason TEXT,
        created_at       TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
        reviewed_at      TEXT
      )
    ''');

    // ── جدول الإشعارات ───────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id            INTEGER NOT NULL,
        title              TEXT    NOT NULL,
        body               TEXT    NOT NULL,
        type               TEXT    NOT NULL DEFAULT 'info',
        related_request_id INTEGER,
        is_read            INTEGER NOT NULL DEFAULT 0,
        created_at         TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // ── جدول جلسات المستخدمين ────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_sessions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        login_at    TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
        logout_at   TEXT,
        device_info TEXT
      )
    ''');

    // ── جدول مرفقات القضايا ───────────────────────────────────
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

    // ── جدول ملفات التقنين ── جديد ───────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS regularization_files (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        case_id     INTEGER,
        file_number TEXT,
        file_date   TEXT,
        status      TEXT    NOT NULL DEFAULT 'active',
        notes       TEXT,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // ── جدول ملفات التراخيص ── جديد ──────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS license_files (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        case_id      INTEGER,
        license_number TEXT,
        license_date TEXT,
        contractor   TEXT,
        status       TEXT    NOT NULL DEFAULT 'active',
        notes        TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // ── إضافة الأعمدة الجديدة إلى violation_cases إن لم تكن موجودة ──
      for (final colDef in [
        "ALTER TABLE violation_cases ADD COLUMN approval_status TEXT DEFAULT 'pending'",
        "ALTER TABLE violation_cases ADD COLUMN source_sheet TEXT",
        "ALTER TABLE violation_cases ADD COLUMN source_row INTEGER",
        "ALTER TABLE violation_cases ADD COLUMN kilometer_location TEXT",
        "ALTER TABLE violation_cases ADD COLUMN percent_47_value REAL",
        "ALTER TABLE violation_cases ADD COLUMN restoration_value REAL",
        "ALTER TABLE violation_cases ADD COLUMN usufruct_value REAL",
        "ALTER TABLE violation_cases ADD COLUMN total_dues REAL",
        "ALTER TABLE violation_cases ADD COLUMN admin_seizure_value REAL",
        "ALTER TABLE violation_cases ADD COLUMN paid_amount REAL",
        "ALTER TABLE violation_cases ADD COLUMN violation_type_ids TEXT",
      ]) {
        try { await db.execute(colDef); } catch (_) {}
      }

      // ── إضافة عمود device_info في audit_logs إن لم يكن موجوداً
    try {
      await db.execute('ALTER TABLE audit_logs ADD COLUMN device_info TEXT');
    } catch (_) {}

    // ── حساب المدير في roles ─────────────────────────────────
    List<Map<String, dynamic>> managerRole = [];
    String roleCodeCol = 'role_code';
    try {
      managerRole = await db.query('roles',
          where: 'role_code = ?', whereArgs: ['manager'], limit: 1);
    } catch (_) {
      try {
        roleCodeCol = 'code';
        managerRole = await db.query('roles',
            where: 'code = ?', whereArgs: ['manager'], limit: 1);
      } catch (_) {
        managerRole = [];
        roleCodeCol = '';
      }
    }

    int managerRoleId;
    if (managerRole.isEmpty && roleCodeCol.isNotEmpty) {
      try {
        managerRoleId = await db.insert('roles', {
          roleCodeCol: 'manager',
          'name_ar': 'مدير',
        });
      } catch (_) {
        managerRoleId = 1;
      }
    } else if (managerRole.isNotEmpty) {
      managerRoleId = managerRole.first['id'] as int? ?? 1;
    } else {
      managerRoleId = 1;
    }

    int employeeRoleId = 1;
    try {
      final allRoles = await db.query('roles');
      for (final r in allRoles) {
        final isManager = r.values.any((v) => v?.toString() == 'manager');
        if (!isManager) {
          employeeRoleId = r['id'] as int? ?? 1;
          break;
        }
      }
    } catch (_) {}

    // ── إضافة/تحديث المستخدمين الثلاثة الرسميين ─────────────
    final hndsaRows = await db.query('users',
        where: 'username = ?', whereArgs: ['hndsa'], limit: 1);
    if (hndsaRows.isEmpty) {
      final template = await db.query('users', limit: 1);
      if (template.isNotEmpty) {
        final newUser = Map<String, dynamic>.from(template.first);
        newUser.remove('id');
        newUser['username']             = 'hndsa';
        newUser['password_hash']        = 'Hndsa@1';
        newUser['employee_name']        = 'م/محمد سامي';
        newUser['role_id']              = managerRoleId;
        newUser['is_active']            = 1;
        newUser['must_change_password'] = 0;
        if (newUser.containsKey('national_id')) {
          newUser['national_id'] = 'MGR-HNDSA';
        }
        try { await db.insert('users', newUser); } catch (_) {}
      }
    }

    final bashRows = await db.query('users',
        where: 'username = ?', whereArgs: ['bashkateb'], limit: 1);
    if (bashRows.isNotEmpty) {
      if ((bashRows.first['employee_name'] ?? '') == 'مدير النظام') {
        try {
          await db.update(
            'users',
            {'employee_name': 'نعمه بدوي', 'role_id': employeeRoleId},
            where: 'username = ?',
            whereArgs: ['bashkateb'],
          );
        } catch (_) {}
      }
    } else {
      final template = await db.query('users', limit: 1);
      if (template.isNotEmpty) {
        final newUser = Map<String, dynamic>.from(template.first);
        newUser.remove('id');
        newUser['username']             = 'bashkateb';
        newUser['password_hash']        = 'Fashn@2';
        newUser['employee_name']        = 'نعمه بدوي';
        newUser['role_id']              = employeeRoleId;
        newUser['is_active']            = 1;
        newUser['must_change_password'] = 0;
        if (newUser.containsKey('national_id')) {
          newUser['national_id'] = 'EMP-BASHKATEB';
        }
        try { await db.insert('users', newUser); } catch (_) {}
      }
    }

    final mo7Rows = await db.query('users',
        where: 'username = ?', whereArgs: ['mo7lfat'], limit: 1);
    if (mo7Rows.isEmpty) {
      final template = await db.query('users', limit: 1);
      if (template.isNotEmpty) {
        final newUser = Map<String, dynamic>.from(template.first);
        newUser.remove('id');
        newUser['username']             = 'mo7lfat';
        newUser['password_hash']        = 'Fashn@3';
        newUser['employee_name']        = 'هبه زين العابدين';
        newUser['role_id']              = employeeRoleId;
        newUser['is_active']            = 1;
        newUser['must_change_password'] = 0;
        if (newUser.containsKey('national_id')) {
          newUser['national_id'] = 'EMP-MO7LFAT';
        }
        try { await db.insert('users', newUser); } catch (_) {}
      }
    }

    // ── تطبيع البيانات (تجري مرة واحدة عند الترقية) ─────────
    await _normalizeDrains(db);
    await _normalizeObservers(db);
    await _normalizeCaseStatuses(db);
    await _normalizeViolationTypes(db);
  }

  // ════════════════════════════════════════════════════════════
  // تطبيع أسماء المصارف — الـ40 مصرف المعياري
  // ════════════════════════════════════════════════════════════
  static const List<String> standardDrains = [
    'الشراهنه', 'مغاغة المعدل - القديم', 'ابسوج الشرقي', 'الشيخ يحيى',
    'بني صالح', 'ابو شوشه', 'الكردي', 'الخياط', 'الصعايده', 'فرع الخياط',
    'الخرسه', 'تلت وامتداده', 'الرشوانية', 'الحبابى', 'الفنت', 'فرع الفنت',
    'الامان', 'نزلة اقفهص', 'اقفهص', 'حبيب', 'عمرو', 'فرع عمرو',
    'صعيدية الفشنيه', 'ساقولا الرئيسى', '1 ساقولا', 'الجمهود', 'الجفادون',
    'الزموط', 'الزموط الايمن', 'الزموط الايسر', 'قاطع مازورة القبلى',
    'عطف حيدر', 'بنى منين', 'شنرا', 'المحيط الغربى', 'ابسوج الغربي',
    'الرشاح', 'مغاغة أ - المصب الجديد',
    'طرد بني صالح القديم', 'طرد بني صالح الجديد',
  ];

  // قواعد تحويل الأسماء القديمة → الأسماء المعيارية
  static const Map<String, String> _drainMapping = {
    // مغاغة
    'مغاغة':               'مغاغة المعدل - القديم',
    'مغاغه':               'مغاغة المعدل - القديم',
    'مغاغه المعدل':        'مغاغة المعدل - القديم',
    'مغاغه المعدل القديم': 'مغاغة المعدل - القديم',
    // الشيخ يحيى
    'الشيخ يحي':           'الشيخ يحيى',
    'الشيخ يحى':           'الشيخ يحيى',
    // الخرسه
    'الخرسة':              'الخرسه',
    // ابو شوشه
    'شوشه':                'ابو شوشه',
    'ابو شوشة':            'ابو شوشه',
    // تلت
    'امتداد تلت':          'تلت وامتداده',
    'تلت':                 'تلت وامتداده',
    // مغاغة المصب الجديد
    'مغاغة المحول للنيل':  'مغاغة أ - المصب الجديد',
    'مغاغه المحول للنيل':  'مغاغة أ - المصب الجديد',
    'مغاغة أ':             'مغاغة أ - المصب الجديد',
    'مغاغه أ':             'مغاغة أ - المصب الجديد',
    // إملاءات بديلة شائعة
    'الخرسه الجديد':       'الخرسه',
    'الرشوانيه':           'الرشوانية',
    'الرشوانيه الجديد':    'الرشوانية',
    'نزلة اقفهص الجديد':  'نزلة اقفهص',
    'صعيدية الفشنية':      'صعيدية الفشنيه',
    'ساقولا الرئيسي':      'ساقولا الرئيسى',
    'المحيط الغربي':       'المحيط الغربى',
    'قاطع مازورة القبلي':  'قاطع مازورة القبلى',
    'بني منين':            'بنى منين',
  };

  // ════════════════════════════════════════════════════════════
  // الأسماء المعيارية للملاحظين
  // ════════════════════════════════════════════════════════════
  static const List<String> standardObservers = [
    'سعيد سيد',
    'رجب محمد ذكي',
    'معتصم مصطفي',
    'خطيب محمد',
    'حسن محمد ابوالعلا',
    'مدكور محمد مجاهد',
    'غانم هيبه',
    'جمعه سيد عبدالفتاح',
    'ايمن احمد ماهر',
    'محمد شمردل',
  ];

  // أنواع المخالفات المعيارية
  static const List<String> standardViolationTypes = [
    'موقف/تندة',
    'تشوينات',
    'مشاتل',
    'كافيتيريا',
    'نوادي',
    'رسو مراكب',
    'مواسير صرف صحي (<1م)',
    'مواسير صرف صحي (>1م)',
    'مياه شرب',
    'كابلات (<1م)',
    'كابلات (>1م)',
    'مباني',
    'زراعة',
    'عشش',
    'كشك (تجاري/صناعي)',
    'ردم',
    'القاء مخلفات',
    'التعدي علي اعمال صناعية',
    'تشجير',
    'قنطره',
    'قطع جسر',
  ];

  // حالات المحضر المعيارية (3 فقط)
  static const List<String> standardCaseStatuses = [
    'قائم',
    'ازالة جبرية',
    'تم رد الشئ لأصله',
  ];

  // خريطة تطبيع أسماء الملاحظين (أسماء قديمة/مشابهة → الاسم المعياري)
  static const Map<String, String> _observerMapping = {
    // حسن محمد ابوالعلا وتنويعاته
    'حسن محمد': 'حسن محمد ابوالعلا',
    'حسن محمد محمد': 'حسن محمد ابوالعلا',
    'حسن محمد ابو العلا': 'حسن محمد ابوالعلا',
    'حسن محمد ابو علا': 'حسن محمد ابوالعلا',
    'حسن محمد او العيلا': 'حسن محمد ابوالعلا',
    'حسن محمد ابوعلا': 'حسن محمد ابوالعلا',
    'حسن محمد ابو العيلا': 'حسن محمد ابوالعلا',
    'حسن محمد أبو العلا': 'حسن محمد ابوالعلا',
    // رجب محمد ذكي
    'رجب محمد': 'رجب محمد ذكي',
    'رجب ذكي': 'رجب محمد ذكي',
    // معتصم مصطفي
    'معتصم': 'معتصم مصطفي',
    'معتصم مصطفى': 'معتصم مصطفي',
    // خطيب محمد
    'خطيب': 'خطيب محمد',
    'الخطيب محمد': 'خطيب محمد',
    // مدكور محمد مجاهد
    'مدكور': 'مدكور محمد مجاهد',
    'مدكور محمد': 'مدكور محمد مجاهد',
    // غانم هيبه
    'غانم': 'غانم هيبه',
    'غانم هيبة': 'غانم هيبه',
    // جمعه سيد عبدالفتاح
    'جمعه سيد': 'جمعه سيد عبدالفتاح',
    'جمعة سيد عبدالفتاح': 'جمعه سيد عبدالفتاح',
    'جمعه عبدالفتاح': 'جمعه سيد عبدالفتاح',
    // ايمن احمد ماهر
    'ايمن احمد': 'ايمن احمد ماهر',
    'أيمن احمد ماهر': 'ايمن احمد ماهر',
    'ايمن ماهر': 'ايمن احمد ماهر',
    // سعيد سيد
    'سعيد': 'سعيد سيد',
    // محمد شمردل
    'شمردل': 'محمد شمردل',
    'محمد شمرد': 'محمد شمردل',
  };

  // خريطة تطبيع حالات المحضر
  static const Map<String, String> _caseStatusMapping = {
    // قائم
    'قائمة': 'قائم',
    'لم تزل': 'قائم',
    'لم تُزل': 'قائم',
    'فعال': 'قائم',
    'جارية': 'قائم',
    'جاري': 'قائم',
    // ازالة جبرية
    'إزالة جبرية': 'ازالة جبرية',
    'جبري': 'ازالة جبرية',
    'جبرا': 'ازالة جبرية',
    'جبراً': 'ازالة جبرية',
    'ازاله جبريه': 'ازالة جبرية',
    'إزاله جبريه': 'ازالة جبرية',
    // تم رد الشئ لأصله
    'رد الشئ': 'تم رد الشئ لأصله',
    'رد الشيء لاصله': 'تم رد الشئ لأصله',
    'رد الشيء لأصله': 'تم رد الشئ لأصله',
    'رد الشى لاصله': 'تم رد الشئ لأصله',
    'تم رد الشيء لأصله': 'تم رد الشئ لأصله',
    'تم رد الشي لاصله': 'تم رد الشئ لأصله',
  };

  // خريطة تطبيع أنواع المخالفات
  static const Map<String, String> _violationTypeMapping = {
    'موقف': 'موقف/تندة',
    'تنده': 'موقف/تندة',
    'تندة': 'موقف/تندة',
    'موقف تندة': 'موقف/تندة',
    'موقف تنده': 'موقف/تندة',
    'تشوين': 'تشوينات',
    'مشتل': 'مشاتل',
    'كافتيريا': 'كافيتيريا',
    'نادي': 'نوادي',
    'رسو': 'رسو مراكب',
    'مراكب': 'رسو مراكب',
    'مواسير صرف': 'مواسير صرف صحي (<1م)',
    'صرف صحي': 'مواسير صرف صحي (<1م)',
    'مواسير': 'مواسير صرف صحي (<1م)',
    'مياة شرب': 'مياه شرب',
    'مياة': 'مياه شرب',
    'كابل': 'كابلات (<1م)',
    'كابلات': 'كابلات (<1م)',
    'مبني': 'مباني',
    'مبنى': 'مباني',
    'زراعه': 'زراعة',
    'عشه': 'عشش',
    'كشك تجاري': 'كشك (تجاري/صناعي)',
    'كشك صناعي': 'كشك (تجاري/صناعي)',
    'كشك': 'كشك (تجاري/صناعي)',
    'القاء': 'القاء مخلفات',
    'مخلفات': 'القاء مخلفات',
    'اعمال صناعية': 'التعدي علي اعمال صناعية',
    'تعدي صناعي': 'التعدي علي اعمال صناعية',
    'تشجيره': 'تشجير',
    'قنطرة': 'قنطره',
    'قطع': 'قطع جسر',
    'جسر': 'قطع جسر',
  };

  // ── تطبيع جدول الملاحظين ─────────────────────────────────────
  static Future<void> _normalizeObservers(Database db) async {
    // 1. أضف الملاحظين المعياريين إن لم يكونوا موجودين
    for (final name in standardObservers) {
      try {
        await db.execute(
          "INSERT OR IGNORE INTO observers (name) VALUES (?)",
          [name],
        );
      } catch (_) {}
    }

    // 2. ابن خريطة الاسم → ID للملاحظين الموجودين
    final Map<String, int> nameToId = {};
    try {
      final rows = await db.rawQuery('SELECT id, name FROM observers');
      for (final row in rows) {
        final name = row['name']?.toString().trim() ?? '';
        final id = (row['id'] as num?)?.toInt() ?? 0;
        if (id > 0 && name.isNotEmpty) nameToId[name] = id;
      }
    } catch (_) {}

    // 3. طبّق قواعد التحويل الصريحة
    for (final entry in _observerMapping.entries) {
      final fromName = entry.key;
      final toName = entry.value;
      final fromId = nameToId[fromName];
      final toId = nameToId[toName];
      if (fromId == null || toId == null || fromId == toId) continue;
      try {
        await db.execute(
          'UPDATE violation_cases SET observer_id = ? WHERE observer_id = ?',
          [toId, fromId],
        );
      } catch (_) {}
    }

    // 4. تطبيع التشابه بالمطابقة الجزئية للأسماء الموجودة
    try {
      final allObservers = await db.rawQuery('SELECT id, name FROM observers');
      for (final obs in allObservers) {
        final obsName = obs['name']?.toString().trim() ?? '';
        if (standardObservers.contains(obsName)) continue;
        // البحث عن أقرب اسم معياري
        String? targetName;
        for (final std in standardObservers) {
          final normObs = obsName.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('ى', 'ي');
          final normStd = std.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('ى', 'ي');
          if (normObs == normStd) { targetName = std; break; }
          // مطابقة جزئية: إذا بدأ الاسم بنفس الكلمتين الأوليين
          final obsParts = normObs.split(' ');
          final stdParts = normStd.split(' ');
          if (obsParts.length >= 2 && stdParts.length >= 2 &&
              obsParts[0] == stdParts[0] && obsParts[1] == stdParts[1]) {
            targetName = std;
            break;
          }
        }
        if (targetName == null) continue;
        final fromId = (obs['id'] as num?)?.toInt() ?? 0;
        final toId = nameToId[targetName];
        if (fromId <= 0 || toId == null || fromId == toId) continue;
        try {
          await db.execute(
            'UPDATE violation_cases SET observer_id = ? WHERE observer_id = ?',
            [toId, fromId],
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── تطبيع جدول حالات المحضر ──────────────────────────────────
  static Future<void> _normalizeCaseStatuses(Database db) async {
    // 1. أضف الحالات المعيارية الثلاث إن لم تكن موجودة
    for (final name in standardCaseStatuses) {
      try {
        await db.execute(
          "INSERT OR IGNORE INTO case_statuses (name) VALUES (?)",
          [name],
        );
      } catch (_) {}
    }

    // 2. ابن خريطة الاسم → ID
    final Map<String, int> nameToId = {};
    try {
      final rows = await db.rawQuery('SELECT id, name FROM case_statuses');
      for (final row in rows) {
        final name = row['name']?.toString().trim() ?? '';
        final id = (row['id'] as num?)?.toInt() ?? 0;
        if (id > 0 && name.isNotEmpty) nameToId[name] = id;
      }
    } catch (_) {}

    // 3. طبّق قواعد التحويل الصريحة
    for (final entry in _caseStatusMapping.entries) {
      final fromName = entry.key;
      final toName = entry.value;
      final fromId = nameToId[fromName];
      final toId = nameToId[toName];
      if (fromId == null || toId == null || fromId == toId) continue;
      try {
        await db.execute(
          'UPDATE violation_cases SET case_status_id = ? WHERE case_status_id = ?',
          [toId, fromId],
        );
      } catch (_) {}
    }

    // 4. مطابقة جزئية للحالات المتبقية
    try {
      final allStatuses = await db.rawQuery('SELECT id, name FROM case_statuses');
      for (final status in allStatuses) {
        final statusName = status['name']?.toString().trim() ?? '';
        if (standardCaseStatuses.contains(statusName)) continue;
        final normStatus = statusName.replaceAll('أ', 'ا').replaceAll('إ', 'ا');
        String? targetName;
        for (final std in standardCaseStatuses) {
          final normStd = std.replaceAll('أ', 'ا').replaceAll('إ', 'ا');
          if (normStatus.contains(normStd) || normStd.contains(normStatus)) {
            targetName = std;
            break;
          }
        }
        if (targetName == null) continue;
        final fromId = (status['id'] as num?)?.toInt() ?? 0;
        final toId = nameToId[targetName];
        if (fromId <= 0 || toId == null || fromId == toId) continue;
        try {
          await db.execute(
            'UPDATE violation_cases SET case_status_id = ? WHERE case_status_id = ?',
            [toId, fromId],
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── تطبيع جدول أنواع المخالفات ──────────────────────────────
  static Future<void> _normalizeViolationTypes(Database db) async {
    // 1. أضف الأنواع المعيارية إن لم تكن موجودة
    for (final name in standardViolationTypes) {
      try {
        await db.execute(
          "INSERT OR IGNORE INTO violation_types (name, is_active) VALUES (?, 1)",
          [name],
        );
      } catch (_) {
        try {
          await db.execute(
            "INSERT OR IGNORE INTO violation_types (name) VALUES (?)",
            [name],
          );
        } catch (_) {}
      }
    }

    // 2. ابن خريطة الاسم → ID
    final Map<String, int> nameToId = {};
    try {
      final rows = await db.rawQuery('SELECT id, name FROM violation_types');
      for (final row in rows) {
        final name = row['name']?.toString().trim() ?? '';
        final id = (row['id'] as num?)?.toInt() ?? 0;
        if (id > 0 && name.isNotEmpty) nameToId[name] = id;
      }
    } catch (_) {}

    // 3. طبّق قواعد التحويل الصريحة
    for (final entry in _violationTypeMapping.entries) {
      final fromName = entry.key;
      final toName = entry.value;
      final fromId = nameToId[fromName];
      final toId = nameToId[toName];
      if (fromId == null || toId == null || fromId == toId) continue;
      try {
        await db.execute(
          'UPDATE violation_cases SET violation_type_id = ? WHERE violation_type_id = ?',
          [toId, fromId],
        );
      } catch (_) {}
    }
  }

  static Future<void> _normalizeDrains(Database db) async {
    // ── 0. أضف عمود is_active لجدول drains إن لم يكن موجوداً ──
    try {
      await db.execute('ALTER TABLE drains ADD COLUMN is_active INTEGER DEFAULT 1');
    } catch (_) {}

    // ── 1. أدرج كل مصرف معياري إن لم يكن موجوداً ──────────────
    for (final name in standardDrains) {
      try {
        await db.execute(
          "INSERT OR IGNORE INTO drains (name, is_active) VALUES (?, 1)",
          [name],
        );
      } catch (_) {
        try {
          await db.execute(
            "INSERT OR IGNORE INTO drains (name) VALUES (?)",
            [name],
          );
        } catch (_) {}
      }
    }

    // ── 2. ابن خريطة الاسم → ID للمصارف الموجودة ──────────────
    final Map<String, int> nameToId = {};
    try {
      final rows = await db.rawQuery('SELECT id, name FROM drains');
      for (final row in rows) {
        final name = row['name']?.toString().trim() ?? '';
        final id   = (row['id'] as num?)?.toInt() ?? 0;
        if (id > 0 && name.isNotEmpty) nameToId[name] = id;
      }
    } catch (_) {}

    // ── 3. طبّق قواعد التحويل على violation_cases ───────────────
    for (final entry in _drainMapping.entries) {
      final fromName = entry.key;
      final toName   = entry.value;
      final fromId   = nameToId[fromName];
      final toId     = nameToId[toName];
      if (fromId == null || toId == null || fromId == toId) continue;
      try {
        await db.execute(
          'UPDATE violation_cases SET drain_id = ? WHERE drain_id = ?',
          [toId, fromId],
        );
        // عطّل المصرف القديم
        try {
          await db.execute(
            'UPDATE drains SET is_active = 0 WHERE id = ?',
            [fromId],
          );
        } catch (_) {}
      } catch (_) {}
    }

    // ── 4. عطّل أي مصرف غير موجود في القائمة المعيارية ─────────
    final standardSet = standardDrains.toSet();
    try {
      final allDrains = await db.rawQuery('SELECT id, name FROM drains');
      for (final row in allDrains) {
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty || standardSet.contains(name)) continue;
        // إذا لم يكن في القائمة المعيارية ولم يعد له محاضر → عطّل
        final hasCase = _firstInt(await db.rawQuery(
          'SELECT COUNT(*) FROM violation_cases WHERE drain_id = ?',
          [row['id']],
        ));
        if (hasCase == 0) {
          try {
            await db.execute(
              'UPDATE drains SET is_active = 0 WHERE id = ?',
              [row['id']],
            );
          } catch (_) {}
        }
      }
    } catch (_) {}

    // ── 5. تأكّد أن المصارف المعيارية is_active = 1 ─────────────
    for (final name in standardDrains) {
      final id = nameToId[name];
      if (id == null) continue;
      try {
        await db.execute(
          'UPDATE drains SET is_active = 1 WHERE id = ?',
          [id],
        );
      } catch (_) {}
    }
  }

  static Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final databasesPath = await databaseFactory.getDatabasesPath();
    await Directory(databasesPath).create(recursive: true);

    final dbPath = p.join(databasesPath, 'criminal_cases.db');
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      final data = await rootBundle.load('assets/database/criminal_cases.db');
      final bytes = data.buffer.asUint8List();
      await dbFile.writeAsBytes(bytes, flush: true);
    }

    return openDatabase(dbPath);
  }

  static Future<void> _ensureDefaultAdmin(Database db) async {
    final users = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['bashkateb'],
      limit: 1,
    );
    if (users.isNotEmpty) return;

    await db.insert('users', {
      'employee_name': 'مدير النظام',
      'national_id': '',
      'username': 'bashkateb',
      'password_hash': 'Fashn@2',
      'role_id': 1,
      'is_active': 1,
      'must_change_password': 0,
    });
  }

  static Future<void> _ensureManagerAccount(Database db) async {
    try {
      final existing = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['handasa'],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      final allRoles = await db.query('roles');
      int managerRoleId = 1;
      bool foundManager = false;

      for (final role in allRoles) {
        for (final val in role.values) {
          if (val?.toString() == 'manager') {
            managerRoleId = role['id'] as int? ?? 1;
            foundManager = true;
            break;
          }
        }
        if (foundManager) break;
      }

      if (!foundManager && allRoles.isNotEmpty) {
        final template = allRoles.first;
        final Map<String, dynamic> newRole = {};
        for (final key in template.keys) {
          if (key == 'id') continue;
          final keyLower = key.toLowerCase();
          if (keyLower.contains('code') || keyLower.contains('key')) {
            newRole[key] = 'manager';
          } else if (keyLower.contains('name') || keyLower.contains('ar')) {
            newRole[key] = 'مدير';
          } else {
            newRole[key] = template[key] ?? '';
          }
        }
        try {
          managerRoleId = await db.insert('roles', newRole);
        } catch (_) {
          managerRoleId = allRoles.first['id'] as int? ?? 1;
        }
      }

      final bashkateb = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['bashkateb'],
        limit: 1,
      );
      if (bashkateb.isEmpty) return;

      final newUser = Map<String, dynamic>.from(bashkateb.first);
      newUser.remove('id');
      newUser['username'] = 'handasa';
      newUser['password_hash'] = 'Handasa@1';
      newUser['employee_name'] = 'مدير الهندسة';
      newUser['role_id'] = managerRoleId;
      newUser['is_active'] = 1;
      if (newUser.containsKey('must_change_password')) {
        newUser['must_change_password'] = 0;
      }
      if (newUser.containsKey('national_id')) {
        newUser['national_id'] = 'MGR-HANDASA';
      }

      await db.insert('users', newUser);
      lastSetupError = null;
    } catch (e) {
      lastSetupError = e.toString();
    }
  }

  // ── تسجيل الدخول ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    final db = await database;

    List<Map<String, dynamic>> rows = [];
    try {
      rows = await db.rawQuery(
        '''
        SELECT
          users.*,
          roles.role_code AS role_code,
          roles.name_ar   AS role_name
        FROM users
        LEFT JOIN roles ON roles.id = users.role_id
        WHERE users.username = ?
          AND users.is_active = 1
        LIMIT 1
        ''',
        [username],
      );
    } catch (_) {
      try {
        rows = await db.rawQuery(
          '''
          SELECT
            users.*,
            roles.code    AS role_code,
            roles.name_ar AS role_name
          FROM users
          LEFT JOIN roles ON roles.id = users.role_id
          WHERE users.username = ?
            AND users.is_active = 1
          LIMIT 1
          ''',
          [username],
        );
      } catch (_) {
        rows = await db.rawQuery(
          '''
          SELECT users.*
          FROM users
          WHERE users.username = ?
            AND users.is_active = 1
          LIMIT 1
          ''',
          [username],
        );
      }
    }

    if (rows.isEmpty) {
      if (username == 'handasa' && lastSetupError != null) {
        throw Exception('فشل إنشاء حساب handasa: $lastSetupError');
      }
      return null;
    }

    final user = Map<String, dynamic>.from(rows.first);
    if ((user['password_hash'] ?? '').toString() != password) return null;

    return user;
  }

  // ════════════════════════════════════════════════════════════
  // إحصائيات الداشبورد — معدّلة لتشمل إحصائيات أشمل
  // ════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;

    // ── إجمالي المحاضر الفعلي بعد الدمج ─────────────────────
    final totalCases = _firstInt(
      await db.rawQuery('SELECT COUNT(*) FROM violation_cases'),
    );

    // ── عدد المصارف المعيارية الـ40 ──────────────────────────
    // نعدّ المصارف من القائمة المعيارية الموجودة في جدول drains
    int totalDrains = 0;
    try {
      final placeholders = List.filled(standardDrains.length, '?').join(', ');
      totalDrains = _firstInt(await db.rawQuery(
        'SELECT COUNT(*) FROM drains WHERE name IN ($placeholders)',
        standardDrains,
      ));
    } catch (_) {
      // احتياطي: عدّ كل المصارف النشطة
      try {
        totalDrains = _firstInt(
          await db.rawQuery('SELECT COUNT(*) FROM drains WHERE is_active = 1'),
        );
      } catch (_) {}
    }

    // ── عدد المصارف المعيارية التي لها محاضر فعلاً ──────────
    final drainsWithCases = _firstInt(
      await db.rawQuery('''
        SELECT COUNT(DISTINCT vc.drain_id)
        FROM violation_cases vc
        INNER JOIN drains d ON d.id = vc.drain_id
        WHERE vc.drain_id IS NOT NULL
      '''),
    );

    // ── أنواع المخالفات ───────────────────────────────────────
    final totalTypes = _firstInt(
      await db.rawQuery(
        'SELECT COUNT(*) FROM violation_types WHERE is_active = 1',
      ),
    );

    // ── طلبات بانتظار الاعتماد ────────────────────────────────
    int totalPending = 0;
    try {
      totalPending = _firstInt(await db.rawQuery(
        "SELECT COUNT(*) FROM pending_requests WHERE status = 'pending'",
      ));
    } catch (_) {}

    // ── محاضر رد الشئ لأصله ──────────────────────────────────
    final restorationCases = await _countCasesByStatusName(
      db,
      keywords: ['رد الشئ', 'رد الشيء', 'رد الشى', 'لأصله', 'لاصله'],
    );

    // ── المحاضر القائمة (لم تُزل بعد) ───────────────────────
    final activeCases = await _countCasesByStatusName(
      db,
      keywords: ['قائمة', 'قائم', 'لم تزل', 'لم تُزل', 'فعال', 'جارية'],
    );

    // ── المحاضر المزالة جبريا ─────────────────────────────────
    final forciblyRemovedCases = await _countCasesByStatusName(
      db,
      keywords: ['جبري', 'إزالة جبرية', 'ازالة جبرية', 'جبرا', 'جبراً'],
    );

    // ── المتعاقدين (مخالفون لديهم ملفات تراخيص) ─────────────
    int contractorsCount = 0;
    try {
      contractorsCount = _firstInt(
        await db.rawQuery(
          'SELECT COUNT(DISTINCT contractor) FROM license_files WHERE contractor IS NOT NULL AND contractor != \'\'',
        ),
      );
    } catch (_) {}

    // ── ملفات التقنين ─────────────────────────────────────────
    int regularizationFiles = 0;
    try {
      regularizationFiles = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM regularization_files'),
      );
    } catch (_) {}

    // ── ملفات التراخيص ───────────────────────────────────────
    int licenseFiles = 0;
    try {
      licenseFiles = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM license_files'),
      );
    } catch (_) {}

    // ── الحجز الإداري ─────────────────────────────────────────
    int adminSeizureCases = 0;
    try {
      adminSeizureCases = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM admin_seizure_cases'),
      );
    } catch (_) {
      // قد لا يوجد جدول بعد — يُعرض صفر
    }

    // ── التبديد ───────────────────────────────────────────────
    int dissipationCasesCount = 0;
    try {
      dissipationCasesCount = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM dissipation_cases'),
      );
    } catch (_) {}

    // ── الشكاوي ───────────────────────────────────────────────
    int complaintsCasesCount = 0;
    try {
      complaintsCasesCount = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM complaints'),
      );
    } catch (_) {
      try {
        complaintsCasesCount = _firstInt(
          await db.rawQuery('SELECT COUNT(*) FROM complaint_cases'),
        );
      } catch (_) {}
    }

    // ── تحليلات المحاضر الجنائية ──────────────────────────────────
    // المحاضر بالسنة
    final byYear = <Map<String, dynamic>>[];
    try {
      final rows = await db.rawQuery('''
        SELECT report_year AS year, COUNT(*) AS cnt
        FROM violation_cases
        WHERE report_year IS NOT NULL
        GROUP BY report_year
        ORDER BY report_year
      ''');
      for (final r in rows) {
        byYear.add({'year': r['year'] as int, 'count': r['cnt'] as int});
      }
    } catch (_) {}

    // المحاضر بنوع المخالفة
    final byVtype = <Map<String, dynamic>>[];
    try {
      final rows = await db.rawQuery('''
        SELECT vt.name AS name, COUNT(*) AS cnt
        FROM violation_cases vc
        JOIN violation_types vt ON vt.id = vc.violation_type_id
        GROUP BY vt.id, vt.name
        ORDER BY cnt DESC
        LIMIT 12
      ''');
      for (final r in rows) {
        byVtype.add({'name': r['name'] as String, 'count': r['cnt'] as int});
      }
    } catch (_) {}

    // المحاضر بالملاحظ
    final byObserver = <Map<String, dynamic>>[];
    try {
      final rows = await db.rawQuery('''
        SELECT ob.name AS name, COUNT(*) AS cnt
        FROM violation_cases vc
        JOIN observers ob ON ob.id = vc.observer_id
        GROUP BY ob.id, ob.name
        ORDER BY cnt DESC
      ''');
      for (final r in rows) {
        byObserver.add({'name': r['name'] as String, 'count': r['cnt'] as int});
      }
    } catch (_) {}

    // المحاضر بموقف المحضر
    final byStatus = <Map<String, dynamic>>[];
    try {
      final rows = await db.rawQuery('''
        SELECT COALESCE(cs.name, 'بدون موقف') AS name, COUNT(*) AS cnt
        FROM violation_cases vc
        LEFT JOIN case_statuses cs ON cs.id = vc.case_status_id
        GROUP BY vc.case_status_id, cs.name
        ORDER BY cnt DESC
      ''');
      for (final r in rows) {
        byStatus.add({'name': r['name'] as String, 'count': r['cnt'] as int});
      }
    } catch (_) {}

    // المحاضر بالمصرف (أعلى 12)
    final byDrain = <Map<String, dynamic>>[];
    try {
      final rows = await db.rawQuery('''
        SELECT d.name AS name, COUNT(*) AS cnt
        FROM violation_cases vc
        JOIN drains d ON d.id = vc.drain_id
        GROUP BY d.id, d.name
        ORDER BY cnt DESC
        LIMIT 12
      ''');
      for (final r in rows) {
        byDrain.add({'name': r['name'] as String, 'count': r['cnt'] as int});
      }
    } catch (_) {}

    return {
      // الإحصائيات الأصلية
      'total_cases':              totalCases,
      'total_drains':             totalDrains,
      'total_types':              totalTypes,
      // الأقسام الجديدة
      'admin_seizure_cases':      adminSeizureCases,
      'dissipation_cases':        dissipationCasesCount,
      'complaints_cases':         complaintsCasesCount,
      'total_pending':            totalPending,
      // الإحصائيات الإضافية
      'drains_with_cases':        drainsWithCases,
      'restoration_cases':        restorationCases,
      'active_cases':             activeCases,
      'forcibly_removed_cases':   forciblyRemovedCases,
      'contractors_count':        contractorsCount,
      'regularization_files':     regularizationFiles,
      'license_files':            licenseFiles,
      // التحليلات التفصيلية
      'by_year':     byYear,
      'by_vtype':    byVtype,
      'by_observer': byObserver,
      'by_status':   byStatus,
      'by_drain':    byDrain,
    };
  }

  // ── مساعد: عدّ المحاضر بحسب كلمات مفتاحية في حالة المحضر ──
  static Future<int> _countCasesByStatusName(
    Database db, {
    required List<String> keywords,
  }) async {
    if (keywords.isEmpty) return 0;
    try {
      final conditions = keywords
          .map((_) => "cs.name LIKE ?")
          .join(' OR ');
      final args = keywords.map((k) => '%$k%').toList();
      final result = await db.rawQuery('''
        SELECT COUNT(*) FROM violation_cases vc
        LEFT JOIN case_statuses cs ON cs.id = vc.case_status_id
        WHERE $conditions
      ''', args);
      return _firstInt(result);
    } catch (_) {
      return 0;
    }
  }

  static Future<List<int>> getReportYears() async {
    // السنوات الثابتة من 2011 إلى 2026 دائماً
    final fixedYears = List.generate(2026 - 2011 + 1, (i) => 2011 + i);

    // السنوات الموجودة فعلاً في قاعدة البيانات
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT report_year
      FROM violation_cases
      WHERE report_year IS NOT NULL
      ORDER BY report_year DESC
    ''');
    final dbYears = rows
        .map((row) => row['report_year'])
        .whereType<int>()
        .toSet();

    // دمج: السنوات الثابتة + أي سنة جديدة من قاعدة البيانات
    final allYears = <int>{...fixedYears, ...dbYears}.toList()
      ..sort((a, b) => b.compareTo(a)); // ترتيب تنازلي
    return allYears;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getFilterOptions() async {
    final db = await database;

    Future<List<Map<String, dynamic>>> lookup(String table) async {
      // أولاً: نحاول مع is_active (إن كان العمود موجوداً)
      try {
        return await db.rawQuery(
          'SELECT id, name FROM $table WHERE is_active = 1 ORDER BY name',
        );
      } catch (_) {}
      // ثانياً: نحاول بدون is_active (الجداول التي لا تملك هذا العمود)
      try {
        return await db.rawQuery(
          'SELECT id, name FROM $table ORDER BY name',
        );
      } catch (_) {
        return [];
      }
    }

    // ── فلتر المصارف: يعرض الـ40 المعياري مرتبة حسب القائمة ──
    Future<List<Map<String, dynamic>>> lookupDrains() async {
      try {
        final placeholders =
            List.filled(standardDrains.length, '?').join(', ');
        final rows = await db.rawQuery(
          'SELECT id, name FROM drains WHERE name IN ($placeholders) ORDER BY name',
          standardDrains,
        );
        // أعد الترتيب حسب قائمة standardDrains الأصلية
        final nameToRow = <String, Map<String, dynamic>>{
          for (final r in rows) r['name'].toString(): r,
        };
        return [
          for (final n in standardDrains)
            if (nameToRow.containsKey(n)) nameToRow[n]!,
        ];
      } catch (_) {
        return lookup('drains');
      }
    }

    // ── فلتر أنواع المخالفة: الـ21 المعيارية مرتبة حسب القائمة ──
    Future<List<Map<String, dynamic>>> lookupStandardViolationTypes() async {
      try {
        final placeholders =
            List.filled(standardViolationTypes.length, '?').join(', ');
        final rows = await db.rawQuery(
          'SELECT id, name FROM violation_types WHERE name IN ($placeholders)',
          standardViolationTypes,
        );
        final nameToRow = <String, Map<String, dynamic>>{
          for (final r in rows) r['name'].toString(): r,
        };
        return [
          for (final n in standardViolationTypes)
            if (nameToRow.containsKey(n)) nameToRow[n]!,
        ];
      } catch (_) {
        return lookup('violation_types');
      }
    }

    // ── فلتر الملاحظين: العشرة المعياريون مرتبون حسب القائمة ──
    Future<List<Map<String, dynamic>>> lookupStandardObservers() async {
      try {
        final placeholders =
            List.filled(standardObservers.length, '?').join(', ');
        final rows = await db.rawQuery(
          'SELECT id, name FROM observers WHERE name IN ($placeholders)',
          standardObservers,
        );
        final nameToRow = <String, Map<String, dynamic>>{
          for (final r in rows) r['name'].toString(): r,
        };
        return [
          for (final n in standardObservers)
            if (nameToRow.containsKey(n)) nameToRow[n]!,
        ];
      } catch (_) {
        return lookup('observers');
      }
    }

    // ── فلتر موقف المحضر: الثلاثة المعيارية فقط ─────────────
    Future<List<Map<String, dynamic>>> lookupStandardCaseStatuses() async {
      try {
        final placeholders =
            List.filled(standardCaseStatuses.length, '?').join(', ');
        final rows = await db.rawQuery(
          'SELECT id, name FROM case_statuses WHERE name IN ($placeholders)',
          standardCaseStatuses,
        );
        final nameToRow = <String, Map<String, dynamic>>{
          for (final r in rows) r['name'].toString(): r,
        };
        return [
          for (final n in standardCaseStatuses)
            if (nameToRow.containsKey(n)) nameToRow[n]!,
        ];
      } catch (_) {
        return lookup('case_statuses');
      }
    }

    final yearRows = (await getReportYears())
        .map((y) => {'id': y, 'name': y.toString()})
        .toList();

    return {
      'years':                   yearRows,
      'violation_types':         await lookupStandardViolationTypes(),
      'drains':                  await lookupDrains(),
      'observers':               await lookupStandardObservers(),
      'case_statuses':           await lookupStandardCaseStatuses(),
      'admin_seizure_statuses':  await lookup('admin_seizure_statuses'),
      'dissipation_statuses':    await lookup('dissipation_statuses'),
      'payment_statuses':        await lookup('payment_statuses'),
    };
  }

  static Future<List<Map<String, dynamic>>> getCases({
    String search = '',
    CaseFilter? filter,
    int limit = 5000,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    final trimmedSearch = search.trim();
    if (trimmedSearch.isNotEmpty) {
      final compactSearch = trimmedSearch.replaceAll(' ', '');
      where.add('''
        (
          CAST(vc.report_number AS TEXT) LIKE ?
          OR CAST(vc.report_year AS TEXT) LIKE ?
          OR IFNULL(vc.offender_name, '') LIKE ?
          OR REPLACE(IFNULL(vc.offender_name, ''), ' ', '') LIKE ?
          OR IFNULL(vc.offender_national_id, '') LIKE ?
          OR IFNULL(vc.judicial_number, '') LIKE ?
          OR IFNULL(vc.removal_decision_number, '') LIKE ?
          OR IFNULL(d.name, '') LIKE ?
          OR IFNULL(vt.name, '') LIKE ?
        )
      ''');
      args.addAll([
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$compactSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
      ]);
    }

    void addInFilter(String columnName, Iterable<int> values) {
      if (values.isEmpty) return;
      where.add(
        '$columnName IN (${List.filled(values.length, '?').join(', ')})',
      );
      args.addAll(values);
    }

    if (filter != null) {
      addInFilter('vc.report_year', filter.years);
      addInFilter('vc.violation_type_id', filter.violationTypeIds);
      addInFilter('vc.drain_id', filter.drainIds);
      addInFilter('vc.observer_id', filter.observerIds);
      addInFilter('vc.case_status_id', filter.caseStatusIds);
      addInFilter('vc.admin_seizure_status_id', filter.adminSeizureStatusIds);
      addInFilter('vc.dissipation_status_id', filter.dissipationStatusIds);
      addInFilter('vc.payment_status_id', filter.paymentStatusIds);

      // ── فلتر فترة تاريخ المحضر ─────────────────────────────
      if (filter.dateFrom != null) {
        final fromStr = filter.dateFrom!.toIso8601String().substring(0, 10);
        where.add("date(vc.report_date) >= date(?)");
        args.add(fromStr);
      }
      if (filter.dateTo != null) {
        final toStr = filter.dateTo!.toIso8601String().substring(0, 10);
        where.add("date(vc.report_date) <= date(?)");
        args.add(toStr);
      }
    }

    final whereSql =
        where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    args.add(limit);

    // ── استعلام كامل مع حماية من الأعمدة المفقودة ──
      try {
        return await db.rawQuery('''
          SELECT
            vc.id,
            vc.report_number,
            vc.report_year,
            vc.report_date,
            vc.removal_decision_number,
            vc.judicial_number,
            vc.offender_name,
            vc.offender_national_id,
            vc.drain_id,
            IFNULL(vc.kilometer_location, '') AS kilometer_location,
            vc.violation_type_id,
            IFNULL(vc.violation_type_ids, '') AS violation_type_ids,
            vc.area,
            vc.observer_id,
            vc.case_status_id,
            vc.removal_date,
            vc.report_value,
            IFNULL(vc.percent_47_value, 0)    AS percent_47_value,
            IFNULL(vc.restoration_value, 0)   AS restoration_value,
            IFNULL(vc.usufruct_value, 0)      AS usufruct_value,
            IFNULL(vc.total_dues, 0)          AS total_dues,
            vc.admin_seizure_status_id,
            IFNULL(vc.admin_seizure_value, 0) AS admin_seizure_value,
            vc.dissipation_status_id,
            vc.payment_status_id,
            IFNULL(vc.paid_amount, 0)         AS paid_amount,
            IFNULL(vc.approval_status, 'pending') AS approval_status,
            IFNULL(vc.source_sheet, '')       AS source_sheet,
            IFNULL(vc.source_row, 0)          AS source_row,
            IFNULL(d.name, '')   AS drain_name,
            IFNULL(vt.name, '')  AS violation_type,
            IFNULL(o.name, '')   AS observer_name,
            IFNULL(cs.name, '')  AS case_status,
            IFNULL(ass.name, '') AS admin_seizure_status,
            IFNULL(ds.name, '')  AS dissipation_status,
            IFNULL(ps.name, '')  AS payment_status
          FROM violation_cases vc
          LEFT JOIN drains d                   ON d.id   = vc.drain_id
          LEFT JOIN violation_types vt         ON vt.id  = vc.violation_type_id
          LEFT JOIN observers o                ON o.id   = vc.observer_id
          LEFT JOIN case_statuses cs           ON cs.id  = vc.case_status_id
          LEFT JOIN admin_seizure_statuses ass ON ass.id = vc.admin_seizure_status_id
          LEFT JOIN dissipation_statuses ds    ON ds.id  = vc.dissipation_status_id
          LEFT JOIN payment_statuses ps        ON ps.id  = vc.payment_status_id
          $whereSql
          ORDER BY vc.report_year DESC, vc.report_number DESC, vc.id DESC
          LIMIT ?
        ''', args);
      } catch (_) {
        // ─── استعلام احتياطي بدون الأعمدة الجديدة (قاعدة بيانات قديمة) ───
        return await db.rawQuery('''
          SELECT
            vc.id,
            vc.report_number,
            vc.report_year,
            vc.report_date,
            vc.removal_decision_number,
            vc.judicial_number,
            vc.offender_name,
            vc.offender_national_id,
            vc.drain_id,
            '' AS kilometer_location,
            vc.violation_type_id,
            vc.area,
            vc.observer_id,
            vc.case_status_id,
            vc.removal_date,
            vc.report_value,
            0 AS percent_47_value,
            0 AS restoration_value,
            0 AS usufruct_value,
            0 AS total_dues,
            vc.admin_seizure_status_id,
            0 AS admin_seizure_value,
            vc.dissipation_status_id,
            vc.payment_status_id,
            0 AS paid_amount,
            'pending' AS approval_status,
            '' AS source_sheet,
            0 AS source_row,
            IFNULL(d.name, '')   AS drain_name,
            IFNULL(vt.name, '')  AS violation_type,
            IFNULL(o.name, '')   AS observer_name,
            IFNULL(cs.name, '')  AS case_status,
            IFNULL(ass.name, '') AS admin_seizure_status,
            IFNULL(ds.name, '')  AS dissipation_status,
            IFNULL(ps.name, '')  AS payment_status
          FROM violation_cases vc
          LEFT JOIN drains d                   ON d.id   = vc.drain_id
          LEFT JOIN violation_types vt         ON vt.id  = vc.violation_type_id
          LEFT JOIN observers o                ON o.id   = vc.observer_id
          LEFT JOIN case_statuses cs           ON cs.id  = vc.case_status_id
          LEFT JOIN admin_seizure_statuses ass ON ass.id = vc.admin_seizure_status_id
          LEFT JOIN dissipation_statuses ds    ON ds.id  = vc.dissipation_status_id
          LEFT JOIN payment_statuses ps        ON ps.id  = vc.payment_status_id
          $whereSql
          ORDER BY vc.report_year DESC, vc.report_number DESC, vc.id DESC
          LIMIT ?
        ''', args);
      }
    }
  
  static Future<Map<String, dynamic>?> getCaseById(int id) async {
    final rows = await getCases(search: '', limit: 2000);
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  static Future<int> submitCaseChangeRequest({
    required String requestType,
    int? targetId,
    Map<String, dynamic>? before,
    required Map<String, dynamic> after,
    int? requestedBy,
  }) async {
    final db = await database;

    final id = await db.insert('pending_requests', {
      'request_type': requestType,
      'target_table': 'violation_cases',
      'target_id': targetId,
      'before_data': before != null ? jsonEncode(before) : '{}',
      'after_data': jsonEncode(after),
      'requested_by': requestedBy ?? 0,
      'status': 'pending',
    });

    return id;
  }

  static int _firstInt(List<Map<String, Object?>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) return 0;
    final value = rows.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
