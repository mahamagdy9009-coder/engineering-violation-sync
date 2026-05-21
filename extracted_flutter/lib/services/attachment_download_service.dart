// ============================================================
// attachment_download_service.dart — تحميل المرفقات بصيغة JPG أو PDF
// الموقع: lib/services/attachment_download_service.dart (الديسكتوب)
//
// يُستخدم من شاشة عرض المرفقات:
//   AttachmentDownloadService.showDownloadDialog(context, filePath);
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

// PDF generation — أضف للـ pubspec: pdf: ^3.10.7
// إذا لم يكن مثبّتاً، استخدم الـ fallback الموجود أسفله
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// File picker — أضف للـ pubspec: file_picker: ^8.0.3
import 'package:file_picker/file_picker.dart';

class AttachmentDownloadService {

  // =========================================================
  // الواجهة الرئيسية — استدعِ هذه الدالة من أي مكان
  // =========================================================

  static Future<void> showDownloadDialog(
    BuildContext context,
    String sourceFilePath, {
    String? suggestedName,
  }) async {
    final fileName = suggestedName ??
        p.basenameWithoutExtension(sourceFilePath);

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => _DownloadDialog(fileName: fileName),
    );

    if (choice == null || !context.mounted) return;

    try {
      if (choice == 'jpg') {
        await _saveAsJpg(context, sourceFilePath, fileName);
      } else if (choice == 'pdf') {
        await _saveAsPdf(context, sourceFilePath, fileName);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحميل: $e'),
              backgroundColor: Colors.red));
      }
    }
  }

  // =========================================================
  // حفظ بصيغة JPG
  // =========================================================

  static Future<void> _saveAsJpg(
    BuildContext context,
    String sourcePath,
    String suggestedName,
  ) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ الصورة',
      fileName: '$suggestedName.jpg',
      type: FileType.image,
      allowedExtensions: ['jpg'],
    );

    if (savePath == null) return;

    final dest = savePath.endsWith('.jpg') ? savePath : '$savePath.jpg';
    await File(sourcePath).copy(dest);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('تم الحفظ: $dest')),
          ]),
          backgroundColor: const Color(0xFF0B6B55),
          duration: const Duration(seconds: 4),
        ));
    }
  }

  // =========================================================
  // حفظ بصيغة PDF
  // =========================================================

  static Future<void> _saveAsPdf(
    BuildContext context,
    String sourcePath,
    String suggestedName,
  ) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ كـ PDF',
      fileName: '$suggestedName.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (savePath == null) return;

    // قراءة الصورة
    final imageBytes = await File(sourcePath).readAsBytes();

    // إنشاء PDF
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
      ),
    );

    final pdfImage = pw.MemoryImage(imageBytes);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context ctx) => pw.Center(
        child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
      ),
    ));

    final pdfBytes = await pdf.save();
    final dest = savePath.endsWith('.pdf') ? savePath : '$savePath.pdf';
    await File(dest).writeAsBytes(pdfBytes);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.picture_as_pdf,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('تم الحفظ كـ PDF: $dest')),
          ]),
          backgroundColor: const Color(0xFF0B6B55),
          duration: const Duration(seconds: 4),
        ));
    }
  }
}

// =========================================================
// حوار اختيار الصيغة
// =========================================================

class _DownloadDialog extends StatelessWidget {
  final String fileName;
  const _DownloadDialog({required this.fileName});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      backgroundColor: const Color(0xFF0F2119),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(children: [
        Icon(Icons.download_rounded, color: Color(0xFFE5C07B), size: 20),
        SizedBox(width: 8),
        Text('تحميل المرفق',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('اختر صيغة الحفظ لـ "$fileName"',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 20),
        // زر JPG
        _FormatBtn(
          icon: Icons.image_outlined,
          label: 'صورة JPG',
          subtitle: 'صورة عالية الجودة قابلة للمشاركة',
          color: const Color(0xFF1565C0),
          onTap: () => Navigator.pop(context, 'jpg'),
        ),
        const SizedBox(height: 10),
        // زر PDF
        _FormatBtn(
          icon: Icons.picture_as_pdf_outlined,
          label: 'مستند PDF',
          subtitle: 'مناسب للطباعة والأرشفة',
          color: const Color(0xFFB71C1C),
          onTap: () => Navigator.pop(context, 'pdf'),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: Colors.white38))),
      ],
    ));
}

class _FormatBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  const _FormatBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label, style: TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(
                color: Colors.white54, fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ]),
      ),
    ));
}
