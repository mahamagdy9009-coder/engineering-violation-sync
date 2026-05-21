// ============================================================
// export_service.dart  —  lib/services/export_service.dart
// تصدير المحاضر إلى Excel / PDF / Word (RTF)
// ============================================================

// dart:convert يوفّر arabic‑safe latin1 encoder للـ RTF
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

// Hide Border from excel to avoid conflict with flutter's Border
import 'package:excel/excel.dart' hide Border, TextDirection;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExportService {
  // ── أعمدة جدول Excel الكامل (24 عموداً) ─────────────────────
  static const List<String> _columnHeaders = [
    'م',
    'رقم المحضر',
    'سنة المحضر',
    'تاريخ المحضر',
    'رقم قرار الازالة',
    'الرقم القضائي',
    'اسم المخالف',
    'الرقم القومي',
    'المصرف',
    'نوع المخالفة',
    'المساحة (م2)',
    'اسم الملاحظ',
    'تاريخ الازالة',
    'قيمة المحضر',
    '+47%',
    'قيمة رد الشئ لأصلة',
    'قيمة مقابل الانتفاع',
    'الحجز الاداري',
    'التبديد',
    'قيمة الحجز الاداري',
    'موقف المحضر',
    'اجمالي المستحقات',
    'الموقف من السداد',
    'ما تم سداده',
  ];

  // ════════════════════════════════════════════════════════════
  // مجلد الحفظ
  // ════════════════════════════════════════════════════════════
  static Future<String> _getSaveFolder() async {
    try {
      if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'];
        if (home != null) return p.join(home, 'Documents');
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) return p.join(home, 'Documents');
      }
    } catch (_) {}
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static String _ts() =>
      DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());

  // ════════════════════════════════════════════════════════════
  // EXCEL
  // ════════════════════════════════════════════════════════════
  static Future<bool> exportToExcel({
    required BuildContext context,
    required List<Map<String, dynamic>> cases,
    required String statementTitle,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // ديباجة
      _cell(sheet, 0, 0, 'جمهورية مصر العربية',
          bold: true, fontSize: 14);
      _cell(sheet, 0, 12, 'وزارة الري والموارد المائية',
          bold: true, fontSize: 12);
      _cell(sheet, 1, 0, 'الهيئة العامة لمشروعات الصرف',
          bold: true, fontSize: 12);
      _cell(sheet, 3, 0, 'هندسة صرف الفشن', bold: true, fontSize: 12);
      _cell(sheet, 4, 0, statementTitle, bold: true, fontSize: 13);
      _cell(sheet, 5, 0,
          'التاريخ: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}');

      // رؤوس الأعمدة (الصف 8)
      for (int col = 0; col < _columnHeaders.length; col++) {
        _cell(
          sheet, 8, col, _columnHeaders[col],
          bold: true,
          bg: ExcelColor.fromInt(0xFF05352D),
          fg: ExcelColor.white,
        );
      }

      // البيانات
      for (int i = 0; i < cases.length; i++) {
        final c = cases[i];
        final rowData = [
          i + 1,
          c['report_number']?.toString() ?? '',
          c['report_year']?.toString() ?? '',
          c['report_date']?.toString() ?? '',
          c['removal_decision_number']?.toString() ?? '',
          c['judicial_number']?.toString() ?? '',
          c['offender_name']?.toString() ?? '',
          c['offender_national_id']?.toString() ?? '',
          c['drain_name']?.toString() ?? '',
          c['violation_type']?.toString() ?? '',
          c['area']?.toString() ?? '',
          c['observer_name']?.toString() ?? '',
          c['removal_date']?.toString() ?? '',
          c['report_value']?.toString() ?? '',
          c['percent_47_value']?.toString() ?? '',
          c['restoration_value']?.toString() ?? '',
          c['usufruct_value']?.toString() ?? '',
          c['admin_seizure_status']?.toString() ?? '',
          c['dissipation_status']?.toString() ?? '',
          c['admin_seizure_value']?.toString() ?? '',
          c['case_status']?.toString() ?? '',
          c['total_dues']?.toString() ?? '',
          c['payment_status']?.toString() ?? '',
          c['paid_amount']?.toString() ?? '',
        ];
        for (int col = 0; col < rowData.length; col++) {
          _cell(
            sheet, 9 + i, col, rowData[col],
            bg: i.isEven
                ? ExcelColor.fromInt(0xFFF5F2EA)
                : ExcelColor.white,
          );
        }
      }

      // صندوق التوقيع
      final sig = 11 + cases.length;
      _cell(sheet, sig, 0, 'مدير هندسة صرف الفشن', bold: true);
      _cell(sheet, sig + 1, 0, 'م / ');
      _cell(sheet, sig + 2, 0, 'التوقيع: _______________');
      _cell(sheet, sig + 3, 0, 'التاريخ:  _______________');

      // عرض الأعمدة
      final widths = [
        4, 8, 8, 12, 12, 12, 20, 16, 16, 16,
        8, 14, 12, 10, 8, 14, 14, 12, 12, 12,
        14, 12, 14, 12,
      ];
      for (int i = 0; i < widths.length; i++) {
        sheet.setColumnWidth(i, widths[i].toDouble());
      }

      final bytes = excel.encode();
      if (bytes == null) return false;

      final folder = await _getSaveFolder();
      final path = p.join(folder, 'محاضر_الفشن_${_ts()}.xlsx');
      await File(path).writeAsBytes(bytes);
      _ok(context, path);
      return true;
    } catch (e) {
      _err(context, 'Excel: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════
  // PDF
  // ════════════════════════════════════════════════════════════
  static Future<bool> exportToPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> cases,
    required String statementTitle,
  }) async {
    try {
      // تحميل الخط من Google (يعمل offline بعد أول تحميل)
      final regular = await PdfGoogleFonts.cairoRegular();
      final bold = await PdfGoogleFonts.cairoBold();

      final base = pw.TextStyle(font: regular, fontSize: 9);
      final hdr = pw.TextStyle(
          font: bold, fontSize: 9, color: PdfColors.white);
      final title = pw.TextStyle(font: bold, fontSize: 13);

      final doc = pw.Document();

      final pdfCols = [
        'م', 'رقم المحضر', 'سنة المحضر', 'اسم المخالف',
        'المصرف', 'نوع المخالفة', 'المساحة', 'موقف المحضر',
      ];

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('هندسة صرف الفشن — إدارة المخالفات',
                style: title,
                textDirection: pw.TextDirection.rtl,),
            pw.SizedBox(height: 4),
            pw.Text(statementTitle,
                style: pw.TextStyle(font: bold, fontSize: 11),
                textDirection: pw.TextDirection.rtl,),
            pw.Text(
                'تاريخ التقرير: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                style: pw.TextStyle(font: regular, fontSize: 10),
                textDirection: pw.TextDirection.rtl,),
            pw.Divider(),
          ],
        ),
        footer: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                    style: base),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('مدير هندسة صرف الفشن  م / ___________',
                        style: pw.TextStyle(font: bold, fontSize: 10),
                        textDirection: pw.TextDirection.rtl,),
                    pw.Text('التوقيع: ___________________________',
                        style: base,
                        textDirection: pw.TextDirection.rtl,),
                  ],
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: pdfCols,
            headerStyle: hdr,
            headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF05352D)),
            cellStyle: base,
            cellAlignment: pw.Alignment.center,
            oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF5F2EA)),
            data: [
              for (int i = 0; i < cases.length; i++)
                [
                  '${i + 1}',
                  cases[i]['report_number']?.toString() ?? '',
                  cases[i]['report_year']?.toString() ?? '',
                  cases[i]['offender_name']?.toString() ?? '',
                  cases[i]['drain_name']?.toString() ?? '',
                  cases[i]['violation_type']?.toString() ?? '',
                  cases[i]['area']?.toString() ?? '',
                  cases[i]['case_status']?.toString() ?? '',
                ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'إجمالي المحاضر: ${cases.length}',
              style: pw.TextStyle(font: bold, fontSize: 11),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ));

      final folder = await _getSaveFolder();
      final path = p.join(folder, 'محاضر_الفشن_${_ts()}.pdf');
      final bytes = await doc.save();
      await File(path).writeAsBytes(bytes);
      _ok(context, path);
      return true;
    } catch (e) {
      _err(context, 'PDF: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════
  // WORD (RTF)
  // ════════════════════════════════════════════════════════════
  static Future<bool> exportToWord({
    required BuildContext context,
    required List<Map<String, dynamic>> cases,
    required String statementTitle,
  }) async {
    try {
      final buf = StringBuffer();
      buf.write(r'{\rtf1\ansi\ansicpg1256\deff0');
      buf.write(r'{\fonttbl{\f0\froman\fcharset178 Times New Roman;}}');
      buf.write(r'{\colortbl ;\red5\green53\blue45;\red255\green255\blue255;\red245\green242\blue234;}');
      buf.write(r'\widowctrl\wpaper12240\wpapr9180\viewkind4\uc1 ');
      buf.write(r'\pard\rtlpar\qc\sb120\sa120 ');

      // العنوان
      buf.write(r'\f0\fs28\b ');
      buf.write(_rtf('هندسة صرف الفشن — إدارة المخالفات'));
      buf.write(r'\b0\par ');
      buf.write(r'\fs24\b ');
      buf.write(_rtf(statementTitle));
      buf.write(r'\b0\par ');
      buf.write(r'\fs20 ');
      buf.write(_rtf(
          'تاريخ التقرير: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}'));
      buf.write(r'\par\par ');

      // أعمدة مختصرة
      final cols = [
        'م', 'رقم المحضر', 'سنة المحضر', 'اسم المخالف',
        'المصرف', 'نوع المخالفة', 'المساحة', 'موقف المحضر', 'الإجمالي',
      ];
      const cw = 1100;

      // صف الرأس
      buf.write(r'\trowd\trgaph60\trrh-380');
      for (int i = 0; i < cols.length; i++) {
        buf.write('\\cellx${(i + 1) * cw}');
      }
      for (final col in cols) {
        buf.write(r'\pard\rtlpar\intbl\qc\b\fs18\cf2\cb1 ');
        buf.write(_rtf(col));
        buf.write(r'\b0\cell ');
      }
      buf.write(r'\row ');

      // صفوف البيانات
      for (int i = 0; i < cases.length; i++) {
        final c = cases[i];
        buf.write(r'\trowd\trgaph60\trrh-320');
        for (int j = 0; j < cols.length; j++) {
          buf.write('\\cellx${(j + 1) * cw}');
        }
        final color = i.isEven ? r'\cb3' : r'\cb0';
        final rowData = [
          '${i + 1}',
          c['report_number']?.toString() ?? '',
          c['report_year']?.toString() ?? '',
          c['offender_name']?.toString() ?? '',
          c['drain_name']?.toString() ?? '',
          c['violation_type']?.toString() ?? '',
          c['area']?.toString() ?? '',
          c['case_status']?.toString() ?? '',
          c['total_dues']?.toString() ?? '',
        ];
        for (final v in rowData) {
          buf.write(r'\pard\rtlpar\intbl\qc\fs16' + color + r'\cf0 ');
          buf.write(_rtf(v));
          buf.write(r'\cell ');
        }
        buf.write(r'\row ');
      }

      // إجمالي + توقيع
      buf.write(r'\pard\rtlpar\qr\sb300\b\fs22 ');
      buf.write(_rtf('إجمالي المحاضر: ${cases.length}'));
      buf.write(r'\b0\par\par ');
      buf.write(r'\pard\rtlpar\ql\sb200\b\fs22 ');
      buf.write(_rtf('مدير هندسة صرف الفشن'));
      buf.write(r'\b0\par\fs20 ');
      buf.write(_rtf('م / ___________________________'));
      buf.write(r'\par ');
      buf.write(_rtf('التوقيع: ___________________________'));
      buf.write(r'\par ');
      buf.write(_rtf('التاريخ:  ___________________________'));
      buf.write(r'}');

      final folder = await _getSaveFolder();
      final path = p.join(folder, 'محاضر_الفشن_${_ts()}.rtf');
      // نكتب بترميز latin1 بعد تحويل النص لـ RTF Unicode escapes
      await File(path).writeAsBytes(latin1.encode(buf.toString()));
      _ok(context, '$path\n(افتحه بـ Microsoft Word)');
      return true;
    } catch (e) {
      _err(context, 'Word: $e');
      return false;
    }
  }

  /// تحويل نص عربي إلى RTF Unicode escapes
  static String _rtf(String text) {
    final buf = StringBuffer();
    for (final cp in text.runes) {
      if (cp > 127) {
        // RTF Unicode: \uN? حيث N هو الكود بالعلامة إذا لزم
        final signed = cp > 32767 ? cp - 65536 : cp;
        buf.write('\\\\u$signed?');
      } else {
        buf.writeCharCode(cp);
      }
    }
    return buf.toString();
  }

  // ════════════════════════════════════════════════════════════
  // مساعد Excel — _cell
  // ════════════════════════════════════════════════════════════
  static void _cell(
    Sheet sheet,
    int row,
    int col,
    dynamic value, {
    bool bold = false,
    double fontSize = 11,
    ExcelColor? bg,
    ExcelColor? fg,
  }) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

    if (value is int) {
      cell.value = IntCellValue(value);
    } else if (value is double) {
      cell.value = DoubleCellValue(value);
    } else {
      cell.value = TextCellValue(value.toString());
    }

    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: fontSize.toInt(),
      fontColorHex: fg ?? ExcelColor.black,
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
  }

  // ════════════════════════════════════════════════════════════
  // رسائل نتيجة
  // ════════════════════════════════════════════════════════════
  static void _ok(BuildContext context, String path) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text('تم الحفظ:\n$path', textDirection: ui.TextDirection.rtl),
      backgroundColor: const Color(0xFF0B6B55),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 7),
    ));
  }

  static void _err(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('خطأ: $msg', textDirection: ui.TextDirection.rtl),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 7),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // نافذة حوار التصدير
  // ════════════════════════════════════════════════════════════
  static Future<void> showExportDialog({
    required BuildContext context,
    required List<Map<String, dynamic>> cases,
  }) async {
    String title = '';
    String? type;

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download_outlined, color: Color(0xFF05352D)),
              SizedBox(width: 10),
              Text('تصدير المحاضر',
                  style: TextStyle(
                      color: Color(0xFF05352D),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عدد المحاضر: ${cases.length}',
                    style: const TextStyle(color: Color(0xFF4F5B57))),
                const SizedBox(height: 14),
                const Text('عنوان البيان:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(
                    hintText: 'أدخل عنوان البيان...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => title = v,
                ),
                const SizedBox(height: 14),
                const Text('نوع الملف:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StatefulBuilder(builder: (ctx2, setState) {
                  return Column(children: [
                    _TypeCard(
                      icon: Icons.table_chart,
                      label: 'Excel (.xlsx)',
                      sub: 'جدول بتنسيق الملف الرسمي',
                      color: const Color(0xFF1D6F42),
                      selected: type == 'excel',
                      onTap: () => setState(() => type = 'excel'),
                    ),
                    const SizedBox(height: 8),
                    _TypeCard(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF (.pdf)',
                      sub: 'للطباعة والمشاركة',
                      color: const Color(0xFFB42318),
                      selected: type == 'pdf',
                      onTap: () => setState(() => type = 'pdf'),
                    ),
                    const SizedBox(height: 8),
                    _TypeCard(
                      icon: Icons.description_outlined,
                      label: 'Word (.rtf)',
                      sub: 'يُفتح في Microsoft Word',
                      color: const Color(0xFF2B5796),
                      selected: type == 'word',
                      onTap: () => setState(() => type = 'word'),
                    ),
                  ]);
                }),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F2EA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFE5DCC8)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.folder_outlined,
                        size: 16, color: Color(0xFF4F5B57)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يُحفظ الملف تلقائياً في مجلد Documents',
                        style: TextStyle(
                            color: Color(0xFF4F5B57),
                            fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF05352D)),
              onPressed: type == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _run(
                        context: context,
                        cases: cases,
                        type: type!,
                        title: title.isEmpty
                            ? 'كشف المحاضر الجنائية'
                            : title,
                      );
                    },
              icon: const Icon(Icons.download),
              label: const Text('تصدير'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _run({
    required BuildContext context,
    required List<Map<String, dynamic>> cases,
    required String type,
    required String title,
  }) async {
    switch (type) {
      case 'excel':
        await exportToExcel(
            context: context, cases: cases, statementTitle: title);
        break;
      case 'pdf':
        await exportToPdf(
            context: context, cases: cases, statementTitle: title);
        break;
      case 'word':
        await exportToWord(
            context: context, cases: cases, statementTitle: title);
        break;
    }
  }
}

// ── بطاقة نوع الملف ─────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5DCC8),
            width: selected ? 2 : 1,
          ),
          color:
              selected ? color.withValues(alpha: 0.08) : Colors.white,
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected ? color : null)),
                Text(sub,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, color: color, size: 20),
        ]),
      ),
    );
  }
}
