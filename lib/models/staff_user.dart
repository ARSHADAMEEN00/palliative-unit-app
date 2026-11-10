import 'package:oruma_app/models/ward.dart';

class StaffUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> permittedModuleIds;
  final bool hasExplicitModulePermissions;
  final List<Ward> assignedWards;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.permittedModuleIds = const [],
    this.hasExplicitModulePermissions = false,
    this.assignedWards = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'staff',
      permittedModuleIds:
          (json['permittedModuleIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      hasExplicitModulePermissions: json.containsKey('permittedModuleIds'),
      assignedWards: (json['assignedWards'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Ward.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  StaffUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    List<String>? permittedModuleIds,
    bool? hasExplicitModulePermissions,
    List<Ward>? assignedWards,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      permittedModuleIds: permittedModuleIds ?? this.permittedModuleIds,
      hasExplicitModulePermissions:
          hasExplicitModulePermissions ?? this.hasExplicitModulePermissions,
      assignedWards: assignedWards ?? this.assignedWards,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
