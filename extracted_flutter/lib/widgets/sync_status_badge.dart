// ============================================================
// sync_status_badge.dart
// أيقونة صغيرة في شريط التطبيق تعرض حالة المزامنة
// الاستخدام: أضفها في actions في AppBar
//   actions: [ SyncStatusBadge(onTap: () => openSyncScreen()) ]
// ============================================================

import 'package:flutter/material.dart';
import '../sync/sync_service.dart';

class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncState>(
      stream: SyncService.instance.onStateChanged,
      initialData: SyncService.instance.state,
      builder: (context, snap) {
        final state = snap.data ?? SyncState.idle;

        if (state == SyncState.syncing) {
          _spinCtrl.repeat();
        } else {
          _spinCtrl.stop();
        }

        return IconButton(
          tooltip: _tooltip(state),
          onPressed: () {
            if (state != SyncState.syncing) {
              SyncService.instance.syncIfOnline();
            }
            widget.onTap?.call();
          },
          icon: _buildIcon(state),
        );
      },
    );
  }

  Widget _buildIcon(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return RotationTransition(
          turns: _spinCtrl,
          child: const Icon(Icons.sync, color: Colors.white70, size: 22),
        );
      case SyncState.success:
        return const Icon(Icons.cloud_done_outlined,
            color: Colors.greenAccent, size: 22);
      case SyncState.error:
        return const Icon(Icons.cloud_off_outlined,
            color: Colors.orangeAccent, size: 22);
      case SyncState.disabled:
        return const Icon(Icons.sync_disabled_outlined,
            color: Colors.white38, size: 22);
      default:
        return const Icon(Icons.sync_outlined, color: Colors.white70, size: 22);
    }
  }

  String _tooltip(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return 'جاري المزامنة...';
      case SyncState.success:
        final t = SyncService.instance.lastSyncTime;
        if (t != null) {
          final diff = DateTime.now().difference(t);
          if (diff.inMinutes < 1) return 'مُزامَن ✓';
          if (diff.inHours < 1) return 'مُزامَن منذ ${diff.inMinutes} دقيقة';
          return 'مُزامَن منذ ${diff.inHours} ساعة';
        }
        return 'مُزامَن ✓';
      case SyncState.error:
        return 'خطأ في المزامنة — اضغط لإعادة المحاولة';
      case SyncState.disabled:
        return 'المزامنة مُعطَّلة';
      default:
        return 'اضغط للمزامنة';
    }
  }
}
