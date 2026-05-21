// ============================================================
// gis_approval_screen.dart
// شاشة مراجعة طلبات GIS — للمدير فقط
// تُعرض الرسومات المعلّقة ويمكن الموافقة عليها أو رفضها
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/approval_service.dart';

class GisApprovalScreen extends StatefulWidget {
  const GisApprovalScreen({
    super.key,
    required this.approvalService,
    required this.currentUser,
  });

  final ApprovalService approvalService;
  final Map<String, dynamic> currentUser;

  @override
  State<GisApprovalScreen> createState() => _GisApprovalScreenState();
}

class _GisApprovalScreenState extends State<GisApprovalScreen> {
  List<Map<String, dynamic>> gisRequests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final all = await widget.approvalService.getPendingRequests();
    final gis = all
        .where((r) =>
            r['target_table'] == 'gis_drawings' && r['status'] == 'pending')
        .toList();
    if (!mounted) return;
    setState(() {
      gisRequests = gis;
      loading = false;
    });
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    await widget.approvalService.approveRequest(
      requestId: req['id'] as int,
      reviewedBy: widget.currentUser['id'] as int,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت الموافقة — الرسمة ظاهرة الآن على الخريطة'),
        backgroundColor: Color(0xFF0B6B55),
      ),
    );
    _load();
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سبب رفض رسمة GIS'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب الرفض...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await widget.approvalService.rejectRequest(
      requestId: req['id'] as int,
      reviewedBy: widget.currentUser['id'] as int,
      reason: ctrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض طلب GIS وإخطار الموظف'),
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
          title: Text(
            'مراجعة طلبات GIS ${gisRequests.isEmpty ? "" : "(${gisRequests.length})"}',
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : gisRequests.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد طلبات GIS معلّقة',
                      style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF05352D),
                          fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: gisRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _GisRequestCard(
                      request: gisRequests[i],
                      onApprove: () => _approve(gisRequests[i]),
                      onReject: () => _reject(gisRequests[i]),
                    ),
                  ),
      ),
    );
  }
}

class _GisRequestCard extends StatefulWidget {
  const _GisRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_GisRequestCard> createState() => _GisRequestCardState();
}

class _GisRequestCardState extends State<_GisRequestCard> {
  bool _showMap = false;

  Map<String, dynamic>? get _afterData {
    try {
      final v = widget.request['after_data'];
      if (v == null) return null;
      return jsonDecode(v.toString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<LatLng> _parsePoints(String? geojson) {
    if (geojson == null || geojson.isEmpty) return [];
    try {
      final obj = jsonDecode(geojson) as Map<String, dynamic>;
      final geometry = obj['geometry'] as Map<String, dynamic>? ?? obj;
      final coords = geometry['coordinates'];
      List<dynamic> raw = [];
      final type = geometry['type'] as String? ?? '';
      if (type == 'LineString') raw = coords as List;
      if (type == 'Polygon') raw = (coords as List).first as List;
      return raw
          .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final after = _afterData;
    final points = _parsePoints(after?['geojson'] as String?);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF05352D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    after?['name'] ?? 'رسمة GIS',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                Text(
                  'من: ${widget.request['requested_by_name'] ?? '-'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                if (after?['projectType'] != null && after!['projectType'].toString().isNotEmpty)
                  _chip('نوع المشروع', after['projectType'].toString()),
                if (after?['offenderName'] != null && after!['offenderName'].toString().isNotEmpty)
                  _chip('المخالف', after['offenderName'].toString()),
                if (after?['reportNumber'] != null && after!['reportNumber'].toString().isNotEmpty)
                  _chip('رقم المحضر', after['reportNumber'].toString()),
                if (after?['description'] != null && after!['description'].toString().isNotEmpty)
                  _chip('الوصف', after['description'].toString()),
                _chip('عدد النقاط', '${points.length} نقطة'),
              ],
            ),
          ),

          // Map preview toggle
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextButton.icon(
                onPressed: () => setState(() => _showMap = !_showMap),
                icon: Icon(_showMap ? Icons.map : Icons.map_outlined,
                    color: const Color(0xFF0B6B55)),
                label: Text(
                  _showMap ? 'إخفاء الخريطة' : 'معاينة على الخريطة',
                  style: const TextStyle(color: Color(0xFF0B6B55)),
                ),
              ),
            ),

          if (_showMap && points.isNotEmpty)
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt0.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: const Color(0xFFE5C07B),
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: points.first,
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6B55),
                  ),
                  onPressed: widget.onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('اعتماد — تظهر على الخريطة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF05352D))),
      ],
    );
  }
}
