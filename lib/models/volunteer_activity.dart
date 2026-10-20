class VolunteerActivityItem {
  const VolunteerActivityItem({
    required this.id,
    required this.givenAt,
    required this.supportTypes,
    required this.patientName,
    this.patientRegisterId,
    this.place,
    this.note,
    this.points = 0,
    this.taskType,
  });

  final String id;
  final DateTime givenAt;
  final List<String> supportTypes;
  final String patientName;
  final String? patientRegisterId;
  final String? place;
  final String? note;
  final int points;
  final String? taskType;

  factory VolunteerActivityItem.fromJson(Map<String, dynamic> json) {
    return VolunteerActivityItem(
      id: json['id']?.toString() ?? '',
      givenAt:
          DateTime.tryParse(json['givenAt']?.toString() ?? '') ??
          DateTime.now(),
      supportTypes: (json['supportTypes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      patientName: json['patientName']?.toString() ?? 'Patient',
      patientRegisterId: json['patientRegisterId']?.toString(),
      place: json['place']?.toString(),
      note: json['note']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      taskType: json['taskType']?.toString(),
    );
  }
}

class VolunteerActivity {
  const VolunteerActivity({
    required this.totalSocialWorks,
    required this.totalPoints,
    required this.achievementTier,
    required this.history,
    this.nextTierAt,
    this.currentTierMinPoints,
    this.nextTierName,
    this.joinedAt,
  });

  final int totalSocialWorks;
  final int totalPoints;
  final String achievementTier;
  final int? nextTierAt;
  final int? currentTierMinPoints;
  final String? nextTierName;
  final DateTime? joinedAt;
  final List<VolunteerActivityItem> history;

  factory VolunteerActivity.fromJson(Map<String, dynamic> json) {
    final works = (json['totalSocialWorks'] as num?)?.toInt() ?? 0;
    final points = (json['totalPoints'] as num?)?.toInt() ?? 0;
    return VolunteerActivity(
      totalSocialWorks: works,
      totalPoints: points,
      achievementTier: json['achievementTier']?.toString() ?? 'New Volunteer',
      nextTierAt: (json['nextTierAt'] as num?)?.toInt(),
      currentTierMinPoints: (json['currentTierMinPoints'] as num?)?.toInt(),
      nextTierName: json['nextTierName']?.toString(),
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? ''),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                VolunteerActivityItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}
