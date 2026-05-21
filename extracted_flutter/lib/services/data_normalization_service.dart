// ============================================================
// data_normalization_service.dart
// خدمة تنظيف البيانات ودمج المحاضر المكررة
// ضعه في: lib/services/data_normalization_service.dart
// ============================================================

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NormalizationReport {
  final List<MergableGroup> mergableGroups;
  final List<DrainMapping> drainMappings;
  final List<NameFix> nameFixes;

  const NormalizationReport({
    required this.mergableGroups,
    required this.drainMappings,
    required this.nameFixes,
  });

  int get totalMerges => mergableGroups.length;
  int get totalDrainFixes => drainMappings.where((d) => d.suggestedId != d.currentId).length;
  int get totalNameFixes => nameFixes.length;

  bool get isEmpty => totalMerges == 0 && totalDrainFixes == 0 && totalNameFixes == 0;
}

class MergableGroup {
  final int reportNumber;
  final int reportYear;
  final List<Map<String, dynamic>> cases;
  final String combinedViolationType;

  const MergableGroup({
    required this.reportNumber,
    required this.reportYear,
    required this.cases,
    required this.combinedViolationType,
  });
}

class DrainMapping {
  final int caseId;
  final int? currentId;
  final String currentName;
  final int? suggestedId;
  final String suggestedName;

  const DrainMapping({
    required this.caseId,
    required this.currentId,
    required this.currentName,
    required this.suggestedId,
    required this.suggestedName,
  });
}

class NameFix {
  final int caseId;
  final String field;
  final String originalValue;
  final String normalizedValue;

  const NameFix({
    required this.caseId,
    required this.field,
    required this.originalValue,
    required this.normalizedValue,
  });
}

class DataNormalizationService {
  // ── تطبيع النص العربي ────────────────────────────────────────
  static String normalizeArabic(String text) {
    if (text.isEmpty) return text;
    String s = text.trim();

    // توحيد الهمزات
    s = s.replaceAll('أ', 'ا');
    s = s.replaceAll('إ', 'ا');
    s = s.replaceAll('آ', 'ا');
    s = s.replaceAll('ٱ', 'ا');

    // توحيد التاء المربوطة والهاء في نهاية الكلمة
    // (نُبقي على الفرق إذا كانت في منتصف الكلمة)
    s = s.replaceAllMapped(RegExp(r'ه(\s|$)'), (m) => 'ة${m.group(1)}');

    // توحيد الياء
    s = s.replaceAll('ى', 'ي');

    // إزالة التشكيل
    s = s.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F]'), '');

    // إزالة المسافات المتكررة
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  // ── حساب مسافة ليفنشتاين ─────────────────────────────────────
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  // ── إيجاد أفضل تطابق للمصرف ──────────────────────────────────
  static Map<String, dynamic>? findBestDrainMatch(
    String inputName,
    List<Map<String, dynamic>> canonicalDrains,
  ) {
    if (inputName.isEmpty || canonicalDrains.isEmpty) return null;

    final normalizedInput = normalizeArabic(inputName);
    final inputNoSpace = normalizedInput.replaceAll(' ', '');

    Map<String, dynamic>? bestMatch;
    int bestDistance = 999;

    for (final drain in canonicalDrains) {
      final canonicalName = drain['name']?.toString() ?? '';
      if (canonicalName.isEmpty) continue;

      final normalizedCanonical = normalizeArabic(canonicalName);
      final canonicalNoSpace = normalizedCanonical.replaceAll(' ', '');

      // تطابق تام بعد التطبيع
      if (normalizedInput == normalizedCanonical || inputNoSpace == canonicalNoSpace) {
        return drain;
      }

      final distance = _levenshtein(normalizedInput, normalizedCanonical);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = drain;
      }
    }

    // قبول التطابق فقط إذا كانت نسبة التشابه مقبولة (خطأ < 30%)
    final maxAllowed = (normalizedInput.length * 0.3).ceil();
    if (bestDistance <= maxAllowed && bestDistance <= 3) {
      return bestMatch;
    }

