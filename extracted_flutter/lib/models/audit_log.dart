class AuditLog {
  final int id;
  final int userId;
  final String userName;
  final String operation; // 'create' | 'update' | 'delete' | 'approve' | 'reject' | 'login'
  final String targetTable;
  final int? targetId;
  final String? beforeData;
  final String? afterData;
  final String? deviceInfo;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.operation,
    required this.targetTable,
    this.targetId,
    this.beforeData,
    this.afterData,
    this.deviceInfo,
    required this.createdAt,
  });

  String get operationLabel {
    switch (operation) {
      case 'create':
        return 'إضافة';
      case 'update':
        return 'تعديل';
      case 'delete':
        return 'حذف';
      case 'approve':
        return 'اعتماد';
      case 'reject':
        return 'رفض';
      case 'login':
        return 'تسجيل دخول';
      default:
        return operation;
    }
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      userName: map['user_name']?.toString() ?? '-',
      operation: map['operation']?.toString() ?? '',
      targetTable: map['target_table']?.toString() ?? '',
      targetId: map['target_id'] as int?,
      beforeData: map['before_data']?.toString(),
      afterData: map['after_data']?.toString(),
      deviceInfo: map['device_info']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
