import 'patient.dart';

/// HomeVisit model that matches the backend schema.
class HomeVisit {
  final String? id;
  final String? patientId; // Patient ObjectId
  final Patient? patientDetails; // Populated patient object from backend
  final String patientName;
  final String address;
  final String visitDate; // ISO date string
  final String visitMode; // 'monthly', 'emergency', 'new'
  final String? team;
  final String? notes;
  final List<String> volunteerIds;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HomeVisit({
    this.id,
    this.patientId,
    this.patientDetails,
    required this.patientName,
    required this.address,
    required this.visitDate,
    this.visitMode = 'new',
    this.team,
    this.notes,
    this.volunteerIds = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Create HomeVisit from JSON (API response).
  factory HomeVisit.fromJson(Map<String, dynamic> json) {
    Patient? patientObj;
    if (json['patient'] is Map) {
      patientObj = Patient.fromJson(json['patient'] as Map<String, dynamic>);
    }

    return HomeVisit(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      patientId: json['patient'] is Map ? json['patient']['_id']?.toString() : json['patient']?.toString(),
      patientDetails: patientObj,
      patientName: json['patientName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      visitDate: json['visitDate']?.toString() ?? '',
      visitMode: json['visitMode']?.toString() ?? 'new',
      team: json['team']?.toString(),
      notes: json['notes']?.toString(),
      volunteerIds: (json['volunteer_ids'] as List<dynamic>? ??
              json['volunteerIds'] as List<dynamic>? ??
              const [])
          .map((e) => e.toString())
          .toList(),
      createdBy: json['createdBy'] is Map
          ? json['createdBy']['name']?.toString()
          : json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  /// Convert HomeVisit to JSON for API requests.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'patientName': patientName,
      'address': address,
      'visitDate': visitDate,
      'visitMode': visitMode,
      'volunteerIds': volunteerIds,
    };
    if (patientId != null && patientId!.isNotEmpty) {
      map['patient'] = patientId;
    }
    if (team != null && team!.isNotEmpty) {
      map['team'] = team;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }
    return map;
  }

  /// Create a copy with updated fields.
  HomeVisit copyWith({
    String? id,
    String? patientId,
    Patient? patientDetails,
    String? patientName,
    String? address,
    String? visitDate,
    String? visitMode,
    String? team,
    String? notes,
    List<String>? volunteerIds,
  }) {
    return HomeVisit(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientDetails: patientDetails ?? this.patientDetails,
      patientName: patientName ?? this.patientName,
      address: address ?? this.address,
      visitDate: visitDate ?? this.visitDate,
      visitMode: visitMode ?? this.visitMode,
      team: team ?? this.team,
      notes: notes ?? this.notes,
      volunteerIds: volunteerIds ?? this.volunteerIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() {
    return 'HomeVisit(id: $id, patientName: $patientName, visitDate: $visitDate, visitMode: $visitMode, team: $team)';
  }
}
