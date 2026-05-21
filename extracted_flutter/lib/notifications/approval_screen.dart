// ============================================================
// approval_screen.dart  — شاشة مراجعة الطلبات (المدير)
// ضعه في: lib/notifications/approval_screen.dart
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_service.dart';
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

// ── الحقول التي يجب إخفاؤها من جدول المقارنة ─────────────────
const _hiddenKeys = {'id', 'created_at', 'updated_at'};

// ─────────────────────────────────────────────────────────────
class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({
    super.key,
    required this.approvalService,
    required this.currentUser,
  });

  final ApprovalService approvalService;
  final Map<String, dynamic> currentUser;

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.approvalService.getPendingRequests();
    if (!mounted) return;
    setState(() {
      _requests = data;
      _loading  = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _requests;
    return _requests.where((r) => r['status'] == _filter).toList();
  }

  int _count(String status) =>
      _requests.where((r) => r['status'] == status).length;

  Future<void> _openReview(Map<String, dynamic> req) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ReviewScreen(
          request: req,
          approvalService: widget.approvalService,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (changed == true) _load();
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
                  ? const Center(
                      child: CircularProgressIndicator(color: _kMid))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── الهيدر ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kDark,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.pending_actions, color: _kGold, size: 22),
          const SizedBox(width: 8),
          const Text(
            'مراجعة طلبات الموظفين',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _filterChip('pending',  'معلّقة', Colors.orange,  _count('pending')),
          const SizedBox(width: 6),
          _filterChip('approved', 'مقبولة', _kMid,         _count('approved')),
          const SizedBox(width: 6),
          _filterChip('rejected', 'مرفوضة', _kRed,         _count('rejected')),
          const SizedBox(width: 6),
          _filterChip('all',      'الكل',   Colors.blueGrey, _requests.length),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'تحديث',
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String val, String label, Color color, int count) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                color: sel ? Colors.white : color,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              )),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? Colors.white30 : color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                    color: sel ? Colors.white : color,
                    fontSize: 11, fontWeight: FontWeight.bold,
                  )),
            ),
          ],
        ]),
      ),
    );
  }

  // ── القائمة ───────────────────────────────────────────────
  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RequestCard(
        request: _filtered[i],
        onTap: () => _openReview(_filtered[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _filter == 'pending'
                ? 'لا توجد طلبات معلّقة حالياً'
                : 'لا توجد طلبات في هذه القائمة',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة طلب واحد في القائمة
// ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final Map<String, dynamic> request;
  final VoidCallback onTap;

  Color get _borderColor {
    switch (request['status']) {
      case 'approved': return _kMid;
      case 'rejected': return _kRed;
      default:         return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type      = request['request_type']?.toString() ?? '';
    final requester = request['requested_by_name']?.toString() ?? 'غير معروف';
    final status    = request['status']?.toString() ?? 'pending';
    final date      = _fmt(request['created_at']?.toString());
    final isImg     = type == 'attachment_add';
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(right: BorderSide(color: _borderColor, width: 5)),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // أيقونة النوع
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: isImg
                      ? Colors.blue.shade50
                      : isPending
                          ? Colors.orange.shade50
                          : status == 'approved'
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isImg
                      ? Icons.image_outlined
                      : type == 'add' || type == 'create'
                          ? Icons.add_circle_outline
                          : type == 'delete'
                              ? Icons.delete_outline
                              : Icons.edit_outlined,
                  color: isImg
                      ? Colors.blue
                      : isPending
                          ? Colors.orange
                          : status == 'approved' ? _kMid : _kRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // معلومات الطلب
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _TypeBadge(type),
                      const SizedBox(width: 8),
                      _StatusBadge(status),
                    ]),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
                        children: [
                          const TextSpan(text: 'الموظف: ',
                              style: TextStyle(color: Colors.grey)),
                          TextSpan(text: requester,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(date,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),

              // زر عرض التفاصيل
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isPending ? _kDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isPending ? Icons.rate_review_outlined : Icons.visibility_outlined,
                    size: 14,
                    color: isPending ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isPending ? 'مراجعة' : 'عرض',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: isPending ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────
// شاشة المراجعة الكاملة
// ─────────────────────────────────────────────────────────────
class _ReviewScreen extends StatefulWidget {
  const _ReviewScreen({
    required this.request,
    required this.approvalService,
    required this.currentUser,
  });

  final Map<String, dynamic>  request;
  final ApprovalService       approvalService;
  final Map<String, dynamic>  currentUser;

  @override
  State<_ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewScreen> {
  bool _processing = false;
  Map<String, List<Map<String, dynamic>>> _filterOptions = {};

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final opts = await DatabaseService.getFilterOptions();
      if (mounted) setState(() => _filterOptions = opts);
    } catch (_) {}
  }

  Map<String, dynamic>? get _before => _json(widget.request['before_data']);
  Map<String, dynamic>? get _after  => _json(widget.request['after_data']);

  Map<String, dynamic>? _json(dynamic v) {
    if (v == null || v.toString().trim().isEmpty || v.toString() == '{}') return null;
    try { return jsonDecode(v.toString()) as Map<String, dynamic>; }
    catch (_) { return null; }
  }

  String get _type => widget.request['request_type']?.toString() ?? '';
  bool get _isPending => widget.request['status'] == 'pending';
  bool get _isImage   => _type == 'attachment_add';

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: const [
            Icon(Icons.check_circle_outline, color: _kMid),
            SizedBox(width: 8),
            Text('تأكيد الموافقة'),
          ]),
          content: const Text('هل تريد الموافقة على هذا الطلب وتطبيقه فوراً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kMid),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('موافق ✓'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await widget.approvalService.approveRequest(
        requestId:  widget.request['id'] as int,
        reviewedBy: widget.currentUser['id'] as int,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ تمت الموافقة وتطبيق التعديل بنجاح'),
        backgroundColor: _kMid,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: _kRed,
        ));
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: const [
            Icon(Icons.cancel_outlined, color: _kRed),
            SizedBox(width: 8),
            Text('سبب الرفض'),
          ]),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اكتب سبب رفض الطلب...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kRed),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('رفض الطلب ✗'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await widget.approvalService.rejectRequest(
        requestId:  widget.request['id'] as int,
        reviewedBy: widget.currentUser['id'] as int,
        reason:     ctrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✗ تم رفض الطلب وإخطار الموظف'),
        backgroundColor: _kRed,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: _kRed,
        ));
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req       = widget.request;
    final requester = req['requested_by_name']?.toString() ?? 'غير معروف';
    final reviewer  = req['reviewed_by_name']?.toString();
    final date      = _fmtFull(req['created_at']?.toString());
    final status    = req['status']?.toString() ?? 'pending';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kCream,
        body: Column(
          children: [
            // ── هيدر الشاشة ──────────────────────────────
            _buildTopBar(requester, date),

            // ── المحتوى ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // بطاقة معلومات الطلب
                    _InfoCard(request: req),
                    const SizedBox(height: 16),

                    // محتوى الطلب
                    if (_isImage)
                      _ImageCard(afterData: _after)
                    else
                      _ReviewSheetCard(
                        before: _before,
                        after: _after,
                        requestType: _type,
                        filterOptions: _filterOptions,
                      ),

                    // سبب الرفض
                    if (status == 'rejected' &&
                        req['rejection_reason'] != null &&
                        req['rejection_reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _RejectionCard(reason: req['rejection_reason'].toString()),
                    ],

                    // معلومات المراجع
                    if (reviewer != null && status != 'pending') ...[
                      const SizedBox(height: 16),
                      _ReviewerCard(
                        reviewer: reviewer,
                        reviewedAt: req['reviewed_at']?.toString(),
                        status: status,
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── شريط الأزرار (للمعلّقة فقط) ─────────────
            if (_isPending) _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String requester, String date) {
    return Container(
      color: _kDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.rate_review_outlined, color: _kGold, size: 16),
                const SizedBox(width: 6),
                Text(
                  'مراجعة طلب: ${_typeLabel(_type)}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ]),
              Text('من: $requester  ·  $date',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const Spacer(),
          _StatusBadge(widget.request['status']?.toString() ?? 'pending',
              large: true),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5DCC8))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_processing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: _kMid, strokeWidth: 2)),
            )
          else ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kRed,
                side: const BorderSide(color: _kRed),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _reject,
              icon: const Icon(Icons.close),
              label: const Text('رفض الطلب', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kMid,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              onPressed: _approve,
              icon: const Icon(Icons.check),
              label: const Text('موافقة وتطبيق', style: TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'add':    case 'create':   return 'إضافة محضر جديد';
      case 'edit':   case 'update':   return 'تعديل محضر';
      case 'delete':                  return 'حذف محضر';
      case 'attachment_add':          return 'إرفاق صورة';
      default:                        return t;
    }
  }

  String _fmtFull(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة معلومات الطلب العامة
// ─────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final type      = request['request_type']?.toString() ?? '';
    final requester = request['requested_by_name']?.toString() ?? '-';
    final date      = _fmt(request['created_at']?.toString());
    final targetId  = request['target_id']?.toString();

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
              color: _kDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(children: const [
              Icon(Icons.info_outline, color: _kGold, size: 16),
              SizedBox(width: 8),
              Text('معلومات الطلب',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24, runSpacing: 12,
              children: [
                _infoItem(Icons.person_outline, 'مقدّم الطلب', requester),
                _infoItem(Icons.category_outlined, 'نوع الطلب', _typeLabel(type)),
                _infoItem(Icons.calendar_today_outlined, 'تاريخ الطلب', date),
                if (targetId != null && targetId != 'null')
                  _infoItem(Icons.tag, 'رقم المحضر المستهدف', '#$targetId'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: _kMid),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    ]);
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
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة المقارنة للبيانات (قبل / بعد)
// ─────────────────────────────────────────────────────────────
class _DataDiffCard extends StatelessWidget {
  const _DataDiffCard({
    required this.before,
    required this.after,
    required this.requestType,
  });

  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String requestType;

  bool get _isAdd => requestType == 'add' || requestType == 'create';

  // تطبيع القيمة للمقارنة (null == '' == '-' == '0' للأرقام المبدئية)
  String _norm(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s == '-' || s == 'null') return '';
    return s;
  }

  bool _isChanged(dynamic bv, dynamic av) =>
      _norm(bv) != _norm(av);

  @override
  Widget build(BuildContext context) {
    final afterMap  = after  ?? {};
    final beforeMap = before ?? {};

    // ── نستخدم فقط مفاتيح after_data (ما غيّره الموظف فعلاً) ──
    // بهذا نتجنب حقول JOIN مثل drain_name/observer_name في before
    final baseKeys = afterMap.keys
        .where((k) => !_hiddenKeys.contains(k))
        .toList();

    // في حالة الإضافة: أظهر الحقول التي لها قيمة فعلية فقط
    // في حالة التعديل: أظهر الحقول المُغيَّرة + الحقول التي لها قيمة في after
    final displayKeys = _isAdd
        ? baseKeys.where((k) {
            final v = _norm(afterMap[k]);
            return v.isNotEmpty && v != '0' && v != '0.0';
          }).toList()
        : baseKeys.where((k) {
            final av = _norm(afterMap[k]);
            final bv = _norm(beforeMap[k]);
            // أظهر الحقل إذا كان متغيراً، أو إذا كان له قيمة في after
            return _isChanged(bv, av) || av.isNotEmpty;
          }).toList();

    // الحقول المُغيَّرة أولاً في التعديل
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
          // عنوان البطاقة
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
                    _isAdd
                        ? '$changedCount حقل'
                        : '$changedCount تعديل',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ]),
          ),

          if (displayKeys.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا توجد بيانات للعرض',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            )
          else
            _buildTable(displayKeys, beforeMap, afterMap),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<String> keys,
    Map<String, dynamic> beforeMap,
    Map<String, dynamic> afterMap,
  ) {
    return Column(
      children: [
        // رأس الجدول
        if (!_isAdd)
          Container(
            color: const Color(0xFFF5F5F5),
            child: Row(children: [
              _th('الحقل', flex: 3),
              _th('القيمة الحالية', flex: 4, color: _kRed.withValues(alpha: 0.8)),
              _th('القيمة الجديدة', flex: 4, color: _kMid),
            ]),
          ),

        // الصفوف
        ...keys.map((key) {
          final bv  = beforeMap[key];
          final av  = afterMap[key];
          final oldVal = _norm(bv);
          final newVal = _norm(av);
          final changed = !_isAdd && _isChanged(bv, av);

          return Container(
            decoration: BoxDecoration(
              color: changed ? const Color(0xFFFFF8E1) : Colors.transparent,
              border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: _isAdd
                ? _addRow(key, newVal)
                : _diffRow(key, oldVal.isEmpty ? '—' : oldVal,
                           newVal.isEmpty ? '—' : newVal, changed),
          );
        }),
      ],
    );
  }

  Widget _addRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(_label(key),
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13, color: _kDark)),
        ),
        Expanded(
          flex: 7,
          child: Text(value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _diffRow(String key, String oldVal, String newVal, bool changed) {
    return Row(children: [
      _td(
        _label(key),
        flex: 3,
        bold: true,
        suffix: changed
            ? const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.edit, size: 11, color: Colors.orange),
              )
            : null,
      ),
      _td(
        oldVal.isEmpty ? '—' : oldVal,
        flex: 4,
        color: changed ? _kRed : Colors.grey[600],
        strike: changed,
      ),
      _td(
        newVal.isEmpty ? '—' : newVal,
        flex: 4,
        color: changed ? _kMid : Colors.grey[600],
        bold: changed,
      ),
    ]);
  }

  Widget _th(String text, {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF555555),
            )),
      ),
    );
  }

  Widget _td(String text, {
    int flex = 1, Color? color, bool bold = false,
    bool strike = false, Widget? suffix,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          if (suffix != null) suffix,
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color ?? const Color(0xFF2D2D2D),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                decoration: strike ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// واجهة مراجعة الطلب بتصميم صحيفة المواطن
// ─────────────────────────────────────────────────────────────
class _ReviewSheetCard extends StatelessWidget {
  const _ReviewSheetCard({
    required this.before,
    required this.after,
    required this.requestType,
    required this.filterOptions,
  });

  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String requestType;
  final Map<String, List<Map<String, dynamic>>> filterOptions;

  bool get _isAdd => requestType == 'add' || requestType == 'create';

  String _n(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return (s == 'null' || s == '-') ? '' : s;
  }

  String _resolveName(String optKey, dynamic idVal) {
    if (idVal == null) return '';
    final id = idVal is int ? idVal : int.tryParse(idVal.toString());
    if (id == null) return '';
    final list = filterOptions[optKey] ?? [];
    for (final o in list) {
      if (o['id'] == id) return o['name']?.toString() ?? '';
    }
    return id.toString();
  }

  String _resolveViolations(dynamic idsVal, dynamic singleIdVal) {
    final idsStr = _n(idsVal);
    if (idsStr.isNotEmpty) {
      final ids = idsStr.split(',')
          .map((s) => int.tryParse(s.trim()))
          .where((id) => id != null)
          .toList();
      return ids
          .map((id) => _resolveName('violation_types', id))
          .where((s) => s.isNotEmpty)
          .join(' + ');
    }
    return _resolveName('violation_types', singleIdVal);
  }

  @override
  Widget build(BuildContext context) {
    final b = before ?? {};
    final a = after  ?? {};

    // ── حقل بسيط (نفس المفتاح في before و after) ──
    Widget sf(String label, String key, {bool isMoney = false}) {
      final oldV = _n(b[key]);
      final newV = _n(a[key]);
      final diff = !_isAdd && oldV != newV;
      return _ReviewField(
        label: label,
        oldVal: isMoney && oldV.isNotEmpty ? '$oldV ج.م' : oldV,
        newVal: isMoney && newV.isNotEmpty ? '$newV ج.م' : newV,
        isChanged: diff,
        isAdd: _isAdd,
      );
    }

    // ── حقل اسم مُحوَّل من ID ──
    Widget lf(String label, String bNameKey, String aIdKey, String optKey) {
      final oldV = _n(b[bNameKey]);
      final newV = _resolveName(optKey, a[aIdKey]);
      final diff = !_isAdd && oldV != newV && (oldV.isNotEmpty || newV.isNotEmpty);
      return _ReviewField(
        label: label,
        oldVal: oldV,
        newVal: newV,
        isChanged: diff,
        isAdd: _isAdd,
      );
    }

    // ── حقل المخالفات المتعددة ──
    final oldVio = _n(b['violation_type']);
    final newVio = _resolveViolations(a['violation_type_ids'], a['violation_type_id']);
    final vioDiff = !_isAdd && oldVio != newVio && (oldVio.isNotEmpty || newVio.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ══ قسم: البيانات الأساسية ══
        _ReviewSection(
          title: 'البيانات الأساسية',
          icon: Icons.person_outline,
          children: [
            sf('اسم المخالف',        'offender_name'),
            sf('الرقم القومي',        'offender_national_id'),
            sf('رقم المحضر',          'report_number'),
            sf('سنة المحضر',          'report_year'),
            sf('تاريخ المحضر',        'report_date'),
            sf('رقم قرار الإزالة',   'removal_decision_number'),
            sf('الرقم الضامن',        'guarantor_id'),
            sf('الموقع الكيلومتري',   'kilometer_location'),
            sf('المساحة (م²)',         'area'),
            lf('المصرف',              'drain_name',    'drain_id',    'drains'),
            lf('الملاحظ',             'observer_name', 'observer_id', 'observers'),
            _ReviewField(
              label: 'أنواع المخالفة',
              oldVal: oldVio,
              newVal: newVio,
              isChanged: vioDiff,
              isAdd: _isAdd,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ══ قسم: الموقف والإجراءات ══
        _ReviewSection(
          title: 'الموقف والإجراءات',
          icon: Icons.assignment_outlined,
          children: [
            lf('موقف المحضر',        'case_status',         'case_status_id',         'case_statuses'),
            sf('تاريخ الإزالة',       'removal_date'),
            lf('موقف الحجز الإداري', 'admin_seizure_status', 'admin_seizure_status_id', 'admin_seizure_statuses'),
            lf('موقف التنبيد',       'dissipation_status',  'dissipation_status_id',  'dissipation_statuses'),
            lf('الموقف من السداد',   'payment_status',      'payment_status_id',      'payment_statuses'),
            sf('مصدر البيانات',       'source_sheet'),
            sf('رقم الصف',            'source_row'),
          ],
        ),

        const SizedBox(height: 12),

        // ══ قسم: الحسابات والمستحقات ══
        _ReviewSection(
          title: 'الحسابات والمستحقات',
          icon: Icons.calculate_outlined,
          children: [
            sf('قيمة المحضر',         'report_value',        isMoney: true),
            sf('47%',                  'percent_47_value',    isMoney: true),
            sf('قيمة رد السريه',       'restoration_value',   isMoney: true),
            sf('مقابل الانتفاع',       'usufruct_value',      isMoney: true),
            sf('قيمة الحجز الإداري',  'admin_seizure_value', isMoney: true),
            sf('إجمالي المستحقات',    'total_dues',          isMoney: true),
            sf('ما تم سداده',          'paid_amount',         isMoney: true),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// قسم في صحيفة المراجعة (مثل SheetSectionCard)
// ─────────────────────────────────────────────────────────────
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String       title;
  final IconData     icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DCC8)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _kDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(children: [
              Icon(icon, color: _kGold, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: children
                  .map((c) => SizedBox(width: 220, child: c))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// حقل مقارنة واحد: يعرض القديم (أحمر) والجديد (أخضر) إن تغيّر
// ─────────────────────────────────────────────────────────────
class _ReviewField extends StatelessWidget {
  const _ReviewField({
    required this.label,
    required this.oldVal,
    required this.newVal,
    required this.isChanged,
    required this.isAdd,
  });

  final String label;
  final String oldVal;
  final String newVal;
  final bool   isChanged;
  final bool   isAdd;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    if (isAdd) {
      bgColor     = const Color(0xFFE8F5E9);
      borderColor = const Color(0xFFA5D6A7);
    } else if (isChanged) {
      bgColor     = const Color(0xFFFFF8E1);
      borderColor = Colors.orange.shade300;
    } else {
      bgColor     = const Color(0xFFF5F2EA);
      borderColor = const Color(0xFFDDD8CC);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // التسمية
        Row(children: [
          if (isChanged)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.edit, size: 11, color: Colors.orange),
            ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isChanged ? Colors.orange.shade800 : Colors.grey[600],
                fontWeight: isChanged ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 3),
        // القيمة
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: isAdd
              ? Text(
                  newVal.isEmpty ? '-' : newVal,
                  style: const TextStyle(fontSize: 12, color: _kDark),
                )
              : isChanged
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (oldVal.isNotEmpty)
                          Text(
                            oldVal,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kRed,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: _kRed,
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (oldVal.isNotEmpty) ...[
                              const Icon(Icons.arrow_downward,
                                  size: 10, color: _kMid),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                newVal.isEmpty ? '(لا يوجد)' : newVal,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _kMid,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      newVal.isEmpty ? '-' : newVal,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF2D2D2D)),
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة الصورة
// ─────────────────────────────────────────────────────────────
class _ImageCard extends StatefulWidget {
  const _ImageCard({required this.afterData});
  final Map<String, dynamic>? afterData;

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  bool _imageExists = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final path = widget.afterData?['file_path']?.toString() ?? '';
    if (path.isEmpty) return;
    final exists = await File(path).exists();
    if (mounted) setState(() => _imageExists = exists);
  }

  @override
  Widget build(BuildContext context) {
    final d        = widget.afterData ?? {};
    final filePath = d['file_path']?.toString() ?? '';
    final fileName = d['file_name']?.toString() ?? 'مرفق';
    final caseId   = d['case_id']?.toString() ?? '-';
    final attType  = _attTypeLabel(d['attachment_type']?.toString() ?? '');
    final uploader = d['uploaded_by']?.toString() ?? 'السكانر';

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
              Text('صورة مرفقة — تحتاج موافقة',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معاينة الصورة
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imageExists && filePath.isNotEmpty
                        ? Image.file(
                            File(filePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _noImage(),
                          )
                        : _noImage(),
                  ),
                ),

                const SizedBox(width: 20),

                // معلومات الملف
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _imgInfo(Icons.folder_outlined,        'اسم الملف',    fileName),
                      _imgInfo(Icons.category_outlined,      'نوع المرفق',   attType),
                      _imgInfo(Icons.tag,                    'رقم القضية',   '#$caseId'),
                      _imgInfo(Icons.phone_android_outlined, 'رُفع بواسطة',  uploader),
                      if (filePath.isNotEmpty)
                        _imgInfo(Icons.link, 'المسار',
                            filePath, small: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noImage() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text('الصورة غير موجودة',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ]),
    );
  }

  Widget _imgInfo(IconData icon, String label, String value, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: _kMid),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value,
                style: TextStyle(
                  fontSize: small ? 11 : 13,
                  color: small ? Colors.grey[600] : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis, maxLines: 2),
          ]),
        ),
      ]),
    );
  }

  String _attTypeLabel(String t) {
    switch (t) {
      case 'report':  return 'صورة المحضر';
      case 'id_card': return 'صورة الهوية';
      case 'removal': return 'قرار الإزالة';
      default:        return 'مستندات أخرى';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة سبب الرفض
// ─────────────────────────────────────────────────────────────
class _RejectionCard extends StatelessWidget {
  const _RejectionCard({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: _kRed, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('سبب الرفض',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: _kRed, fontSize: 13)),
            const SizedBox(height: 4),
            Text(reason, style: const TextStyle(color: Color(0xFF7B1A1A))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة معلومات المراجع
// ─────────────────────────────────────────────────────────────
class _ReviewerCard extends StatelessWidget {
  const _ReviewerCard({
    required this.reviewer,
    required this.reviewedAt,
    required this.status,
  });

  final String  reviewer;
  final String? reviewedAt;
  final String  status;

  @override
  Widget build(BuildContext context) {
    final color  = status == 'approved' ? _kMid : _kRed;
    final label  = status == 'approved' ? 'وافق عليه' : 'رفضه';
    final icon   = status == 'approved' ? Icons.check_circle : Icons.cancel;
    final dateStr = _fmt(reviewedAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
              children: [
                TextSpan(text: '$label: ',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                TextSpan(text: reviewer),
                if (dateStr.isNotEmpty)
                  TextSpan(text: '  ·  $dateStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _fmt(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets مشتركة صغيرة
// ─────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);
  final String type;

  String get _label {
    switch (type) {
      case 'add':    case 'create':  return 'إضافة';
      case 'edit':   case 'update':  return 'تعديل';
      case 'delete':                 return 'حذف';
      case 'attachment_add':         return 'صورة';
      default:                       return type;
    }
  }

  Color get _color {
    switch (type) {
      case 'add':    case 'create':  return _kMid;
      case 'edit':   case 'update':  return Colors.orange.shade700;
      case 'delete':                 return _kRed;
      case 'attachment_add':         return Colors.blue.shade700;
      default:                       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(_label,
          style: TextStyle(fontSize: 11, color: _color,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status, {this.large = false});
  final String status;
  final bool   large;

  Color get _color {
    switch (status) {
      case 'approved': return _kMid;
      case 'rejected': return _kRed;
      default:         return Colors.orange;
    }
  }

  String get _label {
    switch (status) {
      case 'approved': return 'مقبول ✓';
      case 'rejected': return 'مرفوض ✗';
      default:         return 'في الانتظار ⏳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color),
      ),
      child: Text(_label,
          style: TextStyle(
            color: _color,
            fontSize: large ? 13 : 11,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}
