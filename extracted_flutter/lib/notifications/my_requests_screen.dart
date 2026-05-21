// ============================================================
// my_requests_screen.dart — شاشة طلباتي (الموظف)
// ضعه في: lib/notifications/my_requests_screen.dart
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'approval_service.dart';

// ── ألوان الثيم ───────────────────────────────────────────────
const _kDark  = Color(0xFF05352D);
const _kMid   = Color(0xFF0B6B55);
const _kCream = Color(0xFFF5F2EA);
const _kGold  = Color(0xFFE5C07B);
const _kRed   = Color(0xFFB42318);

// ── أسماء الحقول بالعربية ─────────────────────────────────────
const Map<String, String> _fieldLabels = {
  'offender_name':           'اسم المخالف',
  'offender_national_id':    'الرقم القومي',
  'report_number':           'رقم المحضر',
  'report_year':             'سنة المحضر',
  'report_date':             'تاريخ المحضر',
  'removal_decision_number': 'رقم قرار الإزالة',
  'judicial_number':         'الرقم القضائي',
  'guarantor_id':            'الرقم الضامن',
  'drain_id':                'رقم المصرف',
  'kilometer_location':      'الموقع الكيلومتري',
  'violation_type_id':       'نوع المخالفة',
  'area':                    'المساحة',
  'observer_id':             'رقم الملاحظ',
  'case_status_id':          'موقف المحضر',
  'removal_date':            'تاريخ الإزالة',
  'admin_seizure_status_id': 'موقف الحجز الإداري',
  'dissipation_status_id':   'موقف التنبيد',
  'payment_status_id':       'الموقف من السداد',
  'source_sheet':            'مصدر البيانات',
  'source_row':              'رقم الصف في Excel',
  'report_value':            'قيمة المحضر',
  'percent_47_value':        '47%',
  'restoration_value':       'قيمة رد السريه',
  'usufruct_value':          'قيمة مقابل الانتفاع',
  'admin_seizure_value':     'قيمة الحجز الإداري',
  'total_dues':              'إجمالي المستحقات',
  'paid_amount':             'ما تم سداده',
  'notes':                   'ملاحظات',
  'file_path':               'مسار الملف',
  'file_name':               'اسم الملف',
  'attachment_type':         'نوع المرفق',
  'case_id':                 'رقم القضية',
  'uploaded_by':             'رُفع بواسطة',
};

String _label(String key) => _fieldLabels[key] ?? key;
const _hiddenKeys = {'id', 'created_at', 'updated_at'};

