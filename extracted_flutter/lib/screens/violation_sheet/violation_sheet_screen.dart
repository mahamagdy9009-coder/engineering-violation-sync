// ============================================================
// violation_sheet_screen.dart  (النسخة الكاملة مع المرفقات)
// ضعه في: lib/screens/violation_sheet/violation_sheet_screen.dart
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_service.dart';
import '../../services/attachment_service.dart';
import '../../widgets/sheet_field.dart';
import '../../widgets/usb_server_badge.dart';

enum ViewMode { view, add, edit }

// ── ألوان ────────────────────────────────────────────────────
const _kDark   = Color(0xFF05352D);
const _kMid    = Color(0xFF0B6B55);
const _kCream  = Color(0xFFF5F2EA);
const _kGold   = Color(0xFFE5C07B);
const _kRed    = Color(0xFFB42318);

// ─────────────────────────────────────────────────────────────
class ViolationSheetScreen extends StatefulWidget {
  final ViewMode mode;
  final Map<String, dynamic>? caseData;
  final Map<String, dynamic>? currentUser;

  const ViolationSheetScreen({
    super.key,
    required this.mode,
    this.caseData,
    this.currentUser,
  });

  @override
  State<ViolationSheetScreen> createState() => _ViolationSheetScreenState();
}

class _ViolationSheetScreenState extends State<ViolationSheetScreen> {
  final _formKey = GlobalKey<FormState>();
  late ViewMode _mode;
  bool _saving = false;

  // ── خيارات القوائم ───────────────────────────────────────
  List<Map<String, dynamic>> _years                = [];
  List<Map<String, dynamic>> _drains               = [];
  List<Map<String, dynamic>> _vTypes               = [];
  List<Map<String, dynamic>> _observers            = [];
  List<Map<String, dynamic>> _caseStatuses         = [];
  List<Map<String, dynamic>> _adminSeizureStatuses = [];
  List<Map<String, dynamic>> _dissipationStatuses  = [];
  List<Map<String, dynamic>> _paymentStatuses      = [];

  // ── قيم القوائم ──────────────────────────────────────────
  int? _drainId, _observerId, _caseStatusId;
  int? _adminSeizureStatusId, _dissipationStatusId, _paymentStatusId;
  // أنواع المخالفة المتعددة (قائمة من المعرّفات)
  List<int> _vTypeIds   = [];
  // سنة المحضر كقائمة منسدلة
  int? _reportYearVal;

  // ── Controllers ──────────────────────────────────────────
  final _offenderName    = TextEditingController();
  final _nationalId      = TextEditingController();
  final _reportNumber    = TextEditingController();
  final _reportYear      = TextEditingController(); // للعرض فقط في وضع View
  final _reportDate      = TextEditingController();
  final _removalDecision = TextEditingController();
  final _guarantorId     = TextEditingController();
  final _kilometer       = TextEditingController();
  final _area            = TextEditingController();
  final _observerName    = TextEditingController();
  final _caseStatusTxt   = TextEditingController();
  final _removalDate     = TextEditingController();
  final _adminSeizureTxt = TextEditingController();
  final _tanbidTxt       = TextEditingController();
  final _paymentTxt      = TextEditingController();
  final _dataSource      = TextEditingController();
  final _sourceRow       = TextEditingController();
  final _reportValue     = TextEditingController();
  final _percent47       = TextEditingController();
  final _restoration     = TextEditingController();
  final _usufruct        = TextEditingController();
  final _adminSeizureVal = TextEditingController();
  final _totalDues       = TextEditingController();
  final _paidAmount      = TextEditingController();
  final _notes           = TextEditingController();

  // ── المرفقات ─────────────────────────────────────────────
  List<AttachmentRecord> _attachments = [];
  StreamSubscription<AttachmentRecord>? _attachSub;
  bool _attachLoading = false;

  int? get _caseId => _toInt(widget.caseData?['id']);
  bool get _isView  => _mode == ViewMode.view;
  bool get _isManager {
    final r  = widget.currentUser?['role']?.toString() ?? '';
    final rc = widget.currentUser?['role_code']?.toString() ?? '';
    return r == 'manager' || rc == 'manager';
  }

