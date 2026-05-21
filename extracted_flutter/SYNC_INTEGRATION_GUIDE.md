# دليل تكامل المزامنة متعددة الأجهزة
## برنامج إدارة مخالفات هندسة صرف الفشن

---

## ✅ ما تم إنشاؤه

### ملفات Flutter الجديدة (انسخها لمشروعك)

```
lib/sync/
  sync_config.dart         ← إعدادات السيرفر ورابط الـ API
  sync_service.dart        ← خدمة المزامنة الرئيسية (push + pull)
  sync_log_service.dart    ← تسجيل التعديلات في sync_log
  device_service.dart      ← هوية الجهاز + التسجيل + الاعتماد

lib/screens/admin/
  device_approval_screen.dart  ← شاشة المدير للموافقة على الأجهزة المحمولة

lib/screens/sync/
  sync_status_screen.dart  ← شاشة عرض حالة المزامنة + مزامنة يدوية

lib/widgets/
  sync_status_badge.dart   ← أيقونة صغيرة في شريط التطبيق
  responsive_layout.dart   ← مساعد تخطيط متجاوب (ديسكتوب/تابليت/موبايل)

lib/database/
  database_migrations.dart ← ترقية SQLite إلى v3 (جداول المزامنة)

lib/services/
  mobile_attachment_service.dart ← مرفقات الموبايل عبر الكاميرا
```

### ملفات معدّلة
```
lib/app_startup.dart          ← يبدأ المزامنة التلقائية بعد الإقلاع
lib/screens/login/login_screen.dart ← يفحص اعتماد الجهاز + واجهة متجاوبة
```

---

## 🔧 خطوات التكامل

### الخطوة 1: تحديث pubspec.yaml

أضف `image_picker` لدعم الكاميرا على الموبايل:

```yaml
dependencies:
  # ...الـ packages الموجودة...
  image_picker: ^1.1.2
```

ثم:
```bash
flutter pub get
```

### الخطوة 2: ضبط رابط السيرفر

في `lib/sync/sync_config.dart`، بدّل هذا السطر برابط مشروعك على Replit:

```dart
static const String serverBaseUrl =
    'https://YOUR-REPLIT-PROJECT.replit.app/api';
    //   ↑↑↑ بدّل هذا بالرابط الفعلي لمشروعك
```

**كيف تحصل على الرابط؟**
- اذهب للمشروع على Replit
- انقر "Deploy" أو "Publish"
- ستجد الرابط بصيغة: `https://اسم-المشروع.اسم-المستخدم.replit.app`

### الخطوة 3: ترقية قاعدة البيانات المحلية (SQLite)

في `database_service.dart`، ابحث عن `initDatabase()` وعدّلها:

```dart
static Future<Database> initDatabase() async {
  // ... نفس الكود الموجود ...
  return openDatabase(
    path,
    version: DatabaseMigrations.targetVersion,  // ← غيّر من 2 إلى 3
    onCreate: (db, version) async {
      // ... إنشاء الجداول الأصلية ...
      await DatabaseMigrations.runMigrations(db, 0, version); // ← أضف هذا
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      await DatabaseMigrations.runMigrations(db, oldVersion, newVersion); // ← أضف هذا
    },
  );
}
```

وأضف هذا الاستيراد في أعلى الملف:
```dart
import 'database_migrations.dart';
```

### الخطوة 4: تسجيل التعديلات في sync_log

في كل `insert/update/delete` على الجداول الرئيسية (`violation_cases`, `gis_drawings`، إلخ)، أضف هذا بعد العملية مباشرةً:

```dart
import '../sync/sync_log_service.dart';
import '../sync/device_service.dart';

// مثال: بعد إضافة قضية جديدة
final id = await db.insert('violation_cases', caseData);
final deviceId = await DeviceService.getDeviceId();
await SyncLogService.logChange(
  db: db,
  deviceId: deviceId,
  tableName: 'violation_cases',
  recordId: id,
  operation: 'insert',
  dataJson: caseData,
);
```

### الخطوة 5: إضافة Badge المزامنة في AppBar

في `dashboard_screen.dart`، أضف `SyncStatusBadge` لأزرار AppBar:

```dart
import '../../widgets/sync_status_badge.dart';
import '../sync/sync_status_screen.dart';

// داخل AppBar:
actions: [
  SyncStatusBadge(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
    ),
  ),
  // ... باقي الأزرار ...
],
```

