const socialSupportTypeLabels = {
  'ration_kit': 'Ration Kit',
  'vegetables': 'Vegetables',
  'medicine': 'Medicine',
};

class SocialSupport {
  final String? id;
  final dynamic patientId;
  final dynamic volunteerId;
  final List<String> supportTypes;
  final DateTime givenAt;
  final String? note;
  final String volunteerName;
  final String volunteerContact;
  final dynamic createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SocialSupport({
    this.id,
    required this.patientId,
    this.volunteerId,
    required this.supportTypes,
    required this.givenAt,
    this.note,
    required this.volunteerName,
    required this.volunteerContact,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory SocialSupport.fromJson(Map<String, dynamic> json) {
    return SocialSupport(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      patientId: json['patientId'],
      volunteerId: json['volunteerId'],
      supportTypes: (json['supportTypes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      givenAt: json['givenAt'] != null
          ? DateTime.tryParse(json['givenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: json['note']?.toString(),
      volunteerName: json['volunteerName']?.toString() ?? '',
      volunteerContact: json['volunteerContact']?.toString() ?? '',
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': _getId(patientId),
      'volunteerId': _getId(volunteerId),
      'supportTypes': supportTypes,
      'givenAt': givenAt.toIso8601String(),
      'note': note,
      'volunteerName': volunteerName,
      'volunteerContact': volunteerContact,
    };
  }

  static String? _getId(dynamic field) {
    if (field == null) return null;
    if (field is String) return field;
    if (field is Map && field['_id'] != null) return field['_id'].toString();
    if (field is Map && field['id'] != null) return field['id'].toString();
    return field.toString();
  }

  String get patientObjectId => _getId(patientId) ?? '';

  String get volunteerObjectId => _getId(volunteerId) ?? '';

  String get patientName {
    if (patientId is Map) return patientId['name']?.toString() ?? 'Unknown';
    return 'Unknown';
  }

  String? get patientRegisterId {
    if (patientId is Map) return patientId['registerId']?.toString();
    return null;
  }

  String? get patientPhone {
    if (patientId is Map) return patientId['phone']?.toString();
    return null;
  }

  String? get patientPlace {
    if (patientId is Map) return patientId['place']?.toString();
    return null;
  }

  String get supportTypesLabel {
    return supportTypes
        .map((type) => socialSupportTypeLabels[type] ?? type)
        .join(', ');
  }
}
