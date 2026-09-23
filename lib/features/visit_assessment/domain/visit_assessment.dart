class VisitVitals {
  final int? pulse;
  final String pulseRhythm;
  final int? bpSystolic;
  final int? bpDiastolic;
  final String bpPosition;
  final int? respiratoryRate;
  final String respiratoryRhythm;
  final double? temperature;
  final String temperatureUnit;
  final String temperatureMethod;
  final int? spo2;
  final int? grbs;
  final String activityLevel;
  final String stability;

  const VisitVitals({
    this.pulse = 72,
    this.pulseRhythm = 'R',
    this.bpSystolic = 120,
    this.bpDiastolic = 80,
    this.bpPosition = 'UL',
    this.respiratoryRate = 16,
    this.respiratoryRhythm = 'R',
    this.temperature = 98,
    this.temperatureUnit = 'F',
    this.temperatureMethod = 'O',
    this.spo2 = 98,
    this.grbs = 145,
    this.activityLevel = 'IV',
    this.stability = 'stable',
  });

  factory VisitVitals.fromJson(
    Map<String, dynamic>? json, {
    bool fillMissingWithDefaults = true,
  }) {
    final value = json ?? const {};
    const defaults = VisitVitals();
    return VisitVitals(
      pulse:
          _toInt(value['pulse']) ??
          (fillMissingWithDefaults ? defaults.pulse : null),
      pulseRhythm: value['pulseRhythm']?.toString() ?? 'R',
      bpSystolic:
          _toInt(value['bpSystolic']) ??
          (fillMissingWithDefaults ? defaults.bpSystolic : null),
      bpDiastolic:
          _toInt(value['bpDiastolic']) ??
          (fillMissingWithDefaults ? defaults.bpDiastolic : null),
      bpPosition: value['bpPosition']?.toString() ?? 'UL',
      respiratoryRate:
          _toInt(value['rr']) ??
          (fillMissingWithDefaults ? defaults.respiratoryRate : null),
      respiratoryRhythm: value['rrRhythm']?.toString() ?? 'R',
      temperature:
          _toDouble(value['temp']) ??
          (fillMissingWithDefaults ? defaults.temperature : null),
      temperatureUnit:
          value['tempUnit']?.toString() ?? defaults.temperatureUnit,
      temperatureMethod: value['tempMethod']?.toString() ?? 'O',
      spo2:
          _toInt(value['spo2']) ??
          (fillMissingWithDefaults ? defaults.spo2 : null),
      grbs:
          _toInt(value['grbs']) ??
          (fillMissingWithDefaults ? defaults.grbs : null),
      activityLevel:
          value['activityLevel']?.toString() ?? defaults.activityLevel,
      stability: value['stability']?.toString() ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() => {
    'pulse': pulse,
    'pulseRhythm': pulseRhythm,
    'bpSystolic': bpSystolic,
    'bpDiastolic': bpDiastolic,
    'bpPosition': bpPosition,
    'rr': respiratoryRate,
    'rrRhythm': respiratoryRhythm,
    'temp': temperature,
    'tempUnit': temperatureUnit,
    'tempMethod': temperatureMethod,
    'spo2': spo2,
    'grbs': grbs,
    'activityLevel': activityLevel,
    'stability': stability,
  };

  bool get hasMissingMeasurements =>
      pulse == null ||
      bpSystolic == null ||
      bpDiastolic == null ||
      respiratoryRate == null ||
      temperature == null ||
      spo2 == null ||
      grbs == null;

  VisitVitals withBaselineDefaults() {
    const defaults = VisitVitals();
    return VisitVitals(
      pulse: pulse ?? defaults.pulse,
      pulseRhythm: pulseRhythm,
      bpSystolic: bpSystolic ?? defaults.bpSystolic,
      bpDiastolic: bpDiastolic ?? defaults.bpDiastolic,
      bpPosition: bpPosition,
      respiratoryRate: respiratoryRate ?? defaults.respiratoryRate,
      respiratoryRhythm: respiratoryRhythm,
      temperature: temperature ?? defaults.temperature,
      temperatureUnit: temperatureUnit,
      temperatureMethod: temperatureMethod,
      spo2: spo2 ?? defaults.spo2,
      grbs: grbs ?? defaults.grbs,
      activityLevel: activityLevel,
      stability: stability,
    );
  }

  VisitVitals copyWith({
    int? pulse,
    bool clearPulse = false,
    String? pulseRhythm,
    int? bpSystolic,
    bool clearBpSystolic = false,
    int? bpDiastolic,
    bool clearBpDiastolic = false,
    String? bpPosition,
    int? respiratoryRate,
    bool clearRespiratoryRate = false,
    String? respiratoryRhythm,
    double? temperature,
    bool clearTemperature = false,
    String? temperatureUnit,
    String? temperatureMethod,
    int? spo2,
    bool clearSpo2 = false,
    int? grbs,
    bool clearGrbs = false,
    String? activityLevel,
    String? stability,
  }) {
    return VisitVitals(
      pulse: clearPulse ? null : pulse ?? this.pulse,
      pulseRhythm: pulseRhythm ?? this.pulseRhythm,
      bpSystolic: clearBpSystolic ? null : bpSystolic ?? this.bpSystolic,
      bpDiastolic: clearBpDiastolic ? null : bpDiastolic ?? this.bpDiastolic,
      bpPosition: bpPosition ?? this.bpPosition,
      respiratoryRate: clearRespiratoryRate
          ? null
          : respiratoryRate ?? this.respiratoryRate,
      respiratoryRhythm: respiratoryRhythm ?? this.respiratoryRhythm,
      temperature: clearTemperature ? null : temperature ?? this.temperature,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      temperatureMethod: temperatureMethod ?? this.temperatureMethod,
      spo2: clearSpo2 ? null : spo2 ?? this.spo2,
      grbs: clearGrbs ? null : grbs ?? this.grbs,
      activityLevel: activityLevel ?? this.activityLevel,
      stability: stability ?? this.stability,
    );
  }
}

class AssessmentMedicine {
  final String? id;
  final String? medicineId;
  final String medicineName;
  final String strength;
  final String instructionSpecified;
  final String instructionUsage;
  final Set<String> routes;
  final String duration;
  final String remarks;

  const AssessmentMedicine({
    this.id,
    this.medicineId,
    required this.medicineName,
    this.strength = '',
    this.instructionSpecified = '',
    this.instructionUsage = '',
    this.routes = const {},
    this.duration = '',
    this.remarks = '',
  });

  factory AssessmentMedicine.fromJson(Map<String, dynamic> json) {
    final legacyRoutes = <String>[
      if (json['routeOral'] == true) 'P',
      if (json['routeGastro'] == true) 'G',
      if (json['routeSC'] == true) 'S',
      if (json['routeOther'] == true) 'O',
    ];
    return AssessmentMedicine(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      medicineId: _idValue(json['medicineId']),
      medicineName: json['medicineName']?.toString() ?? '',
      strength: json['strength']?.toString() ?? '',
      instructionSpecified:
          json['instructionSpecified']?.toString() ??
          json['dose']?.toString() ??
          '',
      instructionUsage: json['instructionUsage']?.toString() ?? '',
      routes: json['routes'] is List
          ? (json['routes'] as List).map((item) => item.toString()).toSet()
          : legacyRoutes.toSet(),
      duration: json['duration']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'medicineId': medicineId,
    'medicineName': medicineName,
    'strength': strength,
    'instructionSpecified': instructionSpecified,
    'instructionUsage': instructionUsage,
    'routes': routes.toList(),
    'duration': duration,
    'remarks': remarks,
  };

  AssessmentMedicine copyWith({
    String? medicineId,
    String? medicineName,
    String? strength,
    String? instructionSpecified,
    String? instructionUsage,
    Set<String>? routes,
    String? duration,
    String? remarks,
  }) {
    return AssessmentMedicine(
      id: id,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      strength: strength ?? this.strength,
      instructionSpecified: instructionSpecified ?? this.instructionSpecified,
      instructionUsage: instructionUsage ?? this.instructionUsage,
      routes: routes ?? this.routes,
      duration: duration ?? this.duration,
      remarks: remarks ?? this.remarks,
    );
  }
}

class ExamFinding {
  final String status;
  final String value;
  final String notes;
  final List<String> images;
  final Map<String, String> extraValues;

  const ExamFinding({
    this.status = 'not_assessed',
    this.value = '',
    this.notes = '',
    this.images = const [],
    this.extraValues = const {},
  });

  factory ExamFinding.fromJson(dynamic json) {
    if (json is String) {
      return ExamFinding(
        status: json.trim().isEmpty ? 'not_assessed' : 'normal',
        notes: json,
      );
    }
    if (json is! Map) return const ExamFinding();
    return ExamFinding(
      status: json['status']?.toString() ?? 'not_assessed',
      value: json['value']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      extraValues: json['extraValues'] is Map
          ? {
              for (final entry in (json['extraValues'] as Map).entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            }
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'value': value,
    'notes': notes,
    'images': images,
    'extraValues': extraValues,
  };

  ExamFinding copyWith({
    String? status,
    String? value,
    String? notes,
    List<String>? images,
    Map<String, String>? extraValues,
  }) {
    return ExamFinding(
      status: status ?? this.status,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      images: images ?? this.images,
      extraValues: extraValues ?? this.extraValues,
    );
  }
}

const assessmentExamKeys = <String>[
  'respiration',
  'foodWater',
  'urine',
  'defecation',
  'sleep',
  'hygiene',
  'outdoorAccess',
  'sexuality',
  'scalpHair',
  'skin',
  'eyeNoseMouth',
  'oral',
  'nails',
  'perineum',
  'pressureArea',
  'hiddenArea',
  'musclesJoints',
  'specialAttention',
];

Map<String, ExamFinding> emptyPhysicalExam() => {
  for (final key in assessmentExamKeys) key: defaultExamFinding(key),
};

ExamFinding defaultExamFinding(String key) {
  return const ExamFinding();
}

ExamFinding _draftDefaultExamFinding(String key, dynamic json) {
  final finding = ExamFinding.fromJson(json);
  if (finding.status != 'not_assessed' ||
      finding.value.trim().isNotEmpty ||
      finding.notes.trim().isNotEmpty ||
      finding.images.isNotEmpty ||
      finding.extraValues.values.any((value) => value.trim().isNotEmpty)) {
    return finding;
  }
  return defaultExamFinding(key);
}

class AssessmentCarePlan {
  final Set<String> visitPlans;
  final Map<String, String> visitPlanNotes;
  final Set<String> services;

  const AssessmentCarePlan({
    this.visitPlans = const {'NHC'},
    this.visitPlanNotes = const {},
    this.services = const {},
  });

  factory AssessmentCarePlan.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const {};
    final legacyVisitPlans = <String>{
      for (final option in ['DHC', 'NHC', 'GVHC', 'other'])
        if (value[option] == true) option,
    };
    final legacyServices = <String>{
      for (final option in [
        'healthEducation',
        'familyTraining',
        'physiotherapy',
        'dayCare',
        'socialSupport',
        'medicineSupport',
      ])
        if (value[option] == true) option,
    };
    final notesValue = value['visitPlanNotes'];
    return AssessmentCarePlan(
      visitPlans: value['visitPlans'] is List
          ? (value['visitPlans'] as List).map((item) => item.toString()).toSet()
          : legacyVisitPlans,
      visitPlanNotes: notesValue is Map
          ? {
              for (final entry in notesValue.entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            }
          : const {},
      services: value['services'] is List
          ? (value['services'] as List).map((item) => item.toString()).toSet()
          : legacyServices,
    );
  }

  Map<String, dynamic> toJson() => {
    'visitPlans': visitPlans.toList(),
    'visitPlanNotes': visitPlanNotes,
    'services': services.toList(),
  };

  AssessmentCarePlan copyWith({
    Set<String>? visitPlans,
    Map<String, String>? visitPlanNotes,
    Set<String>? services,
  }) {
    return AssessmentCarePlan(
      visitPlans: visitPlans ?? this.visitPlans,
      visitPlanNotes: visitPlanNotes ?? this.visitPlanNotes,
      services: services ?? this.services,
    );
  }
}

class VisitAssessment {
  final String? id;
  final String homeVisitId;
  final String patientId;
  final String patientName;
  final String patientAge;
  final String patientAddress;
  final String regNo;
  final DateTime visitDate;
  final String timeFrom;
  final String timeTo;
  final String team;
  final String visitMode;
  final String visitType;
  final VisitVitals vitals;
  final List<AssessmentMedicine> medicines;
  final Map<String, ExamFinding> physicalExam;
  final String previousVisitConcerns;
  final String medicineRemarks;
  final String nursingDiagnosis;
  final String doctorConsultNotes;
  final String nursingManagementPlan;
  final String complementary;
  final AssessmentCarePlan carePlan;
  final String teamMeetingDiscussion;
  final String nurseName;
  final String? nurseId;
  final String signatureUrl;
  final bool confirmed;
  final String status;
  final bool isComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;

  VisitAssessment({
    this.id,
    required this.homeVisitId,
    required this.patientId,
    required this.patientName,
    this.patientAge = '',
    this.patientAddress = '',
    required this.regNo,
    required this.visitDate,
    this.timeFrom = '',
    this.timeTo = '',
    this.team = 'Palliative App Team',
    this.visitMode = 'new',
    this.visitType = 'NHC',
    this.vitals = const VisitVitals(),
    this.medicines = const [],
    Map<String, ExamFinding>? physicalExam,
    this.previousVisitConcerns = '',
    this.medicineRemarks = '',
    this.nursingDiagnosis = '',
    this.doctorConsultNotes = '',
    this.nursingManagementPlan = '',
    this.complementary = 'Nil',
    this.carePlan = const AssessmentCarePlan(),
    this.teamMeetingDiscussion = '',
    this.nurseName = '',
    this.nurseId,
    this.signatureUrl = '',
    this.confirmed = false,
    this.status = 'draft',
    this.isComplete = false,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
  }) : physicalExam = physicalExam ?? emptyPhysicalExam();

  factory VisitAssessment.fromJson(Map<String, dynamic> json) {
    final examJson = json['physicalExam'] is Map<String, dynamic>
        ? json['physicalExam'] as Map<String, dynamic>
        : <String, dynamic>{};
    final patient = json['patientId'];
    final status =
        json['status']?.toString() ??
        (json['isComplete'] == true ? 'submitted' : 'draft');
    return VisitAssessment(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      homeVisitId: _idValue(json['homeVisitId']) ?? '',
      patientId: _idValue(patient) ?? '',
      patientName: patient is Map
          ? patient['name']?.toString() ?? ''
          : json['patientName']?.toString() ?? '',
      patientAge:
          json['patientAge']?.toString() ??
          (patient is Map ? patient['age']?.toString() ?? '' : ''),
      patientAddress:
          json['patientAddress']?.toString() ??
          (patient is Map ? patient['address']?.toString() ?? '' : ''),
      regNo:
          json['regNo']?.toString() ??
          (patient is Map ? patient['registerId']?.toString() ?? '' : ''),
      visitDate:
          DateTime.tryParse(json['visitDate']?.toString() ?? '') ??
          DateTime.now(),
      timeFrom: json['timeFrom']?.toString() ?? '',
      timeTo: json['timeTo']?.toString() ?? '',
      team: json['team']?.toString() ?? 'Palliative App Team',
      visitMode: json['visitMode']?.toString() ?? 'new',
      visitType: json['visitType']?.toString() ?? 'NHC',
      vitals: VisitVitals.fromJson(
        json['vitals'] as Map<String, dynamic>?,
        fillMissingWithDefaults: status != 'submitted',
      ),
      medicines: (json['medicines'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AssessmentMedicine.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      physicalExam: {
        for (final key in assessmentExamKeys)
          key: status == 'submitted'
              ? ExamFinding.fromJson(examJson[key])
              : _draftDefaultExamFinding(key, examJson[key]),
      },
      previousVisitConcerns: json['previousVisitConcerns']?.toString() ?? '',
      medicineRemarks: json['medicineRemarks']?.toString() ?? '',
      nursingDiagnosis: json['nursingDiagnosis']?.toString() ?? '',
      doctorConsultNotes: json['doctorConsultNotes']?.toString() ?? '',
      nursingManagementPlan: json['nursingManagementPlan']?.toString() ?? '',
      complementary: json['complementary']?.toString() ?? 'Nil',
      carePlan: AssessmentCarePlan.fromJson(
        json['carePlan'] as Map<String, dynamic>?,
      ),
      teamMeetingDiscussion: json['teamMeetingDiscussion']?.toString() ?? '',
      nurseName: json['nurseName']?.toString() ?? '',
      nurseId: _idValue(json['nurseId']),
      signatureUrl: json['signatureUrl']?.toString() ?? '',
      confirmed: json['confirmed'] == true,
      status: status,
      isComplete: json['isComplete'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'homeVisitId': homeVisitId,
    'patientId': patientId,
    'patientName': patientName,
    'patientAge': patientAge,
    'patientAddress': patientAddress,
    'regNo': regNo,
    'visitDate': visitDate.toIso8601String(),
    'timeFrom': timeFrom,
    'timeTo': timeTo,
    'team': team,
    'visitMode': visitMode,
    'visitType': visitType,
    'vitals': vitals.toJson(),
    'medicines': medicines.map((item) => item.toJson()).toList(),
    'physicalExam': {
      for (final entry in physicalExam.entries) entry.key: entry.value.toJson(),
    },
    'previousVisitConcerns': previousVisitConcerns,
    'medicineRemarks': medicineRemarks,
    'nursingDiagnosis': nursingDiagnosis,
    'doctorConsultNotes': doctorConsultNotes,
    'nursingManagementPlan': nursingManagementPlan,
    'complementary': complementary,
    'carePlan': carePlan.toJson(),
    'teamMeetingDiscussion': teamMeetingDiscussion,
    'nurseName': nurseName,
    'nurseId': nurseId,
    'signatureUrl': signatureUrl,
    'confirmed': confirmed,
    'status': status,
    'isComplete': isComplete,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'submittedAt': submittedAt?.toIso8601String(),
  };

  VisitAssessment copyWith({
    String? id,
    String? homeVisitId,
    String? patientId,
    String? patientName,
    String? patientAge,
    String? patientAddress,
    String? regNo,
    DateTime? visitDate,
    String? timeFrom,
    String? timeTo,
    String? team,
    String? visitMode,
    String? visitType,
    VisitVitals? vitals,
    List<AssessmentMedicine>? medicines,
    Map<String, ExamFinding>? physicalExam,
    String? previousVisitConcerns,
    String? medicineRemarks,
    String? nursingDiagnosis,
    String? doctorConsultNotes,
    String? nursingManagementPlan,
    String? complementary,
    AssessmentCarePlan? carePlan,
    String? teamMeetingDiscussion,
    String? nurseName,
    String? nurseId,
    String? signatureUrl,
    bool? confirmed,
    String? status,
    bool? isComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) {
    return VisitAssessment(
      id: id ?? this.id,
      homeVisitId: homeVisitId ?? this.homeVisitId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientAge: patientAge ?? this.patientAge,
      patientAddress: patientAddress ?? this.patientAddress,
      regNo: regNo ?? this.regNo,
      visitDate: visitDate ?? this.visitDate,
      timeFrom: timeFrom ?? this.timeFrom,
      timeTo: timeTo ?? this.timeTo,
      team: team ?? this.team,
      visitMode: visitMode ?? this.visitMode,
      visitType: visitType ?? this.visitType,
      vitals: vitals ?? this.vitals,
      medicines: medicines ?? this.medicines,
      physicalExam: physicalExam ?? this.physicalExam,
      previousVisitConcerns:
          previousVisitConcerns ?? this.previousVisitConcerns,
      medicineRemarks: medicineRemarks ?? this.medicineRemarks,
      nursingDiagnosis: nursingDiagnosis ?? this.nursingDiagnosis,
      doctorConsultNotes: doctorConsultNotes ?? this.doctorConsultNotes,
      nursingManagementPlan:
          nursingManagementPlan ?? this.nursingManagementPlan,
      complementary: complementary ?? this.complementary,
      carePlan: carePlan ?? this.carePlan,
      teamMeetingDiscussion:
          teamMeetingDiscussion ?? this.teamMeetingDiscussion,
      nurseName: nurseName ?? this.nurseName,
      nurseId: nurseId ?? this.nurseId,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      confirmed: confirmed ?? this.confirmed,
      status: status ?? this.status,
      isComplete: isComplete ?? this.isComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}

String? _idValue(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    return value['_id']?.toString() ?? value['id']?.toString();
  }
  return value.toString();
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