    return null;
  }

  // ── دمج نوع المخالفة ─────────────────────────────────────────
  static String combineViolationTypes(List<String?> types) {
    final unique = <String>{};
    for (final t in types) {
      if (t != null && t.isNotEmpty) {
        // إذا كان النوع يحتوي بالفعل على " + "، نفصله أولاً
        for (final part in t.split(RegExp(r'\s*\+\s*'))) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) unique.add(trimmed);
        }
      }
    }
    return unique.join(' + ');
  }

  // ── تحليل قاعدة البيانات وإنشاء تقرير التطبيع ────────────────
  static Future<NormalizationReport> analyze(Database db) async {
    final mergableGroups = <MergableGroup>[];
    final drainMappings = <DrainMapping>[];
    final nameFixes = <NameFix>[];

    // ── 1. إيجاد المحاضر المكررة ─────────────────────────────
    final duplicateRows = await db.rawQuery('''
      SELECT report_number, report_year, COUNT(*) as cnt
      FROM violation_cases
      WHERE report_number IS NOT NULL AND report_year IS NOT NULL
      GROUP BY report_number, report_year
      HAVING COUNT(*) > 1
      ORDER BY report_year DESC, report_number DESC
    ''');

    for (final dup in duplicateRows) {
      final reportNumber = dup['report_number'] as int;
      final reportYear = dup['report_year'] as int;

      final cases = await db.rawQuery('''
        SELECT vc.*, vt.name AS violation_type_name, d.name AS drain_name_db
        FROM violation_cases vc
        LEFT JOIN violation_types vt ON vt.id = vc.violation_type_id
        LEFT JOIN drains d ON d.id = vc.drain_id
        WHERE vc.report_number = ? AND vc.report_year = ?
        ORDER BY vc.id ASC
      ''', [reportNumber, reportYear]);

      final vtypes = cases.map((c) => c['violation_type_name']?.toString()).toList();
      final combined = combineViolationTypes(vtypes);

      mergableGroups.add(MergableGroup(
        reportNumber: reportNumber,
        reportYear: reportYear,
        cases: cases.map((r) => Map<String, dynamic>.from(r)).toList(),
        combinedViolationType: combined,
      ));
    }

    // ── 2. تحليل أسماء المصارف ───────────────────────────────
    final canonicalDrains = await db.rawQuery(
      'SELECT id, name FROM drains WHERE is_active = 1 ORDER BY name',
    );

    final casesWithDrains = await db.rawQuery('''
      SELECT vc.id, vc.drain_id, d.name AS current_drain_name
      FROM violation_cases vc
      LEFT JOIN drains d ON d.id = vc.drain_id
      ORDER BY vc.id
    ''');

    // إيجاد المحاضر التي تملك مصارف غير موجودة أو بأسماء خاطئة
    final allCaseDrains = await db.rawQuery('''
      SELECT DISTINCT drain_id FROM violation_cases WHERE drain_id IS NOT NULL
    ''');

    for (final row in casesWithDrains) {
      final currentName = row['current_drain_name']?.toString() ?? '';
      if (currentName.isEmpty) continue;

      final normalizedCurrent = normalizeArabic(currentName);
      bool needsFix = false;

      for (final canonical in canonicalDrains) {
        final canonicalName = canonical['name']?.toString() ?? '';
        if (normalizeArabic(canonicalName) == normalizedCurrent) {
          // الاسم صحيح بعد التطبيع، لكن ربما يختلف في الكتابة
          if (canonicalName != currentName) {
            needsFix = true;
            drainMappings.add(DrainMapping(
              caseId: row['id'] as int,
              currentId: row['drain_id'] as int?,
              currentName: currentName,
              suggestedId: canonical['id'] as int?,
              suggestedName: canonicalName,
            ));
          }
          break;
        }
      }
    }

    // ── 3. تحليل أسماء المخالفين ─────────────────────────────
    final allCases = await db.rawQuery(
      'SELECT id, offender_name FROM violation_cases WHERE offender_name IS NOT NULL',
    );

    for (final c in allCases) {
      final original = c['offender_name']?.toString() ?? '';
      if (original.isEmpty) continue;

      final normalized = normalizeArabic(original);
      // تحقق من المسافات الزائدة أو اختلافات الهمزة
      if (normalized != original) {
        nameFixes.add(NameFix(
          caseId: c['id'] as int,
          field: 'offender_name',
          originalValue: original,
          normalizedValue: normalized,
        ));
      }
    }

    return NormalizationReport(
      mergableGroups: mergableGroups,
      drainMappings: drainMappings,
      nameFixes: nameFixes,
    );
  }

  // ── تطبيق دمج المحاضر المكررة ────────────────────────────────
  static Future<int> mergeDuplicateCases(Database db) async {
    int mergedCount = 0;

    // إيجاد جميع المجموعات المكررة
    final duplicateRows = await db.rawQuery('''
      SELECT report_number, report_year, COUNT(*) as cnt
      FROM violation_cases
      WHERE report_number IS NOT NULL AND report_year IS NOT NULL
      GROUP BY report_number, report_year
      HAVING COUNT(*) > 1
      ORDER BY report_year DESC, report_number DESC
    ''');

    await db.transaction((txn) async {
      for (final dup in duplicateRows) {
        final reportNumber = dup['report_number'];
        final reportYear = dup['report_year'];

        // جلب جميع السجلات المكررة
        final cases = await txn.rawQuery('''
          SELECT vc.*, vt.name AS vtype_name
          FROM violation_cases vc
          LEFT JOIN violation_types vt ON vt.id = vc.violation_type_id
          WHERE vc.report_number = ? AND vc.report_year = ?
          ORDER BY vc.id ASC
        ''', [reportNumber, reportYear]);

        if (cases.length < 2) continue;

        // اختيار السجل الأساسي (الأول / الأكثر اكتمالاً)
        final primary = cases.first;
        final primaryId = primary['id'] as int;

        // جمع أنواع المخالفات
        final vtypes = cases.map((c) => c['vtype_name']?.toString()).toList();
        final combinedTypeName = combineViolationTypes(vtypes);

        // إيجاد أو إنشاء نوع المخالفة المدمج
        int? combinedTypeId;
        if (combinedTypeName.isNotEmpty) {
          final existing = await txn.rawQuery(
            'SELECT id FROM violation_types WHERE name = ? LIMIT 1',
            [combinedTypeName],
          );

          if (existing.isNotEmpty) {
            combinedTypeId = existing.first['id'] as int;
          } else {
            combinedTypeId = await txn.insert('violation_types', {
              'name': combinedTypeName,
              'is_active': 1,
            });
          }
        }

        // تجميع أفضل البيانات من جميع السجلات
        final mergedData = Map<String, dynamic>.from(primary);

        for (final c in cases.skip(1)) {
          // ملء الحقول الفارغة من السجلات الأخرى
          for (final key in c.keys) {
            if (key == 'id' || key == 'vtype_name') continue;
            if (mergedData[key] == null && c[key] != null) {
              mergedData[key] = c[key];
            }
          }
        }

        // تحديث نوع المخالفة في السجل الأساسي
        if (combinedTypeId != null) {
          mergedData['violation_type_id'] = combinedTypeId;
        }
        mergedData.remove('vtype_name');
        mergedData.remove('id');

        // تحديث السجل الأساسي
        await txn.update(
          'violation_cases',
          mergedData,
          where: 'id = ?',
          whereArgs: [primaryId],
        );

        // حذف السجلات المكررة
        final duplicateIds = cases.skip(1).map((c) => c['id'] as int).toList();
        for (final dupId in duplicateIds) {
          await txn.delete(
            'violation_cases',
            where: 'id = ?',
            whereArgs: [dupId],
          );
        }

        mergedCount++;
      }
    });

    return mergedCount;
  }

  // ── تطبيع أسماء المصارف في قاعدة البيانات ───────────────────
  static Future<int> normalizeDrainNames(Database db) async {
    int fixedCount = 0;

    final canonicalDrains = await db.rawQuery(
      'SELECT id, name FROM drains WHERE is_active = 1 ORDER BY name',
    );

    if (canonicalDrains.isEmpty) return 0;

    final cases = await db.rawQuery('''
      SELECT vc.id, vc.drain_id, d.name AS drain_name
      FROM violation_cases vc
      LEFT JOIN drains d ON d.id = vc.drain_id
    ''');

    await db.transaction((txn) async {
      for (final c in cases) {
        final currentName = c['drain_name']?.toString() ?? '';
        if (currentName.isEmpty) continue;

        final normalizedCurrent = normalizeArabic(currentName);

        // ابحث عن تطابق تام بعد التطبيع
        Map<String, dynamic>? matchedDrain;
        for (final drain in canonicalDrains) {
          final canonicalName = drain['name']?.toString() ?? '';
          if (normalizeArabic(canonicalName) == normalizedCurrent) {
            if (canonicalName != currentName) {
              matchedDrain = drain;
            }
            break;
          }
        }

        if (matchedDrain != null) {
          await txn.update(
            'violation_cases',
            {'drain_id': matchedDrain['id']},
            where: 'id = ?',
            whereArgs: [c['id']],
          );
          fixedCount++;
        }
      }
    });

    return fixedCount;
  }

  // ── تطبيع أسماء المخالفين ────────────────────────────────────
  static Future<int> normalizeOffenderNames(Database db) async {
    int fixedCount = 0;

    final cases = await db.rawQuery(
      'SELECT id, offender_name FROM violation_cases WHERE offender_name IS NOT NULL',
    );

    await db.transaction((txn) async {
      for (final c in cases) {
        final original = c['offender_name']?.toString() ?? '';
        if (original.isEmpty) continue;

        final normalized = normalizeArabic(original);
        if (normalized != original) {
          await txn.update(
            'violation_cases',
            {'offender_name': normalized},
            where: 'id = ?',
            whereArgs: [c['id']],
          );
          fixedCount++;
        }
      }
    });

    return fixedCount;
  }

  // ── تطبيق جميع عمليات التطبيع دفعة واحدة ───────────────────
  static Future<Map<String, int>> applyAll(Database db) async {
    final merged = await mergeDuplicateCases(db);
    final drainFixed = await normalizeDrainNames(db);
    final nameFixed = await normalizeOffenderNames(db);

    return {
      'merged': merged,
      'drain_fixed': drainFixed,
      'name_fixed': nameFixed,
    };
  }
}
