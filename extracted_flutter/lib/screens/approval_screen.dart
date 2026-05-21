// ============================================================
// approval_screen.dart
// شاشة مراجعة الطلبات — للمدير فقط
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/approval_service.dart';

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
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String statusFilter = 'pending'; // 'pending' | 'approved' | 'rejected' | 'all'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await widget.approvalService.getPendingRequests();
    if (!mounted) return;
    setState(() {
      requests = data;
      loading = false;
    });
  }

  List<Map<String, dynamic>> get filtered {
    if (statusFilter == 'all') return requests;
    return requests.where((r) => r['status'] == statusFilter).toList();
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    final reviewerId = widget.currentUser['id'] as int;
    await widget.approvalService.approveRequest(
      requestId: req['id'] as int,
      reviewedBy: reviewerId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت الموافقة وتطبيق التعديل بنجاح'),
        backgroundColor: Color(0xFF0B6B55),
      ),
    );
    _load();
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب رفض الطلب...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('رفض الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final reviewerId = widget.currentUser['id'] as int;
    await widget.approvalService.rejectRequest(
      requestId: req['id'] as int,
      reviewedBy: reviewerId,
      reason: reasonController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض الطلب وإخطار الموظف'),
        backgroundColor: Color(0xFFB42318),
      ),
    );
    _load();
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
          title: const Text('مراجعة الطلبات'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _StatusFilterBar(
                current: statusFilter,
                onChanged: (v) => setState(() => statusFilter = v),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? Center(
                    child: Text(
                      statusFilter == 'pending'
                          ? 'لا توجد طلبات معلّقة حالياً'
                          : 'لا توجد طلبات',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF05352D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _RequestCard(
                      request: filtered[i],
                      onApprove: filtered[i]['status'] == 'pending'
                          ? () => _approve(filtered[i])
                          : null,
                      onReject: filtered[i]['status'] == 'pending'
                          ? () => _reject(filtered[i])
                          : null,
                    ),
                  ),
      ),
    );
  }
}

// ── Status filter bar ──────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip('pending', 'معلّقة', Colors.orange),
        const SizedBox(width: 6),
        _chip('approved', 'مقبولة', const Color(0xFF0B6B55)),
        const SizedBox(width: 6),
        _chip('rejected', 'مرفوضة', const Color(0xFFB42318)),
        const SizedBox(width: 6),
        _chip('all', 'الكل', Colors.grey),
      ],
    );
  }

  Widget _chip(String value, String label, Color color) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Single request card ────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  final Map<String, dynamic> request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.request['status']) {
      case 'approved':
        return const Color(0xFF0B6B55);
      case 'rejected':
        return const Color(0xFFB42318);
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (widget.request['status']) {
      case 'approved':
        return 'مقبول ✓';
      case 'rejected':
        return 'مرفوض ✗';
      default:
        return 'في الانتظار ⏳';
    }
  }

  String get _requestTypeLabel {
    switch (widget.request['request_type']) {
      case 'create':
        return 'إضافة محضر جديد';
      case 'update':
        return 'تعديل محضر';
      case 'delete':
        return 'حذف محضر';
      case 'gis_add':
        return 'إضافة رسمة GIS';
      case 'gis_update':
        return 'تعديل رسمة GIS';
      default:
        return widget.request['request_type']?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final before = _parseJson(req['before_data']);
    final after = _parseJson(req['after_data']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DCC8)),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF05352D),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _requestTypeLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'من: ${req['requested_by_name'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(req['created_at']?.toString()),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                // Expand toggle
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // Rejection reason (if any)
          if (req['rejection_reason'] != null &&
              req['rejection_reason'].toString().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFB42318).withValues(alpha: 0.3)),
              ),
              child: Text(
                'سبب الرفض: ${req['rejection_reason']}',
                style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
              ),
            ),

          // Expanded diff view
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _DiffView(before: before, after: after),
            ),
          ],

          // Action buttons (only for pending)
          if (widget.onApprove != null || widget.onReject != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onReject != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                        side: const BorderSide(color: Color(0xFFB42318)),
                      ),
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('رفض'),
                    ),
                  const SizedBox(width: 10),
                  if (widget.onApprove != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0B6B55),
                      ),
                      onPressed: widget.onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('موافقة'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? _parseJson(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    try {
      return jsonDecode(v.toString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Diff view ──────────────────────────────────────────────────────────────

class _DiffView extends StatelessWidget {
  const _DiffView({this.before, this.after});

  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  @override
  Widget build(BuildContext context) {
    final allKeys = {
      ...?before?.keys,
      ...?after?.keys,
    }.toList();

    if (allKeys.isEmpty) {
      return const Text('لا توجد بيانات للمقارنة', style: TextStyle(color: Colors.grey));
    }

    return Table(
      border: TableBorder.all(color: const Color(0xFFE5DCC8), width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF05352D)),
          children: [
            _th('الحقل'),
            _th('قبل التعديل'),
            _th('بعد التعديل'),
          ],
        ),
        ...allKeys.map((key) {
          final oldVal = before?[key]?.toString() ?? '-';
          final newVal = after?[key]?.toString() ?? '-';
          final changed = oldVal != newVal;
          return TableRow(
            decoration: BoxDecoration(
              color: changed ? const Color(0xFFFFF8E1) : Colors.white,
            ),
            children: [
              _td(key, bold: true),
              _td(oldVal, color: changed ? const Color(0xFFB42318) : null),
              _td(newVal, color: changed ? const Color(0xFF0B6B55) : null),
            ],
          );
        }),
      ],
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );

  Widget _td(String text, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? const Color(0xFF2D2D2D),
            fontSize: 12,
          ),
        ),
      );
}
