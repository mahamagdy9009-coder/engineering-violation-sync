// ============================================================
// usb_server_badge.dart — شريط حالة خادم USB في الديسكتوب
// الموقع: lib/widgets/usb_server_badge.dart
//
// الاستخدام بسيط جداً — ضعه في أي مكان بدون أي parameters:
//   UsbServerBadge()
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/attachment_server.dart';
import '../services/attachment_service.dart';

class UsbServerBadge extends StatefulWidget {
  // لا يحتاج أي parameters — يأخذ الخادم من AttachmentService تلقائياً
  const UsbServerBadge({super.key});

  @override
  State<UsbServerBadge> createState() => _UsbServerBadgeState();
}

class _UsbServerBadgeState extends State<UsbServerBadge> {
  List<String> _ips = [];
  bool _usbTethering = false;
  Timer? _timer;

  // نصل للخادم عبر الـ singleton
  AttachmentService get _svc => AttachmentService.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ips = await AttachmentServer.getLocalIPs();
    // شبكة USB Tethering من Android تكون 192.168.42.x
    final hasUsb = ips.any(
      (ip) =>
          ip.startsWith('192.168.42.') ||
          ip.startsWith('192.168.0.') ||
          ip.startsWith('192.168.1.'),
    );
    if (mounted) {
      setState(() {
        _ips = ips;
        _usbTethering = hasUsb;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _svc.serverRunning;
    final statusColor = !isRunning
        ? Colors.red
        : _usbTethering
            ? Colors.green
            : Colors.orange;

    final statusText = !isRunning
        ? 'الخادم متوقف'
        : _usbTethering
            ? 'USB متصل'
            : 'في انتظار USB';

    return Tooltip(
      message: _buildTooltip(isRunning),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _showDetails,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isRunning ? Icons.usb : Icons.usb_off,
                color: statusColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildTooltip(bool isRunning) {
    if (!isRunning) return 'خادم المرفقات متوقف';
    if (_ips.isEmpty) {
      return 'لا توجد شبكة — وصّل الموبايل بـ USB وفعّل USB Tethering';
    }
    return 'الخادم يعمل على:\n'
        '${_ips.map((ip) => '$ip:${AttachmentServer.httpPort}').join('\n')}';
  }

  void _showDetails() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF05352D),
          title: const Text(
            'حالة اتصال الموبايل',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(
                icon: Icons.circle,
                color: _svc.serverRunning ? Colors.green : Colors.red,
                label: _svc.serverRunning
                    ? 'الخادم يعمل على منفذ ${AttachmentServer.httpPort}'
                    : 'الخادم متوقف',
              ),
              const SizedBox(height: 12),
              _StatusRow(
                icon: _usbTethering ? Icons.usb : Icons.usb_off,
                color: _usbTethering ? Colors.green : Colors.orange,
                label: _usbTethering
                    ? 'تم اكتشاف شبكة USB Tethering'
                    : 'لم يتم اكتشاف USB Tethering',
              ),
              const SizedBox(height: 16),
              if (_ips.isNotEmpty) ...[
                const Text(
                  'عناوين IP المتاحة:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ..._ips.map(
                  (ip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$ip:${AttachmentServer.httpPort}',
                      style: const TextStyle(
                        color: Color(0xFFE5C07B),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              const Text(
                'كيفية الاتصال لأول مرة:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              const _Step(number: '1', text: 'وصّل الموبايل بـ USB'),
              const _Step(
                number: '2',
                text:
                    'في الهاتف: الإعدادات ← نقطة الاتصال والمودم ← USB Tethering ← تفعيل',
              ),
              const _Step(number: '3', text: 'افتح Al Fashn Scan في الموبايل'),
              const _Step(
                  number: '4', text: 'سيتصل تلقائياً بدون أي إجراء إضافي!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _refresh();
                Navigator.pop(ctx);
              },
              child: const Text(
                'تحديث',
                style: TextStyle(color: Color(0xFFE5C07B)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF0B6B55),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