  // ── سنوات افتراضية في حالة عدم وجود بيانات في قاعدة البيانات ──
  static List<Map<String, dynamic>> get _staticYears {
    final now = DateTime.now().year;
    return List.generate(
      now - 2010,
      (i) => {'id': 2011 + i, 'name': (2011 + i).toString()},
    );
  }

  List<Map<String, dynamic>> get _effectiveYears =>
      _years.isNotEmpty ? _years : _staticYears;

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _loadOptions();
    if (widget.caseData != null) _populate(widget.caseData!);
    if (_caseId != null)         _loadAttachments();
    _listenForNewAttachments();
  }

  // ── الاستماع للمرفقات الواردة من الموبايل في الوقت الفعلي ─
  void _listenForNewAttachments() {
    _attachSub = AttachmentService.instance.onNewAttachment.listen((rec) {
      if (rec.caseId == _caseId && mounted) {
        setState(() => _attachments.insert(0, rec));
        _showSnack('📎 وصل مرفق جديد: ${rec.typeLabel}', success: true);
      }
    });
  }

  void _populate(Map<String, dynamic> c) {
    _offenderName.text    = c['offender_name']?.toString() ?? '-';
    _nationalId.text      = c['offender_national_id']?.toString() ?? '-';
    _reportNumber.text    = c['report_number']?.toString() ?? '';
    _reportYear.text      = c['report_year']?.toString() ?? '';
    _reportYearVal        = _toInt(c['report_year']);
    _reportDate.text      = c['report_date']?.toString() ?? '-';
    _removalDecision.text = c['removal_decision_number']?.toString() ?? '-';
    _guarantorId.text     = c['guarantor_id']?.toString() ?? '-';
    _kilometer.text       = c['kilometer_location']?.toString() ?? '';
    _area.text            = c['area']?.toString() ?? '';
    _observerName.text    = c['observer_name']?.toString() ?? '-';
    _removalDate.text     = c['removal_date']?.toString() ?? '-';
    _dataSource.text      = c['source_sheet']?.toString() ?? '';
    _sourceRow.text       = c['source_row']?.toString() ?? '';
    _reportValue.text     = c['report_value']?.toString() ?? '0';
    _percent47.text       = c['percent_47_value']?.toString() ?? '0';
    _restoration.text     = c['restoration_value']?.toString() ?? '0';
    _usufruct.text        = c['usufruct_value']?.toString() ?? '0';
    _adminSeizureVal.text = c['admin_seizure_value']?.toString() ?? '0';
    _totalDues.text       = c['total_dues']?.toString() ?? '0';
    _paidAmount.text      = c['paid_amount']?.toString() ?? '0';
    _drainId              = _toInt(c['drain_id']);
    _observerId           = _toInt(c['observer_id']);
    _caseStatusId         = _toInt(c['case_status_id']);
    _adminSeizureStatusId = _toInt(c['admin_seizure_status_id']);
    _dissipationStatusId  = _toInt(c['dissipation_status_id']);
    _paymentStatusId      = _toInt(c['payment_status_id']);
    _caseStatusTxt.text   = c['case_status']?.toString() ?? '-';
    _adminSeizureTxt.text = c['admin_seizure_status']?.toString() ?? '-';
    _tanbidTxt.text       = c['dissipation_status']?.toString() ?? '-';
    _paymentTxt.text      = c['payment_status']?.toString() ?? '-';

    // ── تحميل أنواع المخالفة المتعددة ────────────────────
    final vtIdsStr = c['violation_type_ids']?.toString() ?? '';
    if (vtIdsStr.isNotEmpty) {
      _vTypeIds = vtIdsStr
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    } else {
      final single = _toInt(c['violation_type_id']);
      if (single != null) _vTypeIds = [single];
    }
  }

  Future<void> _loadOptions() async {
    try {
      final opts = await DatabaseService.getFilterOptions();
      if (!mounted) return;
      setState(() {
        _years                = List<Map<String,dynamic>>.from(opts['years'] ?? []);
        _drains               = List<Map<String,dynamic>>.from(opts['drains'] ?? []);
        _vTypes               = List<Map<String,dynamic>>.from(opts['violation_types'] ?? []);
        _observers            = List<Map<String,dynamic>>.from(opts['observers'] ?? []);
        _caseStatuses         = List<Map<String,dynamic>>.from(opts['case_statuses'] ?? []);
        _adminSeizureStatuses = List<Map<String,dynamic>>.from(opts['admin_seizure_statuses'] ?? []);
        _dissipationStatuses  = List<Map<String,dynamic>>.from(opts['dissipation_statuses'] ?? []);
        _paymentStatuses      = List<Map<String,dynamic>>.from(opts['payment_statuses'] ?? []);
      });
    } catch (_) {}
  }

  Future<void> _loadAttachments() async {
    if (_caseId == null) return;
    setState(() => _attachLoading = true);
    try {
      final list = await AttachmentService.instance.getForCase(_caseId!);
      if (mounted) setState(() => _attachments = list);
    } catch (_) {}
    if (mounted) setState(() => _attachLoading = false);
  }

  Future<void> _deleteAttachment(AttachmentRecord rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: Text('هل تريد حذف "${rec.fileName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (ok != true) return;
    await AttachmentService.instance.delete(rec);
    if (mounted) setState(() => _attachments.remove(rec));
    _showSnack('تم حذف المرفق', success: false);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final after = <String, dynamic>{
      'offender_name':           _offenderName.text.trim(),
      'offender_national_id':    _nationalId.text.trim(),
      'report_number':           int.tryParse(_reportNumber.text.trim()),
      'report_year':             _reportYearVal,
      'report_date':             _reportDate.text.trim(),
      'removal_decision_number': _removalDecision.text.trim(),
      'kilometer_location':      double.tryParse(_kilometer.text.trim()),
      'area':                    double.tryParse(_area.text.trim()),
      'drain_id':                _drainId,
      'violation_type_id':       _vTypeIds.isNotEmpty ? _vTypeIds.first : null,
      'violation_type_ids':      _vTypeIds.isEmpty ? null : _vTypeIds.join(','),
      'observer_id':             _observerId,
      'case_status_id':          _caseStatusId,
      'removal_date':            _removalDate.text.trim(),
      'admin_seizure_status_id': _adminSeizureStatusId,
      'dissipation_status_id':   _dissipationStatusId,
      'payment_status_id':       _paymentStatusId,
      'source_sheet':            _dataSource.text.trim(),
      'source_row':              int.tryParse(_sourceRow.text.trim()),
      'report_value':            double.tryParse(_reportValue.text.trim()),
      'percent_47_value':        double.tryParse(_percent47.text.trim()),
      'restoration_value':       double.tryParse(_restoration.text.trim()),
      'usufruct_value':          double.tryParse(_usufruct.text.trim()),
      'admin_seizure_value':     double.tryParse(_adminSeizureVal.text.trim()),
      'total_dues':              double.tryParse(_totalDues.text.trim()),
      'paid_amount':             double.tryParse(_paidAmount.text.trim()),
    };

    try {
      if (_isManager) {
        final db = await DatabaseService.database;
        if (_mode == ViewMode.add) {
          await db.insert('violation_cases', after);
        } else {
          if (_caseId != null) {
            await db.update('violation_cases', after,
                where: 'id = ?', whereArgs: [_caseId]);
          }
        }
        _showSnack('تم الحفظ بنجاح', success: true);
      } else {
        await DatabaseService.submitCaseChangeRequest(
          requestType: _mode == ViewMode.add ? 'add' : 'edit',
          targetId: _caseId,
          before: widget.caseData,
          after: after,
          requestedBy: _toInt(widget.currentUser?['id']),
        );
        _showSnack('تم إرسال الطلب للمدير', success: true);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showSnack('خطأ: $e', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textDirection: TextDirection.rtl),
      backgroundColor: success ? _kMid : _kRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _attachSub?.cancel();
    for (final c in [
      _offenderName, _nationalId, _reportNumber, _reportYear, _reportDate,
      _removalDecision, _guarantorId, _kilometer, _area, _observerName,
      _caseStatusTxt, _removalDate, _adminSeizureTxt, _tanbidTxt,
      _paymentTxt, _dataSource, _sourceRow, _reportValue, _percent47,
      _restoration, _usufruct, _adminSeizureVal, _totalDues, _paidAmount,
      _notes,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final title = _mode == ViewMode.add
        ? 'إضافة مخالفة جديدة'
        : 'صحيفة المخالف - ${_offenderName.text}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kCream,
        body: Column(
          children: [
            _buildHeader(title),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildBasicData(),
                      _buildProcedures(),
                      _buildFinancials(),
                      _buildAttachments(),
                      if (!_isView) _buildNotes(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── الهيدر ───────────────────────────────────────────────
  Widget _buildHeader(String title) {
    return Container(
      height: 52,
      color: _kDark,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // ── أزرار اليمين ─────────────────────────────────
          if (_isView) ...[
            const UsbServerBadge(),
            const SizedBox(width: 8),
            if (_isManager)
              _HBtn(label: 'تعديل', icon: Icons.edit, color: _kGold,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ViolationSheetScreen(
                      mode: ViewMode.edit,
                      caseData: widget.caseData,
                      currentUser: widget.currentUser,
                    )),
                  ))
            else
              _HBtn(label: 'تقديم تعديل للمدير', icon: Icons.edit_note,
                  color: _kGold,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ViolationSheetScreen(
                      mode: ViewMode.edit,
                      caseData: widget.caseData,
                      currentUser: widget.currentUser,
                    )),
                  )),
          ],
          if (!_isView) ...[
            _HBtn(label: 'إلغاء', icon: Icons.close,
                onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 8),
            _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : _HBtn(
                    label: _isManager ? 'حفظ' : 'إرسال للمدير',
                    icon: _isManager ? Icons.save : Icons.send,
                    color: _kGold, onTap: _submit),
          ],
          // ── العنوان ──────────────────────────────────────
          Expanded(
            child: Text(title,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // ── البيانات الأساسية ─────────────────────────────────────
  Widget _buildBasicData() {
    return SheetSectionCard(
      title: 'البيانات الأساسية', icon: Icons.person_outline,
      children: [
        _row([
          SheetTextField(label: 'اسم المخالف',   controller: _offenderName, readOnly: _isView, isRequired: true),
          SheetTextField(label: 'الرقم القومي',  controller: _nationalId,   readOnly: _isView,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          SheetTextField(label: 'رقم المحضر',   controller: _reportNumber,  readOnly: _isView,
              keyboardType: TextInputType.number, isRequired: true),
          // ── سنة المحضر: قائمة منسدلة في وضع التعديل ──────
          _isView
              ? SheetTextField(label: 'سنة المحضر', controller: _reportYear, readOnly: true)
              : _yearDropdown(),
          SheetDateField(label: 'تاريخ المحضر',  controller: _reportDate,    readOnly: _isView),
          SheetTextField(label: 'رقم قرار الإزالة', controller: _removalDecision, readOnly: _isView),
        ]),
        const SizedBox(height: 10),
        _row([
          SheetTextField(label: 'الرقم الضامن',  controller: _guarantorId,  readOnly: _isView),
          _ddOrText('اسم المصرف',      _drains,               _drainId,            (v) => setState(() => _drainId = v),            isRequired: true),
          SheetTextField(label: 'الموقع الكيلومتري', controller: _kilometer, readOnly: _isView,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          SheetTextField(label: 'المساحة',       controller: _area,         readOnly: _isView,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          _isView
              ? SheetTextField(label: 'اسم الملاحظ', controller: _observerName, readOnly: true)
              : SheetDropdownField<int>(
                  label: 'اسم الملاحظ', readOnly: false,
                  value: _observers.any((o) => o['id'] == _observerId) ? _observerId : null,
                  onChanged: (v) => setState(() => _observerId = v),
                  items: _observers.map((o) => DropdownMenuItem<int>(
                    value: o['id'] as int?, child: Text(o['name']?.toString() ?? ''))).toList()),
          const SizedBox(), // خانة فارغة للمحاذاة
        ]),
        const SizedBox(height: 10),
        // ── قسم أنواع المخالفة المتعددة ──────────────────────
        _buildViolationSection(),
      ],
    );
  }

  // ── قائمة منسدلة لسنة المحضر ─────────────────────────────
  Widget _yearDropdown() {
    final years = _effectiveYears;
    final validVal = years.any((y) => y['id'] == _reportYearVal)
        ? _reportYearVal
        : null;
    return SheetDropdownField<int>(
      label: 'سنة المحضر',
      readOnly: false,
      value: validVal,
      onChanged: (v) => setState(() {
        _reportYearVal = v;
        _reportYear.text = v?.toString() ?? '';
      }),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('غير محدد')),
        ...years.map((y) => DropdownMenuItem<int>(
          value: y['id'] as int?,
          child: Text(y['name']?.toString() ?? '',
              textDirection: TextDirection.rtl),
        )),
      ],
    );
  }

  // ── قسم أنواع المخالفة المتعددة ──────────────────────────
  Widget _buildViolationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isView
            ? const Color(0xFFDDD8CC)
            : const Color(0xFF0B6B55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── عنوان + زر الإضافة ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!_isView)
                InkWell(
                  onTap: _showAddViolationType,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kMid.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kMid),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: _kMid),
                        SizedBox(width: 4),
                        Text('إضافة مخالفة',
                            style: TextStyle(
                                fontSize: 12,
                                color: _kMid,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('أنواع المخالفة',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kDark),
                      textDirection: TextDirection.rtl),
                  SizedBox(width: 6),
                  Icon(Icons.rule_outlined, size: 16, color: _kMid),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── قائمة المخالفات المختارة ──────────────────────
          if (_vTypeIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _isView ? 'لا توجد مخالفة مسجلة' : 'اضغط + إضافة مخالفة لتسجيل المخالفة',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF)),
                textDirection: TextDirection.rtl,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _vTypeIds.map((id) {
                final name = _vTypes
                    .where((v) => v['id'] == id)
                    .map((v) => v['name']?.toString() ?? '')
                    .firstOrNull ?? 'مخالفة #$id';
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kDark.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kDark.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isView)
                        InkWell(
                          onTap: () =>
                              setState(() => _vTypeIds.remove(id)),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close,
                                size: 14, color: _kRed),
                          ),
                        ),
                      if (!_isView) const SizedBox(width: 4),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kDark,
                              fontWeight: FontWeight.w500),
                          textDirection: TextDirection.rtl),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── نافذة إضافة نوع مخالفة جديد ─────────────────────────
  void _showAddViolationType() {
    if (_vTypes.isEmpty) {
      _showSnack('جاري تحميل قائمة أنواع المخالفة...', success: false);
      return;
    }
    // الأنواع غير المضافة مسبقاً
    final available = _vTypes
        .where((t) => !_vTypeIds.contains(t['id']))
        .toList();
    if (available.isEmpty) {
      _showSnack('تمت إضافة جميع أنواع المخالفة المتاحة', success: false);
      return;
    }

    int? selectedId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.rule_outlined, color: _kMid),
                SizedBox(width: 8),
                Text('اختر نوع المخالفة',
                    style: TextStyle(
                        color: _kDark, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                hint: const Text('اختر من القائمة'),
                value: selectedId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'نوع المخالفة',
                ),
                items: available.map((t) => DropdownMenuItem<int>(
                  value: t['id'] as int?,
                  child: Text(
                    t['name']?.toString() ?? '',
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: (v) => setDlgState(() => selectedId = v),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _kMid),
                onPressed: selectedId == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        setState(() => _vTypeIds.add(selectedId!));
                      },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── الموقف والإجراءات ─────────────────────────────────────
  Widget _buildProcedures() {
    return SheetSectionCard(
      title: 'الموقف والإجراءات', icon: Icons.assignment_outlined,
      children: [
        _row([
          _ddOrTextCtrl('موقف المحضر',       _caseStatuses,        _caseStatusId,         _caseStatusTxt,   (v) => setState(() => _caseStatusId = v)),
          SheetDateField(label: 'تاريخ الإزالة', controller: _removalDate, readOnly: _isView),
          _ddOrTextCtrl('موقف الحجز الإداري', _adminSeizureStatuses, _adminSeizureStatusId, _adminSeizureTxt, (v) => setState(() => _adminSeizureStatusId = v)),
          _ddOrTextCtrl('موقف التنبيد',      _dissipationStatuses, _dissipationStatusId,  _tanbidTxt,       (v) => setState(() => _dissipationStatusId = v)),
          _ddOrTextCtrl('الموقف من السداد',  _paymentStatuses,     _paymentStatusId,      _paymentTxt,      (v) => setState(() => _paymentStatusId = v)),
          SheetTextField(label: 'مصدر البيانات', controller: _dataSource, readOnly: _isView),
        ]),
        const SizedBox(height: 10),
        SheetTextField(label: 'رقم الصف في Excel', controller: _sourceRow,
            readOnly: _isView, keyboardType: TextInputType.number),
      ],
    );
  }

  // ── الحسابات ─────────────────────────────────────────────
  Widget _buildFinancials() {
    return SheetSectionCard(
      title: 'الحسابات والمستحقات', icon: Icons.calculate_outlined, iconColor: _kGold,
      children: [
        _row([
          SheetMoneyField(label: 'قيمة المحضر',        controller: _reportValue,     readOnly: _isView),
          SheetMoneyField(label: '47%',                 controller: _percent47,       readOnly: _isView),
          SheetMoneyField(label: 'قيمة رد السريه لأصله', controller: _restoration,  readOnly: _isView),
          SheetMoneyField(label: 'قيمة مقابل الانتفاع', controller: _usufruct,       readOnly: _isView),
          SheetMoneyField(label: 'قيمة الحجز الإداري', controller: _adminSeizureVal, readOnly: _isView),
          SheetMoneyField(label: 'إجمالي المستحقات',   controller: _totalDues,       readOnly: _isView),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: 200,
            child: SheetMoneyField(label: 'ما تم سداده', controller: _paidAmount, readOnly: _isView)),
      ],
    );
  }

  // ── المرفقات ─────────────────────────────────────────────
  Widget _buildAttachments() {
    return SheetSectionCard(
      title: 'المرفقات',
      icon: Icons.attach_file,
      children: [
        // ── شارة الخادم ──────────────────────────────────
        if (_caseId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('استقبال الصور من الموبايل: ',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const UsbServerBadge(),
                if (_caseId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('رقم القضية: $_caseId',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _kDark,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),

        // ── أزرار نوع المرفق ─────────────────────────────
        if (!_isView)
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              _AttachTypeBtn(label: 'صورة المحضر',    icon: Icons.document_scanner_outlined, type: 'report',   caseId: _caseId),
              _AttachTypeBtn(label: 'صورة الهوية',    icon: Icons.badge_outlined,            type: 'id_card',  caseId: _caseId),
              _AttachTypeBtn(label: 'قرار الإزالة',   icon: Icons.gavel_outlined,            type: 'removal',  caseId: _caseId),
              _AttachTypeBtn(label: 'مستندات أخرى',  icon: Icons.folder_outlined,            type: 'other',    caseId: _caseId),
            ],
          ),

        // ── قائمة المرفقات ───────────────────────────────
        if (_attachLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    color: Colors.grey[400], size: 20),
                const SizedBox(width: 6),
                Text(
                  _caseId != null
                      ? 'لا توجد مرفقات — صوّر من تطبيق الموبايل ورقم القضية: $_caseId'
                      : 'احفظ القضية أولاً لإضافة مرفقات',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          const SizedBox(height: 10),
          ..._attachments.map((rec) => _AttachmentRow(
            record: rec,
            canDelete: !_isView || _isManager,
            onDelete: () => _deleteAttachment(rec),
          )),
        ],
      ],
    );
  }

  // ── ملاحظات ──────────────────────────────────────────────
  Widget _buildNotes() {
    return SheetSectionCard(
      title: 'ملاحظات', icon: Icons.notes_outlined,
      children: [
        SheetTextField(label: '', controller: _notes,
            readOnly: _isView, maxLines: 3, hint: 'اكتب ملاحظاتك هنا...'),
      ],
    );
  }

  // ── صف 6 حقول ────────────────────────────────────────────
  Widget _row(List<Widget> fields) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.map((f) => Expanded(
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: f),
      )).toList(),
    );
  }

  // ── Dropdown أو نص للعرض ──────────────────────────────────
  Widget _ddOrText(
    String label,
    List<Map<String, dynamic>> options,
    int? value,
    void Function(int?) onChanged, {
    bool isRequired = false,
  }) {
    if (_isView) {
      final name = options.where((o) => o['id'] == value)
          .map((o) => o['name']?.toString()).firstOrNull ?? '-';
      return SheetTextField(label: label,
          controller: TextEditingController(text: name), readOnly: true);
    }
    return SheetDropdownField<int>(
      label: label, readOnly: false, isRequired: isRequired,
      value: options.any((o) => o['id'] == value) ? value : null,
      onChanged: onChanged,
      items: options.map((o) => DropdownMenuItem<int>(
        value: o['id'] as int?,
        child: Text(o['name']?.toString() ?? '', textDirection: TextDirection.rtl),
      )).toList(),
    );
  }

  // ── Dropdown مع fallback controller ──────────────────────
  Widget _ddOrTextCtrl(
    String label,
    List<Map<String, dynamic>> options,
    int? value,
    TextEditingController fallback,
    void Function(int?) onChanged,
  ) {
    if (_isView) {
      return SheetTextField(label: label, controller: fallback, readOnly: true);
    }
    return SheetDropdownField<int>(
      label: label, readOnly: false,
      value: options.any((o) => o['id'] == value) ? value : null,
      onChanged: onChanged,
      items: options.map((o) => DropdownMenuItem<int>(
        value: o['id'] as int?,
        child: Text(o['name']?.toString() ?? '', textDirection: TextDirection.rtl),
      )).toList(),
    );
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int)  return v;
    return int.tryParse(v.toString());
  }
}

// ──────────────────────────────────────────────────────────────
class _HBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _HBtn({required this.label, required this.icon,
      required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
              color: color ?? Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
          color: color != null
              ? color!.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.08),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color ?? Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 12,
                  color: color ?? Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
/// زر نوع المرفق — يعرض رقم القضية للماسح
class _AttachTypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final String type;
  final int? caseId;

  const _AttachTypeBtn({
    required this.label, required this.icon,
    required this.type, this.caseId,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: caseId != null
          ? 'أرسل من الماسح: رقم القضية $caseId، نوع: $type'
          : 'احفظ القضية أولاً',
      child: Container(
        width: 130, height: 90,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0B6B55), width: 1.5),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF0F9F6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF0B6B55)),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontSize: 11,
                    color: Color(0xFF05352D), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
            if (caseId != null)
              Text('(من الموبايل)',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
/// صف مرفق واحد مع صورة مصغّرة
class _AttachmentRow extends StatelessWidget {
  final AttachmentRecord record;
  final bool canDelete;
  final VoidCallback onDelete;

  const _AttachmentRow({
    required this.record, required this.canDelete, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(record.filePath);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Row(
        children: [
          // ── صورة مصغّرة أو أيقونة ───────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: record.isImage && file.existsSync()
                ? Image.file(file,
                    width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconBox())
                : _iconBox(),
          ),
          const SizedBox(width: 10),
          // ── معلومات ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.typeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13, color: Color(0xFF05352D))),
                const SizedBox(height: 2),
                Text(record.fileName,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis),
                Text(record.createdAt,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFADB5BD))),
              ],
            ),
          ),
          // ── أزرار ────────────────────────────────────────
          if (record.isImage && file.existsSync())
            IconButton(
              icon: const Icon(Icons.zoom_in,
                  color: Color(0xFF0B6B55), size: 20),
              tooltip: 'عرض مكبّر',
              onPressed: () => _showFullImage(context, file),
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFB42318), size: 20),
              tooltip: 'حذف',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  Widget _iconBox() => Container(
    width: 64, height: 64,
    color: const Color(0xFFF0F9F6),
    child: const Icon(Icons.description_outlined,
        color: Color(0xFF0B6B55), size: 32),
  );

  void _showFullImage(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(file, fit: BoxFit.contain)),
            Positioned(
              top: 8, left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
