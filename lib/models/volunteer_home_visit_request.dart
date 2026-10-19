class VolunteerHomeVisitRequest {
  final String id;
  final String status;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String? decisionNote;
  final VolunteerRequestVisit? homeVisit;
  final VolunteerRequestVolunteer? volunteer;

  const VolunteerHomeVisitRequest({
    required this.id,
    required this.status,
    this.requestedAt,
    this.reviewedAt,
    this.decisionNote,
    this.homeVisit,
    this.volunteer,
  });

  factory VolunteerHomeVisitRequest.fromJson(Map<String, dynamic> json) {
    return VolunteerHomeVisitRequest(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewedAt']?.toString() ?? ''),
      decisionNote: json['decisionNote']?.toString(),
      homeVisit: json['homeVisit'] is Map
          ? VolunteerRequestVisit.fromJson(
              Map<String, dynamic>.from(json['homeVisit'] as Map),
            )
          : null,
      volunteer: json['volunteer'] is Map
          ? VolunteerRequestVolunteer.fromJson(
              Map<String, dynamic>.from(json['volunteer'] as Map),
            )
          : null,
    );
  }
}

class VolunteerRequestVisit {
  final String id;
  final String patientName;
  final String address;
  final String visitDate;
  final String visitMode;

  const VolunteerRequestVisit({
    required this.id,
    required this.patientName,
    required this.address,
    required this.visitDate,
    required this.visitMode,
  });

  factory VolunteerRequestVisit.fromJson(Map<String, dynamic> json) {
    return VolunteerRequestVisit(
      id: json['id']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? 'Patient',
      address: json['address']?.toString() ?? '',
      visitDate: json['visitDate']?.toString() ?? '',
      visitMode: json['visitMode']?.toString() ?? 'new',
    );
  }
}

class VolunteerRequestVolunteer {
  final String id;
  final String name;
  final String phone;
  final String place;

  const VolunteerRequestVolunteer({
    required this.id,
    required this.name,
    required this.phone,
    required this.place,
  });

  factory VolunteerRequestVolunteer.fromJson(Map<String, dynamic> json) {
    return VolunteerRequestVolunteer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Volunteer',
      phone: json['phone']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
    );
  }
}
