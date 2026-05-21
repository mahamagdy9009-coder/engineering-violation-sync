// ============================================================
// my_requests_screen.dart
// شاشة "طلباتي" — للموظف لمتابعة حالة طلباته
// ============================================================

import 'package:flutter/material.dart';

import '../services/approval_service.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({
    super.key,
    required this.approvalService,
    required this.currentUser,
  });

  final ApprovalService approvalService;
  final Map<String, dynamic> currentUser;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final userId = widget.currentUser['id'] as int;
    final data = await widget.approvalService.getMyRequests(userId);
    if (!mounted) return;
    setState(() {
      requests = data;
      loading = false;
    });
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
          title: const Text('طلباتي'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : requests.isEmpty
                ? const Center(
                    child: Text(
                      'لم تقدم أي طلبات حتى الآن',
                      style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF05352D),
                          fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _MyRequestTile(request: requests[i]),
                  ),
      ),
    );
  }
}

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({required this.request});
  final Map<String, dynamic> request;

  Color get _statusColor {
    switch (request['status']) {
      case 'approved':
        return const Color(0xFF0B6B55);
      case 'rejected':
        return const Color(0xFFB42318);
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (request['status']) {
      case 'approved':
        return 'تمت الموافقة ✓';
      case 'rejected':
        return 'مرفوض ✗';
      default:
        return 'في انتظار المدير ⏳';
    }
  }

  String get _typeLabel {
    switch (request['request_type']) {
      case 'create':
        return 'إضافة محضر';
      case 'update':
        return 'تعديل محضر';
      case 'delete':
        return 'حذف محضر';
      case 'gis_add':
        return 'إضافة GIS';
      default:
        return request['request_type']?.toString() ?? '-';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF05352D),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _typeLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'تاريخ الإرسال: ${_formatDate(request['created_at']?.toString())}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (request['reviewed_at'] != null)
            Text(
              'تاريخ المراجعة: ${_formatDate(request['reviewed_at']?.toString())}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          if (request['rejection_reason'] != null &&
              request['rejection_reason'].toString().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'سبب الرفض: ${request['rejection_reason']}',
                style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
