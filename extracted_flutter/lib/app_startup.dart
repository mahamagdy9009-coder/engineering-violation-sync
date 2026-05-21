// ============================================================
// app_startup.dart — تشغيل الخدمات عند بدء التطبيق
// ضعه في: lib/app_startup.dart
// ============================================================
// الاستخدام في main.dart:
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await AppStartup.init();
//     runApp(const MyApp());
//   }
//
// وفي dispose:
//   await AppStartup.dispose();
// ============================================================

import 'services/attachment_service.dart';
import 'sync/sync_config.dart';
import 'sync/sync_service.dart';
import 'sync/device_service.dart';

class AppStartup {
  static bool _initialized = false;

  /// يُستدعى مرة واحدة في main() قبل runApp
  static Future<void> init({String? currentUsername}) async {
    if (_initialized) return;
    _initialized = true;

    // ── 1. خادم استقبال مرفقات الماسح الضوئي (ديسكتوب فقط) ─────
    if (SyncConfig.isTrustedDesktop) {
      try {
        await AttachmentService.instance.start();
      } catch (_) {
        // الفشل هنا لا يوقف التطبيق
      }
    }

    // ── 2. تسجيل هذا الجهاز مع السيرفر (مرة واحدة) ─────────────
    if (SyncConfig.syncEnabled) {
      try {
        final registered = await DeviceService.isRegisteredLocally();
        if (!registered) {
          await DeviceService.registerDevice(
            username: currentUsername ?? 'unknown',
          );
        } else {
          // تحديث التسجيل في حالة تغيُّر URL السيرفر
          await DeviceService.registerDevice(
            username: currentUsername ?? 'unknown',
          );
        }
      } catch (_) {
        // فشل التسجيل لا يوقف التطبيق — الديسكتوب يعمل أوفلاين
      }
    }

    // ── 3. تشغيل التزامن التلقائي ────────────────────────────────
    if (SyncConfig.syncEnabled) {
      SyncService.instance.startAutoSync();
    }
  }

  /// تسجيل المستخدم بعد تسجيل الدخول
  static Future<void> onLogin(String username) async {
    if (!SyncConfig.syncEnabled) return;
    try {
      await DeviceService.registerDevice(username: username);
      // محاولة مزامنة فورية عند الدخول
      await SyncService.instance.syncIfOnline();
    } catch (_) {}
  }

  /// يُستدعى عند إغلاق التطبيق إن أمكن
  static Future<void> dispose() async {
    SyncService.instance.stopAutoSync();
    if (SyncConfig.isTrustedDesktop) {
      await AttachmentService.instance.stop();
    }
  }
}
