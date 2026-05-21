// ============================================================
// database_migrations.dart
// ترقية قاعدة البيانات المحلية (SQLite) للإصدار 3
// تشمل: جداول app_settings + sync_log + device_registry
//
// طريقة الاستخدام: في database_service.dart عدّل initDatabase():
//
//   return openDatabase(
//     path,
//     version: DatabaseMigrations.targetVersion,  // ← غيّر الرقم
//     onCreate: (db, version) async {
//       // ... إنشاء الجداول الأصلية ...
//       await DatabaseMigrations.runMigrations(db, 0, version);
//     },
//     onUpgrade: (db, oldVersion, newVersion) async {
//       await DatabaseMigrations.runMigrations(db, oldVersion, newVersion);
//     },
//   );
// ============================================================

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseMigrations {
  static const int targetVersion = 3;

  static Future<void> runMigrations(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) await _migrateToV3(db);
  }

  // ─── v3: جداول المزامنة ─────────────────────────────────────
  static Future<void> _migrateToV3(Database db) async {
    // ── 1. جدول إعدادات التطبيق (device_id، last_pull_seq…) ────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // ── 2. جدول سجل المزامنة ────────────────────────────────────
    // يُسجَّل فيه كل insert/update/delete ليُرسَل للسيرفر لاحقاً
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id   TEXT    NOT NULL,
        table_name  TEXT    NOT NULL,
        record_id   INTEGER,
        operation   TEXT    NOT NULL,
        data_json   TEXT    NOT NULL,
        local_ts    TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
        synced      INTEGER NOT NULL DEFAULT 0,
        server_id   INTEGER
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_synced '
        'ON sync_log(synced)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_server_id '
        'ON sync_log(server_id)');

    // ── 3. جدول تسجيل الأجهزة ───────────────────────────────────
    // يُحفَظ فيه معرف هذا الجهاز وحالته (pending/approved/rejected)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_registry (
        device_id     TEXT PRIMARY KEY,
        device_name   TEXT NOT NULL,
        device_type   TEXT NOT NULL,
        platform      TEXT,
        username      TEXT,
        status        TEXT NOT NULL DEFAULT 'pending',
        registered_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
        approved_at   TEXT,
        last_sync_at  TEXT
      )
    ''');
  }
}
