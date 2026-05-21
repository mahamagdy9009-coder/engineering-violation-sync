enum RequestType { create, update, delete, gisAdd, gisUpdate, gisDelete }

enum RequestStatus { pending, approved, rejected }

class PendingRequest {
  final int id;
  final String requestType;
  final String targetTable;
  final int? targetId;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;
  final int requestedBy;
  final String requestedByName;
  final String? reviewedByName;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const PendingRequest({
    required this.id,
    required this.requestType,
    required this.targetTable,
    this.targetId,
    this.beforeData,
    this.afterData,
    required this.requestedBy,
    required this.requestedByName,
    this.reviewedByName,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get requestTypeLabel {
    switch (requestType) {
      case 'create':
        return 'إضافة جديدة';
      case 'update':
        return 'طلب تعديل';
      case 'delete':
        return 'طلب حذف';
      case 'gis_add':
        return 'إضافة GIS';
      case 'gis_update':
        return 'تعديل GIS';
      case 'gis_delete':
        return 'حذف GIS';
      default:
        return requestType;
    }
  }

  String get targetTableLabel {
    switch (targetTable) {
      case 'criminal_cases':
        return 'المحاضر الجنائية';
      case 'gis_drawings':
        return 'رسومات GIS';
      default:
        return targetTable;
    }
  }

  factory PendingRequest.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parseJson(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      try {
        import 'dart:convert';
        return jsonDecode(v.toString()) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    return PendingRequest(
      id: map['id'] as int,
      requestType: map['request_type']?.toString() ?? '',
      targetTable: map['target_table']?.toString() ?? '',
      targetId: map['target_id'] as int?,
      beforeData: parseJson(map['before_data']),
      afterData: parseJson(map['after_data']),
      requestedBy: map['requested_by'] as int,
      requestedByName: map['requested_by_name']?.toString() ?? '-',
      reviewedByName: map['reviewed_by_name']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      rejectionReason: map['rejection_reason']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'].toString())
          : null,
    );
  }
}
