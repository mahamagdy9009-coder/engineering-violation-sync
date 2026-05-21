// ============================================================
// attachment_server.dart — خادم استقبال المرفقات
// الموقع: lib/services/attachment_server.dart  (الديسكتوب)
//
// الجديد: يفتح Windows Firewall تلقائياً عند أول تشغيل
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef OnFileReceived = void Function(
  String filePath,
  String attachmentType,
  String reportId,
);

class AttachmentServer {
  static const int    httpPort       = 8080;
  static const int    beaconPort     = 8081;
  static const String _baseDir       = 'attachments';
  static const String _beaconMessage = 'ALFASHN_SCAN:8080';

  HttpServer?        _httpServer;
  RawDatagramSocket? _beaconSocket;
  Timer?             _beaconTimer;
  bool               _running = false;

  bool get isRunning => _running;
  OnFileReceived? onFileReceived;

  // =========================================================
  // START
  // =========================================================

  Future<void> start({OnFileReceived? onReceived}) async {
    if (_running) return;
    onFileReceived = onReceived;

    // ── فتح Windows Firewall تلقائياً (لا يحتاج تدخل المستخدم) ──
    await _setupFirewall();

    // ── ربط خادم HTTP على كل الواجهات ──────────────────────
    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      httpPort,
      shared: true,
    );

    _running = true;
    _listenHttp();

    // ── بث نبضة UDP كل 3 ثوانٍ ─────────────────────────────
    await _startBeacon();
  }

  // =========================================================
  // WINDOWS FIREWALL — يفتح المنفذ تلقائياً بدون رسائل
  // =========================================================

  static Future<void> _setupFirewall() async {
    if (!Platform.isWindows) return;
    try {
      // تحقق أولاً إذا كانت القاعدة موجودة
      final check = await Process.run('netsh', [
        'advfirewall', 'firewall', 'show', 'rule',
        'name=AlFashnScan_8080',
      ]);

      // إذا لم تكن موجودة، أضفها
      if (!check.stdout.toString().contains('AlFashnScan_8080')) {
        await Process.run('netsh', [
          'advfirewall', 'firewall', 'add', 'rule',
          'name=AlFashnScan_8080',
          'dir=in',
          'action=allow',
          'protocol=TCP',
          'localport=$httpPort',
          'profile=any',
          'enable=yes',
        ]);
      }

      // افتح UDP beacon أيضاً
      final checkUdp = await Process.run('netsh', [
        'advfirewall', 'firewall', 'show', 'rule',
        'name=AlFashnScan_8081',
      ]);
      if (!checkUdp.stdout.toString().contains('AlFashnScan_8081')) {
        await Process.run('netsh', [
          'advfirewall', 'firewall', 'add', 'rule',
          'name=AlFashnScan_8081',
          'dir=in',
          'action=allow',
          'protocol=UDP',
          'localport=$beaconPort',
          'profile=any',
          'enable=yes',
        ]);
      }
    } catch (_) {
      // إذا فشل الـ firewall setup، نكمل بدونه — Windows قد يعرض حوار تلقائياً
    }
  }

  // =========================================================
  // حذف قواعد الـ Firewall عند إلغاء التثبيت (اختياري)
  // =========================================================

  static Future<void> removeFirewallRules() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('netsh', ['advfirewall', 'firewall', 'delete',
          'rule', 'name=AlFashnScan_8080']);
      await Process.run('netsh', ['advfirewall', 'firewall', 'delete',
          'rule', 'name=AlFashnScan_8081']);
    } catch (_) {}
  }

  // =========================================================
  // STOP
  // =========================================================

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beaconSocket?.close();
    _beaconSocket = null;
    await _httpServer?.close(force: true);
    _httpServer = null;
    _running = false;
  }

  // =========================================================
  // UDP BEACON
  // =========================================================

  Future<void> _startBeacon() async {
    try {
      _beaconSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _beaconSocket!.broadcastEnabled = true;
      _beaconTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _sendBeacon());
      _sendBeacon();
    } catch (_) {}
  }

  void _sendBeacon() {
    try {
      final data = utf8.encode(_beaconMessage);
      _beaconSocket?.send(data, InternetAddress('255.255.255.255'), beaconPort);
      _beaconSocket?.send(data, InternetAddress('192.168.42.255'), beaconPort);
    } catch (_) {}
  }

  // =========================================================
  // HTTP LISTENER
  // =========================================================

  void _listenHttp() {
    _httpServer!.listen((request) async {
      try {
        await _handleRequest(request);
      } catch (e) {
        _respond(request.response, 500, {'error': e.toString()});
      }
    });
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
      ..add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      _respond(request.response, 200, {});
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && path == '/ping') {
      _respond(request.response, 200, {'status': 'ok'});
      return;
    }

    if (request.method == 'GET' && path == '/info') {
      final ips = await getLocalIPs();
      _respond(request.response, 200, {
        'status': 'ok', 'service': 'AlFashn Desktop',
        'port': httpPort, 'ips': ips,
      });
      return;
    }

    if (request.method == 'POST' && path == '/upload') {
      await _handleUpload(request);
      return;
    }

    _respond(request.response, 404, {'error': 'not_found'});
  }

  // =========================================================
  // HANDLE UPLOAD — raw bytes في الـ body + query params
  // =========================================================

  Future<void> _handleUpload(HttpRequest request) async {
    final params         = request.uri.queryParameters;
    final reportId       = params['reportId']       ?? 'unknown';
    final attachmentType = params['attachmentType'] ?? 'other';
    final clientFileName = params['fileName'];

    final fileName = (clientFileName?.isNotEmpty == true)
        ? clientFileName!
        : '${attachmentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // قراءة الـ bytes مباشرة
    final imageBytes = <int>[];
    await for (final chunk in request) {
      imageBytes.addAll(chunk);
    }

    if (imageBytes.isEmpty) {
      _respond(request.response, 400, {'error': 'empty_body'});
      return;
    }

    // حفظ الملف
    final dir = Directory(p.join(_baseDir, reportId));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final filePath = p.join(dir.path, fileName);
    await File(filePath).writeAsBytes(imageBytes, flush: true);

    final fileSize = File(filePath).lengthSync();
    if (fileSize <= 0) {
      _respond(request.response, 500, {'error': 'saved_file_empty'});
      return;
    }

    onFileReceived?.call(filePath, attachmentType, reportId);

    _respond(request.response, 200, {
      'status': 'ok',
      'fileName': fileName,
      'path': filePath,
      'size': fileSize,
    });
  }

  void _respond(HttpResponse response, int status, Map<String, dynamic> body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    response.close();
  }

  static Future<List<String>> getLocalIPs() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            result.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return result;
  }
}
