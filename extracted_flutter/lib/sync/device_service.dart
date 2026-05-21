// ============================================================
// device_service.dart
// إدارة هوية الجهاز وتسجيله مع السيرفر
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_service.dart';
import 'sync_config.dart';

enum DeviceStatus {
  approved,
  pending,
  rejected,
  unknown,
  serverUnreachable,
}

class DeviceService {
  static String? _cachedDeviceId;
  static DeviceStatus? _cachedStatus;

  // ─── الحصول على device_id (أو إنشاؤه) ──────────────────────
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    final db = await DatabaseService.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['device_id'],
    );
    if (rows.isNotEmpty) {
      final id = rows.first['value']?.toString() ?? '';
      if (id.isNotEmpty) {
        _cachedDeviceId = id;
        return id;
      }
    }
    // إنشاء device_id جديد فريد
    final id = _generateId();
    await db.insert(
      'app_settings',
      {'key': 'device_id', 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedDeviceId = id;
    return id;
  }

  static String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final hash = (ts ^ Platform.operatingSystem.hashCode).abs();
    return 'dev-$ts-$hash';
  }

  // ─── تسجيل الجهاز مع السيرفر ───────────────────────────────
  static Future<bool> registerDevice({
    required String username,
    String? deviceName,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final name = deviceName ??
          '${SyncConfig.deviceType == 'desktop_trusted' ? 'ديسكتوب' : 'موبايل'}-$username';
      final type = SyncConfig.deviceType;

      // حفظ محلياً أولاً
      final db = await DatabaseService.database;
      await db.insert(
        'device_registry',
        {
          'device_id': deviceId,
          'device_name': name,
          'device_type': type,
          'platform': Platform.operatingSystem,
          'username': username,
          'status': type == 'desktop_trusted' ? 'approved' : 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // إرسال للسيرفر
      final resp = await _post('/devices/register', {
        'device_id': deviceId,
        'device_name': name,
        'device_type': type,
        'platform': Platform.operatingSystem,
        'username': username,
      });

      return resp['success'] == true || resp['status'] != null;
    } catch (_) {
      // إذا السيرفر غير متاح، نكمل — الديسكتوب يعمل أوفلاين
      return SyncConfig.isTrustedDesktop;
    }
  }

  // ─── التحقق من حالة الجهاز ──────────────────────────────────
  static Future<DeviceStatus> checkStatus({bool forceRefresh = false}) async {
    // الديسكتوب الموثوق: دائماً approved
    if (SyncConfig.isTrustedDesktop) return DeviceStatus.approved;

    if (_cachedStatus != null && !forceRefresh) return _cachedStatus!;

    try {
      final deviceId = await getDeviceId();
      final resp = await _get('/devices/status/$deviceId');
      final status = resp['status']?.toString() ?? 'unknown';
      _cachedStatus = _parseStatus(status);
      return _cachedStatus!;
    } catch (_) {
      return DeviceStatus.serverUnreachable;
    }
  }

  static DeviceStatus _parseStatus(String s) {
    switch (s) {
      case 'approved':
        return DeviceStatus.approved;
      case 'pending':
        return DeviceStatus.pending;
      case 'rejected':
        return DeviceStatus.rejected;
      default:
        return DeviceStatus.unknown;
    }
  }

  /// هل الجهاز مسجَّل محلياً؟
  static Future<bool> isRegisteredLocally() async {
    try {
      final db = await DatabaseService.database;
      final rows = await db.query('device_registry', limit: 1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// جلب الأجهزة المعلّقة من السيرفر (للمدير فقط)
  static Future<List<Map<String, dynamic>>> getPendingDevices() async {
    try {
      final resp = await _get('/devices/pending');
      return List<Map<String, dynamic>>.from(resp['devices'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// جلب كل الأجهزة من السيرفر (للمدير فقط)
  static Future<List<Map<String, dynamic>>> getAllDevices() async {
    try {
      final resp = await _get('/devices/all');
      return List<Map<String, dynamic>>.from(resp['devices'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// الموافقة على جهاز
  static Future<bool> approveDevice(int serverId) async {
    try {
      final resp = await _post('/devices/$serverId/approve', {});
      return resp['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// رفض جهاز
  static Future<bool> rejectDevice(int serverId, {String? reason}) async {
    try {
      final resp = await _post('/devices/$serverId/reject', {
        'reason': reason ?? '',
      });
      return resp['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static void clearCache() {
    _cachedDeviceId = null;
    _cachedStatus = null;
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
      final resp = await req.close()
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
      final resp = await req.close()
          .timeout(Duration(seconds: SyncConfig.receiveTimeoutSec));
      final b = await resp.transform(utf8.decoder).join();
      return jsonDecode(b) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
