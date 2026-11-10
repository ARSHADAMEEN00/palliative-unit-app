import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/ward.dart';

class PatientUnitRegistration {
  const PatientUnitRegistration({
    required this.unitId,
    required this.registerId,
    this.activeFrom,
    this.activeUntil,
    this.transferRequestId,
  });

  final String unitId;
  final String registerId;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  final String? transferRequestId;

  factory PatientUnitRegistration.fromJson(Map<String, dynamic> json) {
    return PatientUnitRegistration(
      unitId: json['unitId']?.toString() ?? '',
      registerId: json['registerId']?.toString() ?? '',
      activeFrom: DateTime.tryParse(json['activeFrom']?.toString() ?? ''),
      activeUntil: DateTime.tryParse(json['activeUntil']?.toString() ?? ''),
      transferRequestId: json['transferRequestId']?.toString(),
    );
  }
}

/// Patient model that matches the backend schema.
class Patient {
  final String? id;
  final String name;
  final String relation;
  final String gender;
  final String address;
  final String phone;
  final String? phone2;
  final String? caregiverName;
  final int age;
  final String place;
  final String village;
  final String? ward;
  final String? currentWardId;
  final Ward? currentWard;
  final List<String> disease;
  final String plan;
  final String? locationLink;
  final String? volunteerId;
  final String? volunteerName;
  final String? volunteerContact;
  final String? registerId;
  final DateTime? registrationDate; // User-controlled registration date
  final bool isDead;
  final DateTime? dateOfDeath;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String transferStatus;
  final String? careJourneyId;
  final String? previousUnitId;
  final String? currentTransferRequestId;
  final List<PatientUnitRegistration> unitRegistrationHistory;

  const Patient({
    this.id,
    required this.name,
    required this.relation,
    required this.gender,
    required this.address,
    this.phone = '',
    this.phone2,
    this.caregiverName,
    required this.age,
    required this.place,
    required this.village,
    this.ward,
    this.currentWardId,
    this.currentWard,
    this.disease = const [],
    required this.plan,
    this.locationLink,
    this.volunteerId,
    this.volunteerName,
    this.volunteerContact,
    this.registerId,
    this.registrationDate,
    this.isDead = false,
    this.dateOfDeath,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.transferStatus = 'ACTIVE',
    this.careJourneyId,
    this.previousUnitId,
    this.currentTransferRequestId,
    this.unitRegistrationHistory = const [],
  });

