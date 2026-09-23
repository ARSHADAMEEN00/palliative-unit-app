class AppNotification {
  final String? id;
  final String? unitId;
  final String type;
  final String title;
  final String message;
  final String status;
  final String severity;
  final String? entityType;
  final String? entityId;
  final DateTime? triggeredAt;
  final DateTime? readAt;
  final DateTime? resolvedAt;
  final Map<String, dynamic> metadata;

  const AppNotification({
    this.id,
    this.unitId,
    required this.type,
    required this.title,
    required this.message,
    this.status = 'active',
    this.severity = 'info',
    this.entityType,
    this.entityId,
    this.triggeredAt,
    this.readAt,
    this.resolvedAt,
    this.metadata = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      unitId: json['unitId']?.toString(),
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      severity: json['severity']?.toString() ?? 'info',
      entityType: json['entityType']?.toString(),
      entityId: json['entityId']?.toString(),
      triggeredAt: _parseDate(json['triggeredAt'] ?? json['createdAt']),
      readAt: _parseDate(json['readAt']),
      resolvedAt: _parseDate(json['resolvedAt']),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
