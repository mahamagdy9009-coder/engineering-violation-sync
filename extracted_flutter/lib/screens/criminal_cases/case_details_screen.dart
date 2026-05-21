import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../gis/screens/gis_screen.dart';
import '../../services/attachment_service.dart';
import '../violation_sheet/violation_sheet_screen.dart';

class CaseDetailsScreen extends StatelessWidget {
  const CaseDetailsScreen({
    super.key,
    required this.item,
    required this.filterOptions,
    this.currentUser,
    this.onRequestSaved,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? currentUser;
  final Map<String, List<Map<String, dynamic>>> filterOptions;
  final VoidCallback? onRequestSaved;

  void _openOnMap(BuildContext context) {
    final lat = _parseDouble(item['gis_lat']);
    final lng = _parseDouble(item['gis_lng']);
    final drainName = _text(item['drain_name'], '');
    final kilometer = _text(item['kilometer_location'], '');

    LatLng? center;

    if (lat != null && lng != null) {
      center = LatLng(lat, lng);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GisScreen(
          initialCenter: center,
          initialZoom: center != null ? 16.0 : null,
          jumpToDrainName:
              drainName.isNotEmpty ? drainName : null,
          initialKilometer:
              kilometer.isNotEmpty ? kilometer : null,
        ),
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ViolationSheetScreen(
          mode: ViewMode.edit,
          caseData: item,
          currentUser: currentUser,
        ),
      ),
    );

    if (saved == true) {
      onRequestSaved?.call();
    }
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
            'صحيفة المخالف - ${_text(item['offender_name'], 'بدون اسم')}',
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side:
                      const BorderSide(color: Colors.white38),
                ),
                onPressed: () => _openOnMap(context),
                icon: const Icon(
                  Icons.map_outlined,
                  size: 18,
                ),
                label: const Text('عرض على الخريطة'),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                onPressed: () =>
                    _openEditSheet(context),
                icon: const Icon(Icons.edit),
                label:
                    const Text('تقديم تعديل للمدير'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_hasGisData())
                _GisLocationCard(
                  item: item,
                  onOpenMap: () =>
                      _openOnMap(context),
                ),

              if (_hasGisData())
                const SizedBox(height: 18),

              _Section(
                title: 'البيانات الأساسية',
                icon: Icons.assignment_outlined,
                children: [
                  _Field(
                      'اسم المخالف',
                      item['offender_name']),
                  _Field(
                      'الرقم القومي',
                      item['offender_national_id']),
                  _Field(
                      'رقم المحضر',
                      item['report_number']),
                  _Field(
                      'سنة المحضر',
                      item['report_year']),
                  _Field(
                      'تاريخ المحضر',
                      item['report_date']),
                  _Field(
                    'رقم قرار الإزالة',
                    item['removal_decision_number'],
                  ),
                  _Field(
                      'الرقم القضائي',
                      item['judicial_number']),
                  _Field(
                      'اسم المصرف',
                      item['drain_name']),
                  _Field(
                    'الموقع الكيلومتري',
                    item['kilometer_location'],
                  ),
                  _Field(
                    'نوع المخالفة',
                    item['violation_type'],
                  ),
                  _Field(
                    'المساحة',
                    _number(item['area']),
                  ),
                  _Field(
                    'اسم الملاحظ',
                    item['observer_name'],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _Section(
                title: 'الموقف والإجراءات',
                icon: Icons.fact_check_outlined,
                children: [
                  _Field(
                      'موقف المحضر',
                      item['case_status']),
                  _Field(
                      'تاريخ الإزالة',
                      item['removal_date']),
                  _Field(
                    'موقف الحجز الإداري',
                    item['admin_seizure_status'],
                  ),
                  _Field(
                    'موقف التبديد',
                    item['dissipation_status'],
                  ),
                  _Field(
                    'الموقف من السداد',
                    item['payment_status'],
                  ),
                  _Field(
                    'مصدر البيانات',
                    item['source_sheet'],
                  ),
                  _Field(
                    'رقم الصف في Excel',
                    item['source_row'],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _Section(
                title: 'الحسابات والمستحقات',
                icon: Icons.calculate_outlined,
                children: [
                  _Field(
                    'قيمة المحضر',
                    _money(item['report_value']),
                  ),
                  _Field(
                    '+47%',
                    _money(item['percent_47_value']),
                  ),
                  _Field(
                    'قيمة رد الشيء لأصله',
                    _money(item['restoration_value']),
                  ),
                  _Field(
                    'قيمة مقابل الانتفاع',
                    _money(item['usufruct_value']),
                  ),
                  _Field(
                    'قيمة الحجز الإداري',
                    _money(item['admin_seizure_value']),
                  ),
                  _Field(
                    'إجمالي المستحقات',
                    _money(item['total_dues']),
                  ),
                  _Field(
                    'ما تم سداده',
                    _money(item['paid_amount']),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _AttachmentsSection(item: item),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasGisData() {
    return item['gis_lat'] != null ||
        item['gis_lng'] != null;
  }

  static String _text(dynamic value,
      [String fallback = '-']) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  static String _number(dynamic value) {
    if (value == null) return '-';

    final number =
        num.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return number.toString();
  }

  static String _money(dynamic value) {
    if (value == null) return '-';

    final number =
        num.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return '${number.toStringAsFixed(2)} جنيه';
  }
}

class _AttachmentsSection extends StatefulWidget {
  final Map<String, dynamic> item;

  const _AttachmentsSection({required this.item});

  @override
  State<_AttachmentsSection> createState() =>
      _AttachmentsSectionState();
}

class _AttachmentsSectionState
    extends State<_AttachmentsSection> {

  List<AttachmentRecord> attachments = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadAttachments();
  }

  Future<void> loadAttachments() async {
    final caseId = widget.item['id'];

    if (caseId == null) {
      setState(() => loading = false);
      return;
    }

    final data =
        await AttachmentService.instance
            .getForCase(caseId);

    if (!mounted) return;

    setState(() {
      attachments = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'المرفقات',
      icon: Icons.attach_file,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),

        if (!loading && attachments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('لا توجد مرفقات'),
          ),

        ...attachments.map((a) {
          return Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE5DCC8),
              ),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(8),
                    child: Image.file(
                      File(a.filePath),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) {
                        return Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image,
                            size: 50,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  a.typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  a.fileName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 10),

                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child:
                            InteractiveViewer(
                          child: Image.file(
                            File(a.filePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                  icon:
                      const Icon(Icons.zoom_in),
                  label:
                      const Text('عرض مكبر'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _GisLocationCard extends StatelessWidget {
  const _GisLocationCard({
    required this.item,
    required this.onOpenMap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF05352D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: Colors.amber,
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'يوجد موقع جغرافي مرتبط بالمحضر',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          FilledButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(Icons.map),
            label: const Text('فتح الخريطة'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE5DCC8),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF0B6B55),
              ),

              const SizedBox(width: 10),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF05352D),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.title, this.value);

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7F3),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE5DCC8),
              ),
            ),
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}