  /// Create Patient from JSON (API response).
  factory Patient.fromJson(Map<String, dynamic> json) {
    final normalizedWard = normalizeWardNumberValue(json['ward']);

    return Patient(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      relation: json['relation']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      phone2: json['phone2']?.toString(),
      caregiverName: json['caregiverName']?.toString(),
      age: (json['age'] is int)
          ? json['age'] as int
          : int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      place: json['place']?.toString() ?? '',
      village: json['village']?.toString() ?? '',
      ward: normalizedWard.isEmpty ? null : normalizedWard,
      currentWardId: _getId(json['currentWardId']),
      currentWard: json['currentWard'] is Map
          ? Ward.fromJson(Map<String, dynamic>.from(json['currentWard']))
          : json['currentWardId'] is Map
          ? Ward.fromJson(Map<String, dynamic>.from(json['currentWardId']))
          : null,
      disease: json['disease'] is List
          ? List<String>.from(json['disease'])
          : json['disease'] != null
          ? [json['disease'].toString()]
          : [],
      plan: json['plan']?.toString() ?? '',
      locationLink: json['locationLink']?.toString(),
      volunteerId: _getId(json['volunteerId']),
      volunteerName: json['volunteerName']?.toString(),
      volunteerContact: json['volunteerContact']?.toString(),
      registerId: json['registerId']?.toString(),
      registrationDate: json['registrationDate'] != null
          ? DateTime.tryParse(json['registrationDate'].toString())
          : null,
      isDead: json['isDead'] == true,
      dateOfDeath: json['dateOfDeath'] != null
          ? DateTime.tryParse(json['dateOfDeath'].toString())
          : null,
      createdBy: json['createdBy'] is Map
          ? json['createdBy']['name']?.toString()
          : json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      transferStatus:
          json['transferStatus']?.toString().toUpperCase() ?? 'ACTIVE',
      careJourneyId: _getId(json['careJourneyId']),
      previousUnitId: _getId(json['previousUnitId']),
      currentTransferRequestId: _getId(json['currentTransferRequestId']),
      unitRegistrationHistory:
          (json['unitRegistrationHistory'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => PatientUnitRegistration.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
    );
  }

  /// Convert Patient to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relation': relation,
      'gender': gender,
      'address': address,
      'phone': phone,
      'phone2': phone2,
      'caregiverName': caregiverName,
      'age': age,
      'place': place,
      'village': village,
      'ward': ward == null ? null : normalizeWardNumberValue(ward),
      'currentWardId': currentWardId,
      'disease': disease,
      'plan': plan,
      'locationLink': locationLink,
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'volunteerContact': volunteerContact,
      'registerId': registerId,
      'registrationDate': registrationDate?.toIso8601String(),
      'isDead': isDead,
      'dateOfDeath': dateOfDeath?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields.
  Patient copyWith({
    String? id,
    String? name,
    String? relation,
    String? gender,
    String? address,
    String? phone,
    String? phone2,
    String? caregiverName,
    int? age,
    String? place,
    String? village,
    String? ward,
    String? currentWardId,
    Ward? currentWard,
    List<String>? disease,
    String? plan,
    String? locationLink,
    String? volunteerId,
    String? volunteerName,
    String? volunteerContact,
    String? registerId,
    DateTime? registrationDate,
    bool? isDead,
    DateTime? dateOfDeath,
    String? transferStatus,
    String? careJourneyId,
    String? previousUnitId,
    String? currentTransferRequestId,
    List<PatientUnitRegistration>? unitRegistrationHistory,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      caregiverName: caregiverName ?? this.caregiverName,
      age: age ?? this.age,
      place: place ?? this.place,
      village: village ?? this.village,
      ward: ward ?? this.ward,
      currentWardId: currentWardId ?? this.currentWardId,
      currentWard: currentWard ?? this.currentWard,
      disease: disease ?? this.disease,
      plan: plan ?? this.plan,
      locationLink: locationLink ?? this.locationLink,
      volunteerId: volunteerId ?? this.volunteerId,
      volunteerName: volunteerName ?? this.volunteerName,
      volunteerContact: volunteerContact ?? this.volunteerContact,
      registerId: registerId ?? this.registerId,
      registrationDate: registrationDate ?? this.registrationDate,
      isDead: isDead ?? this.isDead,
      dateOfDeath: dateOfDeath ?? this.dateOfDeath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      transferStatus: transferStatus ?? this.transferStatus,
      careJourneyId: careJourneyId ?? this.careJourneyId,
      previousUnitId: previousUnitId ?? this.previousUnitId,
      currentTransferRequestId:
          currentTransferRequestId ?? this.currentTransferRequestId,
      unitRegistrationHistory:
          unitRegistrationHistory ?? this.unitRegistrationHistory,
    );
  }

  @override
  String toString() {
    return 'Patient(id: $id, name: $name, village: $village, disease: $disease)';
  }

  static String? _getId(dynamic field) {
    if (field == null) return null;
    if (field is String) return field;
    if (field is Map && field['_id'] != null) return field['_id'].toString();
    if (field is Map && field['id'] != null) return field['id'].toString();
    return field.toString();
  }
}

class PatientCounts {
  final int allCount;
  final int deadCount;
  final int aliveCount;

  PatientCounts({
    required this.allCount,
    required this.deadCount,
    required this.aliveCount,
  });

  factory PatientCounts.fromJson(Map<String, dynamic> json) {
    return PatientCounts(
      allCount: json['allCount'] as int? ?? 0,
      deadCount: json['deadCount'] as int? ?? 0,
      aliveCount: json['aliveCount'] as int? ?? 0,
    );
  }
}

class PatientListResponse {
  final List<Patient> patients;
  final PatientCounts counts;

  PatientListResponse({required this.patients, required this.counts});

  factory PatientListResponse.fromJson(Map<String, dynamic> json) {
    return PatientListResponse(
      patients:
          (json['patients'] as List<dynamic>?)
              ?.map((e) => Patient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      counts: PatientCounts.fromJson(
        json['counts'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
