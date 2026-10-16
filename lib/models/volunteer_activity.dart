class VolunteerActivityItem {
  const VolunteerActivityItem({
    required this.id,
    required this.givenAt,
    required this.supportTypes,
    required this.patientName,
    this.patientRegisterId,
    this.place,
    this.note,
  });

  final String id;
  final DateTime givenAt;
  final List<String> supportTypes;
  final String patientName;
  final String? patientRegisterId;
  final String? place;
  final String? note;

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
    );
  }
}

class VolunteerActivity {
  const VolunteerActivity({
    required this.totalSocialWorks,
    required this.achievementTier,
    required this.history,
    this.nextTierAt,
  });

  final int totalSocialWorks;
  final String achievementTier;
  final int? nextTierAt;
  final List<VolunteerActivityItem> history;

  factory VolunteerActivity.fromJson(Map<String, dynamic> json) {
    return VolunteerActivity(
      totalSocialWorks: (json['totalSocialWorks'] as num?)?.toInt() ?? 0,
      achievementTier: json['achievementTier']?.toString() ?? 'New Volunteer',
      nextTierAt: (json['nextTierAt'] as num?)?.toInt(),
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
