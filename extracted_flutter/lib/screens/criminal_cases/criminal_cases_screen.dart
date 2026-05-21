import 'dart:async';

import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../../models/case_filter.dart';
import '../../services/export_service.dart';
import '../violation_sheet/violation_sheet_screen.dart';

class CriminalCasesScreen extends StatefulWidget {
  const CriminalCasesScreen({super.key, this.currentUser});

  final Map<String, dynamic>? currentUser;

  @override
  State<CriminalCasesScreen> createState() => _CriminalCasesScreenState();
}

class _CriminalCasesScreenState extends State<CriminalCasesScreen> {
  final searchController = TextEditingController();
  Timer? searchTimer;

  List<Map<String, dynamic>> cases = [];
  Map<String, List<Map<String, dynamic>>> filterOptions = {};
  CaseFilter activeFilter = CaseFilter();
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    if (mounted) setState(() { loading = true; loadError = null; });
    try {
      final loadedOptions = await DatabaseService.getFilterOptions();
      final loadedCases  = await DatabaseService.getCases(filter: activeFilter);
      if (!mounted) return;
      setState(() {
        filterOptions = loadedOptions;
        cases         = loadedCases;
        loading       = false;
        loadError     = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading   = false;
        loadError = e.toString();
      });
    }
  }

  Future<void> loadCases() async {
    setState(() { loading = true; loadError = null; });
    try {
      final data = await DatabaseService.getCases(
        search: searchController.text,
        filter: activeFilter,
      );
      if (!mounted) return;
      setState(() {
        cases     = data;
        loading   = false;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading   = false;
        loadError = e.toString();
      });
    }
  }

  void onSearchChanged(String value) {
    searchTimer?.cancel();
    searchTimer = Timer(const Duration(milliseconds: 350), loadCases);
  }

  Future<void> openAdvancedFilters() async {
    final result = await showDialog<CaseFilter>(
      context: context,
      builder: (context) => AdvancedFiltersDialog(
        initialFilter: activeFilter,
        filterOptions: filterOptions,
      ),
    );
    if (result == null) return;
    setState(() => activeFilter = result);
    await loadCases();
  }

  Future<void> openAddSheet() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ViolationSheetScreen(
          mode: ViewMode.add,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (saved == true) await loadCases();
  }

  Future<void> openViewSheet(Map<String, dynamic> item) async {
    final needsRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ViolationSheetScreen(
          mode: ViewMode.view,
          caseData: item,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (needsRefresh == true) await loadCases();
  }

  Future<void> openExportDialog() async {
    if (cases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد محاضر لتصديرها — يرجى تطبيق فلتر أولاً',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Color(0xFF0B6B55),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ExportService.showExportDialog(context: context, cases: cases);
  }

  Future<void> resetFilters() async {
    searchController.clear();
    setState(() => activeFilter = CaseFilter());
    await loadCases();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF05352D),
          foregroundColor: Colors.white,
          title: const Text(
            'المحاضر الجنائية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                onPressed: loading ? null : openExportDialog,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  cases.isEmpty ? 'تصدير' : 'تصدير (${cases.length})',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                onPressed: openAddSheet,
                icon: const Icon(Icons.add),
                label: const Text('تسجيل محضر جديد'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── داشبورد المحاضر الجنائية (4 بطاقات) ──────────
            _CasesStatBar(onRefresh: loadInitialData),
            Container(
              padding: const EdgeInsets.all(18),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        labelText:
                            'بحث بالاسم، رقم المحضر، الرقم القومي، المصرف أو نوع المخالفة',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed:
                        filterOptions.isEmpty ? null : openAdvancedFilters,
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: Text(
                      activeFilter.isEmpty
                          ? 'فلترة متقدمة'
                          : 'فلترة متقدمة (${activeFilter.activeCount})',
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed:
                        searchController.text.isEmpty && activeFilter.isEmpty
                        ? null
                        : resetFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة ضبط'),
                  ),
                ],
              ),
            ),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  Text(
                    loading
                        ? 'جاري التحميل...'
                        : 'عدد النتائج: ${cases.length}',
                    style: const TextStyle(
                      color: Color(0xFF05352D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (!activeFilter.isEmpty)
                    const Text(
                      'يوجد فلتر متقدم مفعل',
                      style: TextStyle(
                        color: Color(0xFF0B6B55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (loadError != null) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'خطأ: $loadError',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: loadInitialData,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 56),
                          const SizedBox(height: 16),
                          const Text(
                            'فشل تحميل المحاضر',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF05352D)),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05352D)),
                            onPressed: loadInitialData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : cases.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد نتائج',
                        style: TextStyle(
                          color: Color(0xFF05352D),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: cases.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = cases[index];
                        return _CaseTile(
                          item: item,
                          onTap: () => openViewSheet(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdvancedFiltersDialog extends StatefulWidget {
  const AdvancedFiltersDialog({
    super.key,
    required this.initialFilter,
    required this.filterOptions,
  });

  final CaseFilter initialFilter;
  final Map<String, List<Map<String, dynamic>>> filterOptions;

  @override
  State<AdvancedFiltersDialog> createState() => _AdvancedFiltersDialogState();
}

class _AdvancedFiltersDialogState extends State<AdvancedFiltersDialog> {
  late CaseFilter localFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    localFilter = widget.initialFilter.copy();
    _dateFrom = widget.initialFilter.dateFrom;
    _dateTo   = widget.initialFilter.dateTo;
  }

  CaseFilter _buildFilter() => localFilter.copyWith(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

  void _clearAll() {
    setState(() {
      localFilter.clear();
      _dateFrom = null;
      _dateTo   = null;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime(2020))
        : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2011),
      lastDate: DateTime(2030),
      helpText: isFrom ? 'من تاريخ' : 'إلى تاريخ',
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        // إذا كان "من" أكبر من "إلى" — أعد ضبط "إلى"
        if (_dateTo != null && _dateFrom!.isAfter(_dateTo!)) _dateTo = null;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateTo!.isBefore(_dateFrom!)) _dateFrom = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── رأس الحوار ───────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.filter_alt_outlined,
                      color: Color(0xFF0B6B55)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الفلترة المتقدمة',
                      style: TextStyle(
                        color: Color(0xFF05352D),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── محتوى الفلاتر ────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── فلتر السنة (2011-2026 دائماً) ─────────
                      _FilterSection(
                        title: 'سنة المحضر',
                        options: widget.filterOptions['years'] ?? const [],
                        selectedValues: localFilter.years,
                        onChanged: _toggle(localFilter.years),
                      ),

                      // ── فلتر فترة التاريخ ─────────────────────
                      _DateRangeSection(
                        dateFrom: _dateFrom,
                        dateTo: _dateTo,
                        fmtDate: _fmtDate,
                        onPickFrom: () => _pickDate(isFrom: true),
                        onPickTo: () => _pickDate(isFrom: false),
                        onClearFrom: () => setState(() => _dateFrom = null),
                        onClearTo: () => setState(() => _dateTo = null),
                      ),

                      // ── نوع المخالفة ───────────────────────────
                      _FilterSection(
                        title: 'نوع المخالفة',
                        options: widget.filterOptions['violation_types'] ??
                            const [],
                        selectedValues: localFilter.violationTypeIds,
                        onChanged: _toggle(localFilter.violationTypeIds),
                      ),

                      // ── المصرف ────────────────────────────────
                      _FilterSection(
                        title: 'المصرف',
                        options: widget.filterOptions['drains'] ?? const [],
                        selectedValues: localFilter.drainIds,
                        onChanged: _toggle(localFilter.drainIds),
                      ),

                      // ── اسم الملاحظ ───────────────────────────
                      _FilterSection(
                        title: 'اسم الملاحظ',
                        options: widget.filterOptions['observers'] ?? const [],
                        selectedValues: localFilter.observerIds,
                        onChanged: _toggle(localFilter.observerIds),
                      ),

                      // ── موقف المحضر ───────────────────────────
                      _FilterSection(
                        title: 'موقف المحضر',
                        options:
                            widget.filterOptions['case_statuses'] ?? const [],
                        selectedValues: localFilter.caseStatusIds,
                        onChanged: _toggle(localFilter.caseStatusIds),
                      ),

                      // ── الحجز الإداري ─────────────────────────
                      _FilterSection(
                        title: 'الحجز الإداري',
                        options: widget.filterOptions[
                                'admin_seizure_statuses'] ??
                            const [],
                        selectedValues: localFilter.adminSeizureStatusIds,
                        onChanged: _toggle(localFilter.adminSeizureStatusIds),
                      ),

                      // ── التبديد ───────────────────────────────
                      _FilterSection(
                        title: 'التبديد',
                        options:
                            widget.filterOptions['dissipation_statuses'] ??
                            const [],
                        selectedValues: localFilter.dissipationStatusIds,
                        onChanged: _toggle(localFilter.dissipationStatusIds),
                      ),

                      // ── الموقف من السداد ──────────────────────
                      _FilterSection(
                        title: 'الموقف من السداد',
                        options:
                            widget.filterOptions['payment_statuses'] ?? const [],
                        selectedValues: localFilter.paymentStatusIds,
                        onChanged: _toggle(localFilter.paymentStatusIds),
                      ),
                    ],
                  ),
                ),
              ),

              // ── أزرار الإجراءات ──────────────────────────────
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('مسح اختيارات الفلتر'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _buildFilter()),
                    icon: const Icon(Icons.check),
                    label: const Text('تطبيق الفلتر'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ValueChanged<int> _toggle(Set<int> values) {
    return (id) {
      setState(() {
        if (values.contains(id)) {
          values.remove(id);
        } else {
          values.add(id);
        }
      });
    };
  }
}

// ── ودجت فلتر فترة التاريخ ───────────────────────────────────────
class _DateRangeSection extends StatelessWidget {
  const _DateRangeSection({
    required this.dateFrom,
    required this.dateTo,
    required this.fmtDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFrom,
    required this.onClearTo,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String Function(DateTime) fmtDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تاريخ المحضر (فترة زمنية)',
            style: TextStyle(
              color: Color(0xFF05352D),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // ── من تاريخ ───────────────────────────────────
              _DatePickerChip(
                label: 'من',
                value: dateFrom != null ? fmtDate(dateFrom!) : null,
                icon: Icons.calendar_today_outlined,
                onTap: onPickFrom,
                onClear: dateFrom != null ? onClearFrom : null,
              ),

              const Icon(Icons.arrow_back, color: Color(0xFF0B6B55), size: 20),

              // ── إلى تاريخ ──────────────────────────────────
              _DatePickerChip(
                label: 'إلى',
                value: dateTo != null ? fmtDate(dateTo!) : null,
                icon: Icons.calendar_today_outlined,
                onTap: onPickTo,
                onClear: dateTo != null ? onClearTo : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePickerChip extends StatelessWidget {
  const _DatePickerChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue
              ? const Color(0xFFE5C07B).withValues(alpha: 0.35)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue
                ? const Color(0xFFE5C07B)
                : const Color(0xFFCCCCCC),
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF05352D)),
            const SizedBox(width: 6),
            Text(
              hasValue ? '$label: $value' : '$label: اختر تاريخ',
              style: TextStyle(
                color: hasValue
                    ? const Color(0xFF05352D)
                    : const Color(0xFF888888),
                fontWeight:
                    hasValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasValue && onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: Color(0xFF05352D)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  final String title;
  final List<Map<String, dynamic>> options;
  final Set<int> selectedValues;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF05352D),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (options.isEmpty)
            const Text('لا توجد اختيارات')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final id    = _intValue(option['id']);
                final name  = option['name']?.toString() ?? '-';
                if (id == null) return const SizedBox.shrink();
                return FilterChip(
                  label: Text(name),
                  selected: selectedValues.contains(id),
                  onSelected: (_) => onChanged(id),
                  selectedColor: const Color(0xFFE5C07B),
                  checkmarkColor: const Color(0xFF05352D),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reportNumber = item['report_number']?.toString() ?? '-';
    final reportYear   = item['report_year']?.toString() ?? '-';
    final offenderName = item['offender_name']?.toString() ?? 'بدون اسم';
    final drainName    = item['drain_name']?.toString() ?? '-';
    final violationType = item['violation_type']?.toString() ?? '-';
    final caseStatus   = item['case_status']?.toString() ?? '-';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5DCC8)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B6B55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gavel, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offenderName,
                      style: const TextStyle(
                        color: Color(0xFF05352D),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _InfoText('رقم المحضر', '$reportNumber / $reportYear'),
                        _InfoText('المصرف', drainName),
                        _InfoText('نوع المخالفة', violationType),
                        _InfoText('الموقف', caseStatus),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0B6B55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// شريط إحصائيات المحاضر الجنائية (يظهر في أعلى الصفحة)
// 4 بطاقات: الإجمالي = القائمة + رد الشئ + المزالة جبرياً
// ══════════════════════════════════════════════════════════════

class _CasesStatBar extends StatefulWidget {
  const _CasesStatBar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_CasesStatBar> createState() => _CasesStatBarState();
}

class _CasesStatBarState extends State<_CasesStatBar> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await DatabaseService.getDashboardStats();
      if (mounted) setState(() { _stats = s; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _val(String key) => _loading ? '...' : (_stats[key]?.toString() ?? '٠');

  @override
  Widget build(BuildContext context) {
    final total          = int.tryParse(_stats['total_cases']?.toString() ?? '0') ?? 0;
    final active         = int.tryParse(_stats['active_cases']?.toString() ?? '0') ?? 0;
    final restoration    = int.tryParse(_stats['restoration_cases']?.toString() ?? '0') ?? 0;
    final forciblyRemoved= int.tryParse(_stats['forcibly_removed_cases']?.toString() ?? '0') ?? 0;
    final otherCases     = total - active - restoration - forciblyRemoved;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF05352D),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // الإجمالي
          _MiniStatCard(
            title: 'إجمالي المحاضر',
            value: _val('total_cases'),
            icon: Icons.gavel,
            color: Colors.white,
            bgColor: Colors.white.withValues(alpha: 0.12),
            isTotal: true,
          ),
          const SizedBox(width: 1),
          // فاصل مرئي يوضح أن الإجمالي = مجموع الثلاثة
          Container(
            width: 28,
            alignment: Alignment.center,
            child: const Text(
              '=',
              style: TextStyle(
                color: Color(0xFFE5C07B),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 1),
          // القائمة
          _MiniStatCard(
            title: 'المحاضر القائمة',
            value: _loading ? '...' : active.toString(),
            icon: Icons.hourglass_top_outlined,
            color: const Color(0xFF86EFAC),
            bgColor: const Color(0xFF16A34A).withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),
          // رد الشئ لأصله
          _MiniStatCard(
            title: 'رد الشئ لأصله',
            value: _loading ? '...' : restoration.toString(),
            icon: Icons.restore,
            color: const Color(0xFF93C5FD),
            bgColor: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),
          // مزالة جبرياً
          _MiniStatCard(
            title: 'مزالة جبرياً',
            value: _loading ? '...' : forciblyRemoved.toString(),
            icon: Icons.cleaning_services_outlined,
            color: const Color(0xFFFCA5A5),
            bgColor: const Color(0xFFB91C1C).withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),
          // غير مصنّفة (الباقي)
          if (!_loading && otherCases > 0)
            _MiniStatCard(
              title: 'غير مصنّفة',
              value: otherCases.toString(),
              icon: Icons.help_outline,
              color: const Color(0xFFD4D4D4),
              bgColor: Colors.white.withValues(alpha: 0.08),
            ),
          const Spacer(),
          // زر تحديث
          IconButton(
            tooltip: 'تحديث الإحصائيات',
            onPressed: () { _load(); widget.onRefresh(); },
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isTotal = false,
  });

  final String   title;
  final String   value;
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  final bool     isTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isTotal
            ? Border.all(color: const Color(0xFFE5C07B).withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isTotal ? 22 : 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: isTotal ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: color.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
