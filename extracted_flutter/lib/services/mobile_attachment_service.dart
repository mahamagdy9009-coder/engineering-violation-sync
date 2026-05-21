// ============================================================
// mobile_attachment_service.dart
// خدمة مرفقات الموبايل والتابليت — التقاط صور بالكاميرا
// ضعها في: lib/services/mobile_attachment_service.dart
//
// لاستخدامها، أضف هذا الـ package في pubspec.yaml:
//   dependencies:
//     image_picker: ^1.1.2
//
// وأضف الأذونات في:
//   Android: android/app/src/main/AndroidManifest.xml
//     <uses-permission android:name="android.permission.CAMERA"/>
//   iOS: ios/Runner/Info.plist
//     <key>NSCameraUsageDescription</key>
//     <string>التقاط صور للمرفقات</string>
//     <key>NSPhotoLibraryUsageDescription</key>
//     <string>اختيار صور من المعرض</string>
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'attachment_service.dart';
import '../database/database_service.dart';

// ── نوع مصدر الصورة ──────────────────────────────────────────
enum ImageSourceType { camera, gallery }

class MobileAttachmentService {
  // ─── أخذ صورة من الكاميرا أو المعرض ───────────────────────
  // يعيد مسار الملف المحفوظ أو null عند الإلغاء
  static Future<String?> pickImage({
    required BuildContext context,
    required ImageSourceType source,
    required int caseId,
    required String attachmentType,
    required int uploadedByUserId,
  }) async {
    // محاولة استخدام image_picker إذا كان مثبَّتاً
    String? pickedPath;
    try {
      pickedPath = await _pickWithImagePicker(source);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'تعذّر فتح الكاميرا — تأكد من تثبيت image_picker وإضافة الأذونات'),
          backgroundColor: Colors.red[700],
        ));
      }
      return null;
    }

    if (pickedPath == null) return null;

    // نسخ الصورة إلى مجلد المرفقات
    final savedPath = await _saveToAttachments(pickedPath, caseId);
    if (savedPath == null) return null;

    // حفظ في قاعدة البيانات مع طلب اعتماد
    await AttachmentService.instance.addManualWithApproval(
      filePath: savedPath,
      attachmentType: attachmentType,
      caseId: caseId,
      requestedBy: uploadedByUserId,
    );

    return savedPath;
  }

  // ─── حفظ الصورة في مجلد المرفقات ───────────────────────────
  static Future<String?> _saveToAttachments(
      String sourcePath, int caseId) async {
    try {
      final dir = Directory(p.join('attachments', '$caseId'));
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final ext = p.extension(sourcePath).toLowerCase();
      final fileName =
          '${attachmentTypeLabel}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(dir.path, fileName);

      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  static const String attachmentTypeLabel = 'mobile_photo';

  // ─── محاولة استخدام image_picker (تحتاج تثبيت المكتبة) ─────
  static Future<String?> _pickWithImagePicker(
      ImageSourceType source) async {
    // ملاحظة: هذا الكود يتطلب تثبيت مكتبة image_picker في pubspec.yaml
    // import 'package:image_picker/image_picker.dart';
    // final picker = ImagePicker();
    // final file = await picker.pickImage(
    //   source: source == ImageSourceType.camera
    //       ? ImageSource.camera
    //       : ImageSource.gallery,
    //   imageQuality: 85,
    //   maxWidth: 1920,
    //   maxHeight: 1920,
    // );
    // return file?.path;

    // بديل مؤقت: اعرض رسالة للمطور
    throw UnsupportedError(
        'يجب إضافة مكتبة image_picker إلى pubspec.yaml\n'
        'ثم إلغاء تعليق الكود في _pickWithImagePicker');
  }

  // ─── واجهة الاختيار (كاميرا أو معرض) ──────────────────────
  static Future<String?> showPickerDialog({
    required BuildContext context,
    required int caseId,
    required String attachmentType,
    required int uploadedByUserId,
  }) async {
    final source = await showDialog<ImageSourceType>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Text('إضافة صورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF0B6B55)),
                title: const Text('كاميرا الجهاز'),
                subtitle: const Text('التقاط صورة جديدة'),
                onTap: () =>
                    Navigator.pop(ctx, ImageSourceType.camera),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF0B6B55)),
                title: const Text('معرض الصور'),
                subtitle: const Text('اختيار صورة موجودة'),
                onTap: () =>
                    Navigator.pop(ctx, ImageSourceType.gallery),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return null;

    return pickImage(
      context: context,
      source: source,
      caseId: caseId,
      attachmentType: attachmentType,
      uploadedByUserId: uploadedByUserId,
    );
  }
}
