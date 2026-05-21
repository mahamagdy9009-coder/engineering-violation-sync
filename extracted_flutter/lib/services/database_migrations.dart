// ============================================================
// database_migrations.dart
// استدعِ هذا الملف مرة واحدة عند تشغيل التطبيق قبل أي عملية
// قاعدة بيانات. يضيف الجداول الجديدة فقط ولا يمس الجداول الحالية.
// ============================================================

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseMigrations {
  /// نسخة schema الجديدة — ارفع هذا الرقم كلما أضفت جداول جديدة
  static const int targetVersion = 2;

  /// يُستدعى من DatabaseService.initDatabase() بعد فتح قاعدة البيانات
  static Future<void> runMigrations(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrate_v1_to_v2(db);
    }
    // أضف هنا: if (oldVersion < 3) { await _migrate_v2_to_v3(db); }
  }

  // ------------------------------------------------------------------
  // Migration v1 → v2 : إضافة نظام المستخدمين والصلاحيات والإشعارات
  // ------------------------------------------------------------------
  static Future<void> _migrate_v1_to_v2(Database db) async {
    // 1. جدول المستخدمين (يُكمّل جدول users الموجود أو يُنشئه)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        username       TEXT    NOT NULL UNIQUE,
        password_hash  TEXT    NOT NULL,
        employee_name  TEXT    NOT NULL,
        role           TEXT    NOT NULL DEFAULT 'employee',
        role_name      TEXT    NOT NULL DEFAULT 'موظف',
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // إدراج المستخدمَين الأساسيَّين إن لم يكونا موجودَين
    // كلمة مرور bashkateb  => Fashn@2
    // كلمة مرور handasa   => Handasa@1
    // (مخزّنة كـ plaintext هنا — استبدلها بـ hash إن أردت تأمينًا أعلى)
    await db.execute('''
      INSERT OR IGNORE INTO users
        (username, password_hash, employee_name, role, role_name)
      VALUES
        ('bashkateb', 'Fashn@2',    'الباشكاتب',    'employee', 'موظف / باشكاتب'),
        ('handasa',   'Handasa@1',  'مدير الهندسة', 'manager',  'مدير')
    ''');

    // 2. جدول طلبات الانتظار
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_requests (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        request_type     TEXT    NOT NULL,
        target_table     TEXT    NOT NULL DEFAULT 'criminal_cases',
        target_id        INTEGER,
        before_data      TEXT,
        after_data       TEXT,
        requested_by     INTEGER NOT NULL REFERENCES users(id),
        reviewed_by      INTEGER REFERENCES users(id),
        status           TEXT    NOT NULL DEFAULT 'pending',
        rejection_reason TEXT,
        created_at       TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
        reviewed_at      TEXT
      )
    ''');

    // 3. جدول الإشعارات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id            INTEGER NOT NULL REFERENCES users(id),
        title              TEXT    NOT NULL,
        body               TEXT    NOT NULL,
        type               TEXT    NOT NULL DEFAULT 'info',
        related_request_id INTEGER REFERENCES pending_requests(id),
        is_read            INTEGER NOT NULL DEFAULT 0,
        created_at         TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // 4. جدول سجلات التدقيق
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id      INTEGER NOT NULL,
        user_name    TEXT    NOT NULL,
        operation    TEXT    NOT NULL,
        target_table TEXT    NOT NULL,
        target_id    INTEGER,
        before_data  TEXT,
        after_data   TEXT,
        device_info  TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // 5. جدول رسومات GIS المعلّقة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gis_pending_drawings (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id      INTEGER NOT NULL REFERENCES pending_requests(id),
        draw_type       TEXT    NOT NULL,
        geojson         TEXT    NOT NULL,
        name            TEXT,
        project_type    TEXT,
        description     TEXT,
        offender_name   TEXT,
        report_number   TEXT,
        report_year     TEXT,
        notes           TEXT,
        color_value     INTEGER NOT NULL DEFAULT 4284624870,
        status          TEXT    NOT NULL DEFAULT 'pending',
        created_at      TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');
  }
}
