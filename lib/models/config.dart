final RegExp _naturalSortPattern = RegExp(r'\d+|\D+');

String normalizeWardNumberValue(dynamic raw) {
  if (raw == null) return '';

  final text = raw.toString().trim();
  if (text.isEmpty) return '';

  final digits = RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!).join();
  if (digits.isNotEmpty) {
    return digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  }

  return text;
}

int compareNaturally(String a, String b) {
  final aParts = _naturalSortPattern
      .allMatches(a)
      .map((m) => m.group(0)!)
      .toList();
  final bParts = _naturalSortPattern
      .allMatches(b)
      .map((m) => m.group(0)!)
      .toList();
  final partsToCompare = aParts.length < bParts.length
      ? aParts.length
      : bParts.length;

  for (var i = 0; i < partsToCompare; i++) {
    final aPart = aParts[i];
    final bPart = bParts[i];
    final aNumber = int.tryParse(aPart);
    final bNumber = int.tryParse(bPart);

    if (aNumber != null && bNumber != null) {
      final numberCompare = aNumber.compareTo(bNumber);
      if (numberCompare != 0) {
        return numberCompare;
      }

      final digitLengthCompare = aPart.length.compareTo(bPart.length);
      if (digitLengthCompare != 0) {
        return digitLengthCompare;
      }

      continue;
    }

    final textCompare = aPart.toLowerCase().compareTo(bPart.toLowerCase());
    if (textCompare != 0) {
      return textCompare;
    }
  }

  final lengthCompare = aParts.length.compareTo(bParts.length);
  if (lengthCompare != 0) {
    return lengthCompare;
  }

  return a.toLowerCase().compareTo(b.toLowerCase());
}

int compareWardNumbers(String a, String b) {
  return compareNaturally(
    normalizeWardNumberValue(a),
    normalizeWardNumberValue(b),
  );
}

int compareWardConfigs(WardConfig a, WardConfig b) {
  final villageCompare = compareNaturally(a.village.trim(), b.village.trim());
  if (villageCompare != 0) {
    return villageCompare;
  }

  return compareWardNumbers(a.number, b.number);
}

List<WardConfig> sortWardConfigs(Iterable<WardConfig> wards) {
  final sorted = wards.toList()..sort(compareWardConfigs);
  return sorted;
}

class WardConfig {
  final String number;
  final String village;

  WardConfig({required this.number, required this.village});

  factory WardConfig.fromJson(Map<String, dynamic> json) {
    return WardConfig(
      number: normalizeWardNumberValue(json['number'] ?? json['title']),
      village: json['village'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'number': normalizeWardNumberValue(number), 'village': village};
  }
}

class Config {
  final String? id;
  final List<String> villages;
  final List<String> diseases;
  final List<String> plans;
  final List<WardConfig> wards;
  final List<int> workingDays;
  String volunteerAvailabilityStartTime;
  String volunteerAvailabilityEndTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Config({
    this.id,
    required this.villages,
    required this.diseases,
    required this.plans,
    required this.wards,
    required this.workingDays,
    this.volunteerAvailabilityStartTime = '09:30 AM',
    this.volunteerAvailabilityEndTime = '03:30 PM',
    this.createdAt,
    this.updatedAt,
  });

  String get volunteerAvailabilityTimeWindow {
    final start = volunteerAvailabilityStartTime.trim().isNotEmpty
        ? volunteerAvailabilityStartTime.trim()
        : '09:30 AM';
    final end = volunteerAvailabilityEndTime.trim().isNotEmpty
        ? volunteerAvailabilityEndTime.trim()
        : '03:30 PM';
    return '$start to $end';
  }

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      id: json['id'] as String?,
      villages:
          (json['villages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      diseases:
          (json['diseases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      plans:
          (json['plans'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      wards:
          (json['wards'] as List<dynamic>?)
              ?.map((e) => WardConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      workingDays:
          (json['workingDays'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()))
              .whereType<int>()
              .where((day) => day >= 1 && day <= 7)
              .toList() ??
          [1, 2, 3, 4, 5, 6],
      volunteerAvailabilityStartTime:
          json['volunteerAvailabilityStartTime']?.toString().trim().isNotEmpty ==
                  true
              ? json['volunteerAvailabilityStartTime'].toString().trim()
              : '09:30 AM',
      volunteerAvailabilityEndTime:
          json['volunteerAvailabilityEndTime']?.toString().trim().isNotEmpty ==
                  true
              ? json['volunteerAvailabilityEndTime'].toString().trim()
              : '03:30 PM',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'villages': villages,
      'diseases': diseases,
      'plans': plans,
      'wards': wards.map((e) => e.toJson()).toList(),
      'workingDays': workingDays,
      'volunteerAvailabilityStartTime': volunteerAvailabilityStartTime,
      'volunteerAvailabilityEndTime': volunteerAvailabilityEndTime,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
