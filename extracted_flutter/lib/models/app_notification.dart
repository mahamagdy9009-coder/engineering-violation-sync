class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type; // 'request_new' | 'approved' | 'rejected' | 'info'
  final int? relatedRequestId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedRequestId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'info',
      relatedRequestId: map['related_request_id'] as int?,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get typeIcon {
    switch (type) {
      case 'request_new':
        return '📋';
      case 'approved':
        return '✅';
      case 'rejected':
        return '❌';
      default:
        return 'ℹ️';
    }
  }
}
