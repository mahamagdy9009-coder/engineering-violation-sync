// ============================================================
// sync_config.dart
// إعدادات المزامنة — عدّل serverBaseUrl بعد نشر السيرفر
// ============================================================

import 'dart:io';

class SyncConfig {
  // ═══════════════════════════════════════════════════════════
  // ⚠️ عدّل هذا الرابط بعد نشر السيرفر على Replit
  // مثال: https://alfashn-violations.ahmed.replit.app/api
  // ═══════════════════════════════════════════════════════════
  static const String serverBaseUrl =
      'https://engineering-violation-sync--btq16.replit.app/api';

  // مفتاح API المشترك — يجب أن يتطابق مع SYNC_API_KEY على السيرفر
  static const String apiKey = 'alfashn-sync-key-2024';

  // مهلة الاتصال (بالثواني)
  static const int connectTimeoutSec = 15;
  static const int receiveTimeoutSec = 30;

  // فترة التزامن التلقائي
  static const int autoSyncIntervalMinutes = 5;

  // ─── نوع الجهاز ─────────────────────────────────────────────
  // desktop_trusted = ديسكتوب (يُعتمد تلقائياً بدون موافقة)
  // mobile          = موبايل أو تابليت (يحتاج موافقة المدير)
  static String get deviceType {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'desktop_trusted';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'mobile';
    }
    return 'unknown';
  }

  /// هل هذا الجهاز ديسكتوب موثوق؟
  static bool get isTrustedDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// هل هذا الجهاز موبايل؟
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// هل التزامن مُفعَّل؟
  static bool syncEnabled = true;
}
