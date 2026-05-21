// ============================================================
// device_approval_screen.dart
// شاشة موافقة المدير على الأجهزة المحمولة الجديدة
// ضعها في: lib/screens/admin/device_approval_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import '../../sync/device_service.dart';

const _kDark = Color(0xFF05352D);
const _kMid = Color(0xFF0B6B55);
const _kCream = Color(0xFFF5F2EA);
const _kGold = Color(0xFFE5C07B);
const _kRed = Color(0xFFB42318);

class DeviceApprovalScreen extends StatefulWidget {
  const DeviceApprovalScreen({super.key});

  @override
  State<DeviceApprovalScreen> createState() => _DeviceApprovalScreenState();
}

class _DeviceApprovalScreenState extends State<DeviceApprovalScreen> {
  List<Map<String, dynamic>> _allDevices = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'pending' | 'approved' | 'rejected'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final devices = await DeviceService.getAllDevices();
    if (!mounted) return;
    setState(() {
      _allDevices = devices;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _allDevices;
    return _allDevices.where((d) => d['status'] == _filter).toList();
  }

  int _count(String status) =>
      _allDevices.where((d) => d['status'] == status).length;

  Future<void> _approve(Map<String, dynamic> device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: [
            const Icon(Icons.check_circle_outline, color: _kMid),
            const SizedBox(width: 8),
            const Text('تأكيد الاعتماد'),
          ]),
          content: Text(
            'هل تريد اعتماد الجهاز "${device['device_name']}"؟\n'
            'سيتمكن هذا الجهاز من المزامنة وقراءة/كتابة البيانات.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kMid),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('اعتماد ✓'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final id = device['id'] as int?;
    if (id == null) return;

    final success = await DeviceService.approveDevice(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          success ? '✓ تم اعتماد الجهاز بنجاح' : '✗ فشل الاعتماد — تحقق من الاتصال'),
      backgroundColor: success ? _kMid : _kRed,
    ));
    if (success) _load();
  }

  Future<void> _reject(Map<String, dynamic> device) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: [
            const Icon(Icons.cancel_outlined, color: _kRed),
            const SizedBox(width: 8),
            const Text('رفض الجهاز'),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('رفض الجهاز "${device['device_name']}"؟'),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'سبب الرفض (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رفض ✗'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final id = device['id'] as int?;
    if (id == null) return;

    final success =
        await DeviceService.rejectDevice(id, reason: ctrl.text.trim());
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(success ? '✗ تم رفض الجهاز' : '✗ فشل الرفض — تحقق من الاتصال'),
      backgroundColor: success ? Colors.orange : _kRed,
    ));
    if (success) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kCream,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kMid))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kDark,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.devices_outlined, color: _kGold, size: 22),
          const SizedBox(width: 8),
          const Text(
            'إدارة الأجهزة',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _filterChip('all', 'الكل', Colors.blueGrey, _allDevices.length),
          const SizedBox(width: 6),
          _filterChip('pending', 'انتظار', Colors.orange, _count('pending')),
          const SizedBox(width: 6),
          _filterChip('approved', 'معتمدة', _kMid, _count('approved')),
          const SizedBox(width: 6),
          _filterChip('rejected', 'مرفوضة', _kRed, _count('rejected')),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'تحديث',
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String val, String label, Color color, int count) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
              color: sel ? Colors.white : color,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: sel
                    ? Colors.white30
                    : color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    color: sel ? Colors.white : color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _DeviceCard(
        device: _filtered[i],
        onApprove: () => _approve(_filtered[i]),
        onReject: () => _reject(_filtered[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _filter == 'pending'
                ? 'لا توجد أجهزة بانتظار الاعتماد'
                : 'لا توجد أجهزة',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> device;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color get _borderColor {
    switch (device['status']) {
      case 'approved':
        return const Color(0xFF0B6B55);
      case 'rejected':
        return _kRed;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = device['status']?.toString() ?? 'pending';
    final type = device['device_type']?.toString() ?? '';
    final name = device['device_name']?.toString() ?? 'جهاز غير معروف';
    final username = device['username']?.toString() ?? '-';
    final platform = device['platform']?.toString() ?? '-';
    final registered =
        _fmtDate(device['registered_at']?.toString());
    final lastSync =
        _fmtDate(device['last_sync_at']?.toString());
    final isPending = status == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border(right: BorderSide(color: _borderColor, width: 5)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // أيقونة نوع الجهاز
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: type == 'desktop_trusted'
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'desktop_trusted'
                    ? Icons.computer_outlined
                    : Icons.smartphone_outlined,
                color: type == 'desktop_trusted'
                    ? _kMid
                    : Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // معلومات الجهاز
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    _StatusBadge(status),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'المستخدم: $username  |  النظام: $platform',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'التسجيل: $registered',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                  if (lastSync.isNotEmpty && lastSync != '-')
                    Text(
                      'آخر مزامنة: $lastSync',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),

            // أزرار الإجراء (للأجهزة المعلّقة فقط)
            if (isPending) ...[
              const SizedBox(width: 8),
              Column(
                children: [
                  SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kMid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('اعتماد',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kRed,
                        side: const BorderSide(color: _kRed),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('رفض',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = _kMid;
        label = 'معتمد ✓';
        break;
      case 'rejected':
        color = _kRed;
        label = 'مرفوض ✗';
        break;
      default:
        color = Colors.orange;
        label = 'انتظار...';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