// ─────────────────────────────────────────────────────────────
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({
    super.key,
    required this.approvalService,
    required this.currentUser,
  });

  final ApprovalService       approvalService;
  final Map<String, dynamic>  currentUser;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = widget.currentUser['id'] as int? ?? 0;
    final data   = await widget.approvalService.getMyRequests(userId);
    if (!mounted) return;
    setState(() { _requests = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _requests;
    return _requests.where((r) => r['status'] == _filter).toList();
  }

  int _count(String s) => _requests.where((r) => r['status'] == s).length;

  void _openDetail(Map<String, dynamic> req) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _RequestDetailScreen(request: req),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kCream,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kMid))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kDark,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
          const Icon(Icons.history, color: _kGold, size: 20),
          const SizedBox(width: 8),
          const Text('طلباتي المُقدَّمة',
              style: TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          _chip('all',      'الكل',    Colors.blueGrey, _requests.length),
          const SizedBox(width: 6),
          _chip('pending',  'معلّقة',  Colors.orange,   _count('pending')),
          const SizedBox(width: 6),
          _chip('approved', 'مقبولة',  _kMid,           _count('approved')),
          const SizedBox(width: 6),
          _chip('rejected', 'مرفوضة', _kRed,            _count('rejected')),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'تحديث',
          ),
        ],
      ),
    );
  }

  Widget _chip(String val, String label, Color color, int count) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                color: sel ? Colors.white : color,
                fontSize: 11,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              )),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? Colors.white30 : color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                    color: sel ? Colors.white : color,
                    fontSize: 10, fontWeight: FontWeight.bold,
                  )),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MyRequestCard(
        request: _filtered[i],
        onView: () => _openDetail(_filtered[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          _filter == 'all'
              ? 'لم تقدّم أي طلبات حتى الآن'
              : 'لا توجد طلبات في هذه القائمة',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة الطلب في قائمة الموظف
// ─────────────────────────────────────────────────────────────
class _MyRequestCard extends StatelessWidget {
  const _MyRequestCard({required this.request, required this.onView});

  final Map<String, dynamic> request;
  final VoidCallback onView;

  Color get _statusColor {
    switch (request['status']) {
      case 'approved': return _kMid;
      case 'rejected': return _kRed;
      default:         return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (request['status']) {
      case 'approved': return 'تمت الموافقة ✓';
      case 'rejected': return 'مرفوض ✗';
      default:         return 'في انتظار المدير ⏳';
    }
  }

  String get _typeLabel {
    switch (request['request_type']) {
      case 'add':    case 'create':  return 'إضافة محضر';
      case 'edit':   case 'update':  return 'تعديل محضر';
      case 'delete':                 return 'حذف محضر';
      case 'attachment_add':         return 'إرفاق صورة';
      default: return request['request_type']?.toString() ?? '-';
    }
  }

  String _fmt(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
          '  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final status   = request['status']?.toString() ?? 'pending';
    final rejected = status == 'rejected';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(right: BorderSide(color: _statusColor, width: 5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── صف العنوان ────────────────────────────────
            Row(children: [
              // نوع الطلب
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_typeLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              // حالة الطلب
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(
                      color: _statusColor, fontSize: 12,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              const Spacer(),
              // زر عرض التفاصيل
              GestureDetector(
                onTap: onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kDark.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kDark.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.visibility_outlined, size: 14, color: _kDark),
                    SizedBox(width: 5),
                    Text('عرض التفاصيل',
                        style: TextStyle(fontSize: 12,
                            color: _kDark, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // ── التواريخ ──────────────────────────────────
            Row(children: [
              const Icon(Icons.send_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text('أُرسل: ${_fmt(request['created_at']?.toString())}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (request['reviewed_at'] != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.done_all, size: 13, color: _statusColor),
                const SizedBox(width: 4),
                Text('رُوجع: ${_fmt(request['reviewed_at']?.toString())}',
                    style: TextStyle(color: _statusColor, fontSize: 12)),
              ],
            ]),

            // ── سبب الرفض ─────────────────────────────────
            if (rejected &&
                request['rejection_reason'] != null &&
                request['rejection_reason'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, color: _kRed, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سبب الرفض: ${request['rejection_reason']}',
                      style: const TextStyle(color: _kRed, fontSize: 13),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// شاشة تفاصيل الطلب (قراءة فقط — للموظف)
// ─────────────────────────────────────────────────────────────
class _RequestDetailScreen extends StatelessWidget {
  const _RequestDetailScreen({required this.request});

  final Map<String, dynamic> request;

  String get _type => request['request_type']?.toString() ?? '';
  bool get _isImage => _type == 'attachment_add';

  Map<String, dynamic>? _json(dynamic v) {
    if (v == null || v.toString().trim().isEmpty || v.toString() == '{}') return null;
    try { return jsonDecode(v.toString()) as Map<String, dynamic>; }
    catch (_) { return null; }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'add':   case 'create':  return 'إضافة محضر جديد';
      case 'edit':  case 'update':  return 'تعديل محضر';
      case 'delete':                return 'حذف محضر';
      case 'attachment_add':        return 'إرفاق صورة';
      default:                      return t;
    }
  }

  String _fmt(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
          '  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final before   = _json(request['before_data']);
    final after    = _json(request['after_data']);
    final status   = request['status']?.toString() ?? 'pending';
    final reviewer = request['reviewed_by_name']?.toString();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = _kMid; statusLabel = 'تمت الموافقة ✓'; break;
      case 'rejected':
        statusColor = _kRed; statusLabel = 'مرفوض ✗'; break;
      default:
        statusColor = Colors.orange; statusLabel = 'في انتظار المدير ⏳';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kCream,
        body: Column(
          children: [
            // ── هيدر ─────────────────────────────────────
            Container(
              color: _kDark,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.description_outlined, color: _kGold, size: 15),
                    const SizedBox(width: 6),
                    Text('تفاصيل الطلب: ${_typeLabel(_type)}',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  Text(_fmt(request['created_at']?.toString()),
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
                const Spacer(),
                // حالة الطلب
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
              ]),
            ),

            // ── المحتوى ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // بطاقة حالة الطلب
                    _StatusSummaryCard(
                      status: status,
                      statusColor: statusColor,
                      statusLabel: statusLabel,
                      reviewer: reviewer,
                      reviewedAt: request['reviewed_at']?.toString(),
                      reason: request['rejection_reason']?.toString(),
                    ),
                    const SizedBox(height: 16),

                    // محتوى البيانات أو الصورة
                    if (_isImage)
                      _ImageViewCard(afterData: after)
                    else
                      _DataViewCard(
                        before: before,
                        after: after,
                        requestType: _type,
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة ملخص الحالة
// ─────────────────────────────────────────────────────────────
class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({
    required this.status,
    required this.statusColor,
    required this.statusLabel,
    required this.reviewer,
    required this.reviewedAt,
    required this.reason,
  });

  final String  status, statusLabel;
  final Color   statusColor;
  final String? reviewer, reviewedAt, reason;

  String _fmt(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              status == 'approved'
                  ? Icons.check_circle_outline
                  : status == 'rejected'
                      ? Icons.cancel_outlined
                      : Icons.pending_outlined,
              color: statusColor, size: 20,
            ),
            const SizedBox(width: 8),
            Text(statusLabel,
                style: TextStyle(color: statusColor,
                    fontWeight: FontWeight.bold, fontSize: 15)),
            if (reviewer != null) ...[
              const SizedBox(width: 12),
              Text('بواسطة: $reviewer',
                  style: TextStyle(color: statusColor.withValues(alpha: 0.8), fontSize: 13)),
              if (reviewedAt != null)
                Text('  ·  ${_fmt(reviewedAt)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ]),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kRed.withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, color: _kRed, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('سبب الرفض: $reason',
                      style: const TextStyle(color: _kRed, fontSize: 13)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة عرض البيانات (قراءة فقط)
// ─────────────────────────────────────────────────────────────
class _DataViewCard extends StatelessWidget {
  const _DataViewCard({
    required this.before,
    required this.after,
    required this.requestType,
  });

  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String requestType;

  bool get _isAdd => requestType == 'add' || requestType == 'create';

  String _norm(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s == '-' || s == 'null') return '';
    return s;
  }

  bool _isChanged(dynamic bv, dynamic av) => _norm(bv) != _norm(av);

  @override
  Widget build(BuildContext context) {
    final afterMap  = after  ?? {};
    final beforeMap = before ?? {};

    final baseKeys = afterMap.keys
        .where((k) => !_hiddenKeys.contains(k))
        .toList();

    final displayKeys = _isAdd
        ? baseKeys.where((k) {
            final v = _norm(afterMap[k]);
            return v.isNotEmpty && v != '0' && v != '0.0';
          }).toList()
        : baseKeys.where((k) {
            final av = _norm(afterMap[k]);
            final bv = _norm(beforeMap[k]);
            return _isChanged(bv, av) || av.isNotEmpty;
          }).toList();

    if (!_isAdd) {
      displayKeys.sort((a, b) {
        final ac = _isChanged(beforeMap[a], afterMap[a]);
        final bc = _isChanged(beforeMap[b], afterMap[b]);
        if (ac && !bc) return -1;
        if (!ac && bc) return 1;
        return 0;
      });
    }

    final changedCount = _isAdd
        ? displayKeys.length
        : displayKeys.where((k) => _isChanged(beforeMap[k], afterMap[k])).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _isAdd ? _kMid : Colors.orange.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(children: [
              Icon(_isAdd ? Icons.add_circle_outline : Icons.compare_arrows,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                _isAdd ? 'بيانات المحضر الجديد' : 'التعديلات المطلوبة',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (changedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isAdd ? '$changedCount حقل' : '$changedCount تعديل',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ]),
          ),

          if (displayKeys.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)),
            )
          else
            Column(children: [
              // رأس الجدول للتعديل
              if (!_isAdd)
                Container(
                  color: const Color(0xFFF5F5F5),
                  child: Row(children: [
                    _th('الحقل', flex: 3),
                    _th('القيمة الحالية', flex: 4,
                        color: _kRed.withValues(alpha: 0.8)),
                    _th('القيمة الجديدة', flex: 4, color: _kMid),
                  ]),
                ),
              ...displayKeys.map((key) {
                final bv      = beforeMap[key];
                final av      = afterMap[key];
                final oldVal  = _norm(bv);
                final newVal  = _norm(av);
                final changed = !_isAdd && _isChanged(bv, av);

                return Container(
                  decoration: BoxDecoration(
                    color: changed
                        ? const Color(0xFFFFF8E1)
                        : Colors.transparent,
                    border: const Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: _isAdd
                      ? _addRow(key, newVal)
                      : _diffRow(key,
                          oldVal.isEmpty ? '—' : oldVal,
                          newVal.isEmpty ? '—' : newVal,
                          changed),
                );
              }),
            ]),
        ],
      ),
    );
  }

  Widget _addRow(String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Expanded(flex: 3, child: Text(_label(key),
          style: const TextStyle(fontWeight: FontWeight.bold,
              fontSize: 13, color: _kDark))),
      Expanded(flex: 7, child: Text(value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _diffRow(String key, String old, String nw, bool changed) {
    return Row(children: [
      Expanded(flex: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            if (changed)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.edit, size: 11, color: Colors.orange),
              ),
            Flexible(child: Text(_label(key),
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 12, color: _kDark),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      _td(old, flex: 4,
          color: changed ? _kRed : Colors.grey[600], strike: changed),
      _td(nw,  flex: 4,
          color: changed ? _kMid : Colors.grey[600], bold: changed),
    ]);
  }

  Widget _th(String text, {int flex = 1, Color? color}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold,
        color: color ?? const Color(0xFF555555),
      )),
    ),
  );

  Widget _td(String text, {
    int flex = 1, Color? color, bool bold = false, bool strike = false,
  }) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Text(text,
        style: TextStyle(
          fontSize: 12,
          color: color ?? const Color(0xFF2D2D2D),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          decoration: strike ? TextDecoration.lineThrough : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// بطاقة عرض الصورة (قراءة فقط)
// ─────────────────────────────────────────────────────────────
class _ImageViewCard extends StatefulWidget {
  const _ImageViewCard({required this.afterData});
  final Map<String, dynamic>? afterData;

  @override
  State<_ImageViewCard> createState() => _ImageViewCardState();
}

class _ImageViewCardState extends State<_ImageViewCard> {
  bool _exists = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final path = widget.afterData?['file_path']?.toString() ?? '';
    if (path.isEmpty) return;
    final e = await File(path).exists();
    if (mounted) setState(() => _exists = e);
  }

  @override
  Widget build(BuildContext context) {
    final d        = widget.afterData ?? {};
    final filePath = d['file_path']?.toString() ?? '';
    final fileName = d['file_name']?.toString() ?? 'مرفق';
    final caseId   = d['case_id']?.toString() ?? '-';
    final attType  = _attLabel(d['attachment_type']?.toString() ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(children: const [
              Icon(Icons.image_outlined, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('الصورة المُرفَقة',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _exists && filePath.isNotEmpty
                      ? Image.file(File(filePath), fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _info(Icons.folder_outlined,   'اسم الملف',  fileName),
                  _info(Icons.category_outlined, 'نوع المرفق', attType),
                  _info(Icons.tag,               'رقم القضية', '#$caseId'),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 200,
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 8),
      Text('الصورة غير موجودة',
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    ]),
  );

  Widget _info(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: _kMid),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  String _attLabel(String t) {
    switch (t) {
      case 'report':  return 'صورة المحضر';
      case 'id_card': return 'صورة الهوية';
      case 'removal': return 'قرار الإزالة';
      default:        return 'مستندات أخرى';
    }
  }
}
