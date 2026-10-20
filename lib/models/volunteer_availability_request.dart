class VolunteerAvailabilityRequest {
  final String id;
  final String requestedDate;
  final String contactName;
  final String phone;
  final String address;
  final String? timeSlot;
  final String status;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String? decisionNote;
  final AvailabilityRequestVolunteer? volunteer;

  const VolunteerAvailabilityRequest({
    required this.id,
    required this.requestedDate,
    required this.contactName,
    required this.phone,
    required this.address,
    this.timeSlot,
    required this.status,
    this.requestedAt,
    this.reviewedAt,
    this.decisionNote,
    this.volunteer,
  });

  factory VolunteerAvailabilityRequest.fromJson(Map<String, dynamic> json) {
    return VolunteerAvailabilityRequest(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      requestedDate: json['requestedDate']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      timeSlot:
          json['timeSlot']?.toString() ?? json['availableTime']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewedAt']?.toString() ?? ''),
      decisionNote: json['decisionNote']?.toString(),
      volunteer: json['volunteer'] is Map
          ? AvailabilityRequestVolunteer.fromJson(
              Map<String, dynamic>.from(json['volunteer'] as Map),
            )
          : null,
    );
  }
}

class AvailabilityRequestVolunteer {
  final String id;
  final String name;
  final String phone;
  final String place;
  final String address;

  const AvailabilityRequestVolunteer({
    required this.id,
    required this.name,
    required this.phone,
    required this.place,
    required this.address,
  });

  factory AvailabilityRequestVolunteer.fromJson(Map<String, dynamic> json) {
    return AvailabilityRequestVolunteer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Volunteer',
      phone: json['phone']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}
