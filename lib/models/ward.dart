class Ward {
  const Ward({
    required this.id,
    required this.name,
    this.code,
    this.localBody,
    this.lsgWardValue,
    this.managedByLsg = false,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? code;
  final String? localBody;
  final String? lsgWardValue;
  final bool managedByLsg;
  final bool isActive;

  String get label {
    final value = code?.trim();
    return value == null || value.isEmpty ? name : '$name ($value)';
  }

  String get fullLabel {
    final body = localBody?.trim();
    return body == null || body.isEmpty ? label : '$body • $label';
  }

  factory Ward.fromJson(Map<String, dynamic> json) => Ward(
    id: (json['id'] ?? json['_id'] ?? '').toString(),
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString(),
    localBody: json['localBody']?.toString(),
    lsgWardValue: json['lsgWardValue']?.toString(),
    managedByLsg: json['managedByLsg'] == true,
    isActive: json['isActive'] != false,
  );
}

class PatientWardHistoryEntry {
  const PatientWardHistoryEntry({
    required this.id,
    required this.toWard,
    required this.changedAt,
    this.fromWard,
    this.changedByName,
    this.note,
  });

  final String id;
  final Ward? fromWard;
  final Ward toWard;
  final String? changedByName;
  final DateTime changedAt;
  final String? note;

  factory PatientWardHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawFrom = json['fromWard'];
    final rawTo = json['toWard'];
    final changedBy = json['changedBy'];
    return PatientWardHistoryEntry(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      fromWard: rawFrom is Map
          ? Ward.fromJson(Map<String, dynamic>.from(rawFrom))
          : null,
      toWard: Ward.fromJson(
        rawTo is Map ? Map<String, dynamic>.from(rawTo) : const {},
      ),
      changedByName: changedBy is Map ? changedBy['name']?.toString() : null,
      changedAt:
          DateTime.tryParse(json['changedAt']?.toString() ?? '') ??
          DateTime(1970),
      note: json['note']?.toString(),
    );
  }
}

class WardPatientCount {
  const WardPatientCount({
    required this.total,
    required this.active,
    this.ward,
  });

  final Ward? ward;
  final int total;
  final int active;

  factory WardPatientCount.fromJson(Map<String, dynamic> json) =>
      WardPatientCount(
        ward: json['ward'] is Map
            ? Ward.fromJson(Map<String, dynamic>.from(json['ward']))
            : null,
        total: int.tryParse(json['total']?.toString() ?? '') ?? 0,
        active: int.tryParse(json['active']?.toString() ?? '') ?? 0,
      );
}
