// ============================================================
// sync_service.dart
// خدمة المزامنة الرئيسية — push ثم pull مع السيرفر
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_service.dart';
import 'sync_config.dart';
import 'sync_log_service.dart';
import 'device_service.dart';

enum SyncState { idle, syncing, success, error, disabled }

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncState _state = SyncState.idle;
  String _lastError = '';
  DateTime? _lastSyncTime;
  int _pendingCount = 0;
  Timer? _autoTimer;

  final _stateCtrl = StreamController<SyncState>.broadcast();
  Stream<SyncState> get onStateChanged => _stateCtrl.stream;

  SyncState get state => _state;
  String get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;

  // ─── تشغيل التزامن التلقائي ────────────────────────────────
  void startAutoSync() {
    if (!SyncConfig.syncEnabled) return;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      Duration(minutes: SyncConfig.autoSyncIntervalMinutes),
      (_) => syncIfOnline(),
    );
    // أول محاولة بعد 4 ثوانٍ من التشغيل
    Future.delayed(const Duration(seconds: 4), () => syncIfOnline());
  }

  void stopAutoSync() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  // ─── تزامن إذا الإنترنت متاح ───────────────────────────────
  Future<void> syncIfOnline() async {
    if (!SyncConfig.syncEnabled) return;
    if (_state == SyncState.syncing) return;
    final online = await _isOnline();
    if (online) await sync();
  }

  // ─── دورة التزامن الكاملة ───────────────────────────────────
  Future<bool> sync() async {
    if (_state == SyncState.syncing) return false;
    _setState(SyncState.syncing);
    try {
      await _push();
      await _pull();
      _lastSyncTime = DateTime.now();
      await _updatePendingCount();
      _setState(SyncState.success);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setState(SyncState.error);
      return false;
    }
  }

  // ─── إرسال التغييرات المحلية للسيرفر ──────────────────────
  Future<void> _push() async {
    final db = await DatabaseService.database;
    final deviceId = await DeviceService.getDeviceId();
    final unsynced = await SyncLogService.getUnsynced(db);
    if (unsynced.isEmpty) return;

    final entries = unsynced
        .map((row) => {
              'table_name': row['table_name'],
              'record_id': row['record_id'],
              'operation': row['operation'],
              'data_json': row['data_json'],
              'local_ts': row['local_ts'],
            })
        .toList();

    final resp = await _post('/sync/push', {
      'device_id': deviceId,
      'entries': entries,
    });

    if (resp['error'] == 'device_not_approved') {
      throw Exception('الجهاز لم يُعتمد بعد من المدير');
    }

    final ids = unsynced.map((r) => r['id'] as int).toList();
    final maxServerId = (resp['max_server_id'] as int?) ?? 0;
    await SyncLogService.markSynced(db, ids, maxServerId);
  }

  // ─── سحب التغييرات من السيرفر وتطبيقها محلياً ─────────────
  Future<void> _pull() async {
    final db = await DatabaseService.database;
    final deviceId = await DeviceService.getDeviceId();
    final lastSeq = await SyncLogService.getLastServerSeq(db);

    final resp = await _get(
        '/sync/pull?after=$lastSeq&device_id=${Uri.encodeComponent(deviceId)}');

    final entries = resp['entries'] as List<dynamic>? ?? [];
    if (entries.isEmpty) return;

    await db.transaction((txn) async {
      for (final entry in entries) {
        await _applyEntry(txn, entry as Map<String, dynamic>);
      }
    });

    // حفظ آخر server_id مُستلَم
    final maxId = resp['max_id'] as int?;
    if (maxId != null && maxId > lastSeq) {
      await db.insert(
        'app_settings',
        {'key': 'last_pull_seq', 'value': maxId.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ─── تطبيق إدخال واحد من السيرفر على قاعدة البيانات المحلية
  Future<void> _applyEntry(
      DatabaseExecutor txn, Map<String, dynamic> entry) async {
    final table = entry['table_name']?.toString() ?? '';
    final op = entry['operation']?.toString() ?? '';
    final recordId = entry['record_id'] as int?;
    final rawData = entry['data_json']?.toString() ?? '{}';

    // لا نطبّق على جداول النظام
    const skipTables = {
      'sync_log',
      'app_settings',
      'device_registry',
      'user_sessions',
    };
    if (skipTables.contains(table)) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(rawData) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    try {
      switch (op) {
        case 'insert':
          if (recordId != null) {
            final existing = await txn.query(table,
                where: 'id = ?', whereArgs: [recordId], limit: 1);
            if (existing.isNotEmpty) {
              // موجود: تحديث (last-write-wins)
              await txn.update(table, data,
                  where: 'id = ?', whereArgs: [recordId]);
            } else {
              await txn.insert(table, data,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } else {
            await txn.insert(table, data,
                conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          break;

        case 'update':
          if (recordId != null) {
            await txn.update(table, data,
                where: 'id = ?', whereArgs: [recordId]);
          }
          break;

        case 'delete':
          if (recordId != null) {
            await txn.delete(table, where: 'id = ?', whereArgs: [recordId]);
          }
          break;
      }
    } catch (_) {
      // لا نوقف العملية بسبب خطأ في سطر واحد
    }
  }

  // ─── فحص الاتصال بالسيرفر ───────────────────────────────────
  Future<bool> _isOnline() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('${SyncConfig.serverBaseUrl}/healthz'));
      req.headers.set('X-API-Key', SyncConfig.apiKey);
      final resp =
          await req.close().timeout(const Duration(seconds: 6));
      client.close();
      return resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updatePendingCount() async {
    try {
      final db = await DatabaseService.database;
      _pendingCount = await SyncLogService.getPendingCount(db);
    } catch (_) {}
  }

  void _setState(SyncState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    _autoTimer?.cancel();
    _stateCtrl.close();
  }

  // ─── HTTP helpers ────────────────────────────────────────────
  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final client = HttpClient()
      ..connectionTimeout =
          Duration(seconds: SyncConfig.connectTimeoutSec);
    try {
      final uri = Uri.parse('${SyncConfig.serverBaseUrl}$path');
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('X-API-Key', SyncConfig.apiKey);
      req.write(jsonEncode(body));
      final resp = await req
          .close()
          .timeout(Duration(seconds: SyncConfig.receiveTimeoutSec));
      final b = await resp.transform(utf8.decoder).join();
      return jsonDecode(b) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final client = HttpClient()
      ..connectionTimeout =
          Duration(seconds: SyncConfig.connectTimeoutSec);
    try {
      final uri = Uri.parse('${SyncConfig.serverBaseUrl}$path');
      final req = await client.getUrl(uri);
      req.headers.set('X-API-Key', SyncConfig.apiKey);
      final resp = await req
          .close()
          .timeout(Duration(seconds: SyncConfig.receiveTimeoutSec));
      final b = await resp.transform(utf8.decoder).join();
      return jsonDecode(b) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
