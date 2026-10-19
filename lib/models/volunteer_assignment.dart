class VolunteerAssignmentPatient {
  final String? id;
  final String name;
  final int? age;
  final String? gender;
  final String address;
  final String? place;
  final String? phone;
  final List<String> disease;
  final String? locationLink;

  const VolunteerAssignmentPatient({
    this.id,
    required this.name,
    this.age,
    this.gender,
    required this.address,
    this.place,
    this.phone,
    this.disease = const [],
    this.locationLink,
  });

  factory VolunteerAssignmentPatient.fromJson(Map<String, dynamic> json) {
    return VolunteerAssignmentPatient(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'Patient',
      age: json['age'] is num ? (json['age'] as num).toInt() : null,
      gender: json['gender']?.toString(),
      address: json['address']?.toString() ?? '',
      place: json['place']?.toString(),
      phone: json['phone']?.toString(),
      disease: (json['disease'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      locationLink: json['locationLink']?.toString(),
    );
  }
}

class VolunteerAssignmentTaskDetails {
  final String title;
  final String? visitMode;
  final String? visitType;
  final String? team;
  final String? notes;
  final List<String> supportTypes;
  final String? nurseName;

  const VolunteerAssignmentTaskDetails({
    required this.title,
    this.visitMode,
    this.visitType,
    this.team,
    this.notes,
    this.supportTypes = const [],
    this.nurseName,
  });

  factory VolunteerAssignmentTaskDetails.fromJson(Map<String, dynamic> json) {
    return VolunteerAssignmentTaskDetails(
      title: json['title']?.toString() ?? 'Task',
      visitMode: json['visitMode']?.toString(),
      visitType: json['visitType']?.toString(),
      team: json['team']?.toString(),
      notes: json['notes']?.toString(),
      supportTypes: (json['supportTypes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      nurseName: json['nurseName']?.toString(),
    );
  }
}

class VolunteerAssignmentCoVolunteer {
  final String id;
  final String name;
  final String phone;
  final String? place;

  const VolunteerAssignmentCoVolunteer({
    required this.id,
    required this.name,
    required this.phone,
    this.place,
  });

  factory VolunteerAssignmentCoVolunteer.fromJson(Map<String, dynamic> json) {
    return VolunteerAssignmentCoVolunteer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      place: json['place']?.toString(),
    );
  }
}

class VolunteerAssignment {
  final String id;
  final String taskType;
  final String taskId;
  final String scheduledDate;
  final bool isToday;
  final bool isOverdue;
  final String status;
  final int pointsAwarded;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final String? notes;
  final VolunteerAssignmentPatient patient;
  final VolunteerAssignmentTaskDetails taskDetails;
  final List<VolunteerAssignmentCoVolunteer> coVolunteers;
  final bool canAccept;
  final bool canComplete;

  const VolunteerAssignment({
    required this.id,
    required this.taskType,
    required this.taskId,
    required this.scheduledDate,
    this.isToday = false,
    this.isOverdue = false,
    required this.status,
    this.pointsAwarded = 0,
    this.assignedAt,
    this.completedAt,
    this.notes,
    required this.patient,
    required this.taskDetails,
    this.coVolunteers = const [],
    this.canAccept = false,
    this.canComplete = false,
  });

  factory VolunteerAssignment.fromJson(Map<String, dynamic> json) {
    return VolunteerAssignment(
      id: json['id']?.toString() ?? '',
      taskType: json['taskType']?.toString() ?? 'home_visit',
      taskId: json['taskId']?.toString() ?? '',
      scheduledDate: json['scheduledDate']?.toString() ?? '',
      isToday: json['isToday'] == true,
      isOverdue: json['isOverdue'] == true,
      status: json['status']?.toString() ?? 'assigned',
      pointsAwarded: (json['pointsAwarded'] as num?)?.toInt() ?? 0,
      assignedAt: json['assignedAt'] != null
          ? DateTime.tryParse(json['assignedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      notes: json['notes']?.toString(),
      patient: VolunteerAssignmentPatient.fromJson(
        Map<String, dynamic>.from(json['patient'] ?? {}),
      ),
      taskDetails: VolunteerAssignmentTaskDetails.fromJson(
        Map<String, dynamic>.from(json['taskDetails'] ?? {}),
      ),
      coVolunteers: (json['coVolunteers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (c) => VolunteerAssignmentCoVolunteer.fromJson(
              Map<String, dynamic>.from(c),
            ),
          )
          .toList(),
      canAccept: json['canAccept'] == true,
      canComplete: json['canComplete'] == true,
    );
  }

  String get typeLabel {
    switch (taskType) {
      case 'home_visit':
        return 'Home Visit';
      case 'visit_assessment':
        return 'Visit Assessment';
      case 'social_support':
        return 'Social Support';
      default:
        return 'Task';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'missed':
        return 'Missed';
      default:
        return status;
    }
  }

  int get expectedPoints {
    if (pointsAwarded > 0) return pointsAwarded;
    switch (taskType) {
      case 'home_visit':
        return 10;
      case 'visit_assessment':
        return 15;
      case 'social_support':
        return 10;
      default:
        return 10;
    }
  }
}

class VolunteerLeaderboardEntry {
  final int rank;
  final String id;
  final String name;
  final String place;
  final int points;

  const VolunteerLeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    required this.place,
    required this.points,
  });

  factory VolunteerLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return VolunteerLeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}
