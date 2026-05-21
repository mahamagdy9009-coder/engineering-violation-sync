// ============================================================
// sync_status_screen.dart
// شاشة حالة المزامنة مع زر مزامنة يدوية
// ضعها في: lib/screens/sync/sync_status_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import '../../sync/sync_service.dart';
import '../../sync/sync_config.dart';
import '../../sync/device_service.dart';
import '../../sync/sync_log_service.dart';
import '../../database/database_service.dart';

const _kDark = Color(0xFF05352D);
const _kMid = Color(0xFF0B6B55);
const _kCream = Color(0xFFF5F2EA);
const _kGold = Color(0xFFE5C07B);
const _kRed = Color(0xFFB42318);

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  String _deviceId = '...';
  String _deviceType = '...';
  DeviceStatus _deviceStatus = DeviceStatus.unknown;
  int _pendingCount = 0;
  bool _loadingInfo = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _loadingInfo = true);
    final deviceId = await DeviceService.getDeviceId();
    final deviceStatus = await DeviceService.checkStatus(forceRefresh: true);
    final db = await DatabaseService.database;
    final pending = await SyncLogService.getPendingCount(db);

    if (!mounted) return;
    setState(() {
      _deviceId = deviceId;
      _deviceType = SyncConfig.deviceType;
      _deviceStatus = deviceStatus;
      _pendingCount = pending;
      _loadingInfo = false;
    });
  }

  Future<void> _manualSync() async {
    await SyncService.instance.sync();
    await _loadInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kCream,
        body: Column(
          children: [
            // هيدر
            Container(
              color: _kDark,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.sync, color: _kGold, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'حالة المزامنة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadInfo,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'تحديث',
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loadingInfo
                  ? const Center(
                      child: CircularProgressIndicator(color: _kMid))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDeviceCard(),
                          const SizedBox(height: 16),
                          _buildSyncStateCard(),
                          const SizedBox(height: 16),
                          _buildServerCard(),
                          const SizedBox(height: 24),
                          _buildSyncButton(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    final isDesktop = SyncConfig.isTrustedDesktop;
    return _InfoCard(
      title: 'معلومات هذا الجهاز',
      icon: isDesktop ? Icons.computer : Icons.smartphone,
      iconColor: isDesktop ? _kMid : Colors.blue,
      children: [
        _InfoRow(
          label: 'نوع الجهاز',
          value: isDesktop ? 'ديسكتوب (موثوق)' : 'موبايل / تابليت',
        ),
        _InfoRow(
          label: 'معرّف الجهاز',
          value: _deviceId.length > 20
              ? '${_deviceId.substring(0, 20)}...'
              : _deviceId,
        ),
        _InfoRow(
          label: 'حالة الاعتماد',
          value: _deviceStatusLabel(_deviceStatus),
          valueColor: _deviceStatusColor(_deviceStatus),
        ),
      ],
    );
  }

  Widget _buildSyncStateCard() {
    final state = SyncService.instance.state;
    final lastSync = SyncService.instance.lastSyncTime;

    return _InfoCard(
      title: 'حالة التزامن',
      icon: Icons.sync,
      iconColor: _syncStateColor(state),
      children: [
        _InfoRow(
          label: 'الحالة الحالية',
          value: _syncStateLabel(state),
          valueColor: _syncStateColor(state),
        ),
        if (lastSync != null)
          _InfoRow(
            label: 'آخر مزامنة ناجحة',
            value: _fmtDate(lastSync.toIso8601String()),
          ),
        _InfoRow(
          label: 'تغييرات لم تُزامَن',
          value: '$_pendingCount تعديل',
          valueColor: _pendingCount > 0 ? Colors.orange : _kMid,
        ),
        if (state == SyncState.error)
          _InfoRow(
            label: 'آخر خطأ',
            value: SyncService.instance.lastError,
            valueColor: _kRed,
          ),
      ],
    );
  }

  Widget _buildServerCard() {
    final url = SyncConfig.serverBaseUrl;
    final configured = !url.contains('YOUR-REPLIT');
    return _InfoCard(
      title: 'إعدادات السيرفر',
      icon: Icons.cloud_outlined,
      iconColor: configured ? _kMid : Colors.orange,
      children: [
        _InfoRow(
          label: 'عنوان السيرفر',
          value: configured ? url : '⚠️ لم يُضبط بعد',
          valueColor: configured ? null : Colors.orange,
        ),
        _InfoRow(
          label: 'التزامن التلقائي',
          value: SyncConfig.syncEnabled
              ? 'كل ${SyncConfig.autoSyncIntervalMinutes} دقائق'
              : 'مُعطَّل',
        ),
      ],
    );
  }

  Widget _buildSyncButton() {
    return StreamBuilder<SyncState>(
      stream: SyncService.instance.onStateChanged,
      initialData: SyncService.instance.state,
      builder: (context, snap) {
        final syncing = snap.data == SyncState.syncing;
        return SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: syncing ? null : _manualSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kMid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            label: Text(
              syncing ? 'جاري المزامنة...' : 'مزامنة الآن',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  String _deviceStatusLabel(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.approved:
        return 'معتمد ✓';
      case DeviceStatus.pending:
        return 'في انتظار موافقة المدير';
      case DeviceStatus.rejected:
        return 'مرفوض ✗';
      case DeviceStatus.serverUnreachable:
        return 'لا يمكن الوصول للسيرفر';
      default:
        return 'غير معروف';
    }
  }

  Color _deviceStatusColor(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.approved:
        return _kMid;
      case DeviceStatus.pending:
        return Colors.orange;
      case DeviceStatus.rejected:
        return _kRed;
      default:
        return Colors.grey;
    }
  }

  String _syncStateLabel(SyncState s) {
    switch (s) {
      case SyncState.syncing:
        return 'جاري التزامن...';
      case SyncState.success:
        return 'مُزامَن ✓';
      case SyncState.error:
        return 'خطأ في التزامن';
      case SyncState.disabled:
        return 'مُعطَّل';
      default:
        return 'جاهز';
    }
  }

  Color _syncStateColor(SyncState s) {
    switch (s) {
      case SyncState.syncing:
        return Colors.blue;
      case SyncState.success:
        return _kMid;
      case SyncState.error:
        return _kRed;
      default:
        return Colors.grey;
    }
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

// ─── مكونات مساعدة ─────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _kDark),
              ),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF2D2D2D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
