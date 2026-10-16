import 'package:oruma_app/models/config.dart';

class Volunteer {
  final String? id;
  final String village;
  final String ward;
  final String place;
  final String address;
  final String name;
  final String phone;
  final String phone2;
  final String email;
  final String applicationStatus;
  final DateTime? reviewedAt;
  final dynamic createdBy;
  final dynamic updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Volunteer({
    this.id,
    required this.village,
    required this.ward,
    required this.place,
    this.address = '',
    required this.name,
    required this.phone,
    this.phone2 = '',
    this.email = '',
    this.applicationStatus = 'approved',
    this.reviewedAt,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    return Volunteer(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      village: json['village']?.toString() ?? '',
      ward: normalizeWardNumberValue(json['ward']),
      place: json['place']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      phone2: json['phone2']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      applicationStatus: json['applicationStatus']?.toString() ?? 'approved',
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'].toString())
          : null,
      createdBy: json['createdBy'],
      updatedBy: json['updatedBy'],
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
      'village': village,
      'ward': normalizeWardNumberValue(ward),
      'place': place,
      'address': address,
      'name': name,
      'phone': phone,
      'phone2': phone2,
    };
  }

  Volunteer copyWith({
    String? id,
    String? village,
    String? ward,
    String? place,
    String? address,
    String? name,
    String? phone,
    String? phone2,
    String? email,
    String? applicationStatus,
    DateTime? reviewedAt,
    dynamic createdBy,
    dynamic updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Volunteer(
      id: id ?? this.id,
      village: village ?? this.village,
      ward: ward ?? this.ward,
      place: place ?? this.place,
      address: address ?? this.address,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      email: email ?? this.email,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get wardLabel => ward.isEmpty ? 'Ward' : 'Ward $ward';

  String get locationLabel {
    return [
      if (place.trim().isNotEmpty) place.trim(),
      if (village.trim().isNotEmpty) village.trim(),
      if (ward.trim().isNotEmpty) wardLabel,
    ].join(' • ');
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      name,
      phone,
      phone2,
      address,
      place,
      village,
      ward,
      wardLabel,
    ].join(' ').toLowerCase().contains(normalized);
  }
}