### الخطوة 6: إضافة شاشة اعتماد الأجهزة للمدير

في `dashboard_screen.dart` (القائمة الجانبية - للمدير فقط):

```dart
import '../admin/device_approval_screen.dart';

// داخل القائمة الجانبية للمدير (hndsa):
if (widget.user['role'] == 'admin') ...[
  ListTile(
    leading: const Icon(Icons.devices_outlined),
    title: const Text('اعتماد الأجهزة'),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceApprovalScreen()),
    ),
  ),
],
```

### الخطوة 7: أذونات الكاميرا (للموبايل)

**Android** — في `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**iOS** — في `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>التقاط صور للمرفقات</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>اختيار صور من المعرض</string>
```

---

## 🏗️ كيف يعمل النظام

```
┌────────────────────────────────────────────────────────┐
│                    السيرفر (Replit)                    │
│  PostgreSQL: sync_log + device_registry                │
│  POST /api/sync/push   — استقبال التعديلات             │
│  GET  /api/sync/pull   — إرسال تعديلات الأجهزة الأخرى │
│  POST /api/devices/register — تسجيل جهاز جديد         │
│  GET  /api/devices/pending  — الأجهزة المعلّقة         │
│  POST /api/devices/:id/approve — موافقة المدير         │
└───────────────┬────────────────────────────────────────┘
                │ HTTPS (بيانات قليلة جداً — نصوص فقط)
     ┌──────────┴──────────┐
     │                     │
┌────▼────────┐    ┌───────▼────────┐
│  جهاز المطور │   │  الموبايل/تابليت│
│  (ديسكتوب)  │   │                │
│  SQLite     │   │  SQLite        │
│  أوفلاين    │   │  متصل دائماً   │
│  يتصل بالهوتسبوت│  يزامن تلقائياً │
│  كل 5 دقائق │   │  كل 5 دقائق    │
└─────────────┘   └────────────────┘
        │
┌───────▼─────────────┐
│  مكتب الهندسة (PC)  │
│  (ديسكتوب - أوفلاين)│
│  SQLite              │
│  يتصل 5 دقائق/يوم   │
└─────────────────────┘
```

### بروتوكول المزامنة

1. **كل تعديل** (إضافة/تعديل/حذف) يُسجَّل في `sync_log` المحلي
2. عند الاتصال، `push()` يرفع السجلات غير المُزامَنة للسيرفر
3. ثم `pull()` يسحب تعديلات الأجهزة الأخرى ويطبّقها محلياً
4. **الصور والمرفقات** تبقى على الجهاز — لا تُرسَل (لتوفير الداتا)
5. **حل التعارض**: آخر تعديل يكسب (بناءً على الوقت المحلي)

---

## 🔑 اعتماد الأجهزة

| نوع الجهاز | الاعتماد |
|------------|----------|
| ديسكتوب (Windows/Linux/Mac) | تلقائي — بدون موافقة |
| موبايل / تابليت (Android/iOS) | يحتاج موافقة مدير النظام (hndsa) |

**خطوات الموبايل:**
1. الموبايل يفتح التطبيق ويسجل الدخول
2. يُرسَل طلب اعتماد للسيرفر تلقائياً
3. المدير يفتح "اعتماد الأجهزة" ويوافق
4. في الزيارة التالية، الموبايل يبدأ في المزامنة

---

## 🚀 النشر (الخطوات الأخيرة)

1. **انشر السيرفر على Replit**: انقر "Deploy" في المشروع
2. **انسخ رابط الـ API** وضعه في `sync_config.dart`
3. **بنِ التطبيق لـ Android**: `flutter build apk`
4. **ثبّته على الموبايل/التابليت**
5. **اضبط مفتاح SYNC_API_KEY** على السيرفر (موجود بالفعل: `alfashn-sync-key-2024`)

---

## 🔒 الأمان

- كل طلب يحتاج `X-API-Key: alfashn-sync-key-2024`
- يمكنك تغيير المفتاح من Replit Secrets (متغير `SYNC_API_KEY`)
- الأجهزة المرفوضة لا تستطيع رفع أي بيانات
- الصور لا تُرسَل عبر الشبكة (بيانات قليلة)
