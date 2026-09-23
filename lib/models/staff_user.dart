class StaffUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'staff',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  StaffUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
