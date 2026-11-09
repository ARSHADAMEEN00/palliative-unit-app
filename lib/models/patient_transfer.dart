import 'patient.dart';
import 'patient_details.dart';

class TransferUnitSummary {
  const TransferUnitSummary({
    required this.id,
    required this.name,
    this.code,
    this.district,
    this.village,
  });

  final String id;
  final String name;
  final String? code;
  final String? district;
  final String? village;

  factory TransferUnitSummary.fromJson(Map<String, dynamic> json) {
    return TransferUnitSummary(
      id: _text(json['id'] ?? json['_id']),
      name: _text(json['name']),
      code: _nullableText(json['code']),
      district: _nullableText(json['district']),
      village: _nullableText(json['village']),
    );
  }
}

class TransferPatientSummary {
  const TransferPatientSummary({
    required this.id,
    required this.name,
    this.registerId,
    this.age,
    this.gender,
    this.phone,
    this.place,
    this.village,
  });

  final String id;
  final String name;
  final String? registerId;
  final int? age;
  final String? gender;
  final String? phone;
  final String? place;
  final String? village;

  factory TransferPatientSummary.fromJson(Map<String, dynamic> json) {
    return TransferPatientSummary(
      id: _text(json['id'] ?? json['_id']),
      name: _text(json['name']),
      registerId: _nullableText(json['registerId']),
      age: int.tryParse(_text(json['age'])),
      gender: _nullableText(json['gender']),
      phone: _nullableText(json['phone']),
      place: _nullableText(json['place']),
      village: _nullableText(json['village']),
    );
  }
}

class TransferVerificationCheck {
  const TransferVerificationCheck({
    required this.key,
    required this.label,
    required this.required,
    required this.checked,
  });

  final String key;
  final String label;
  final bool required;
  final bool checked;

  factory TransferVerificationCheck.fromJson(Map<String, dynamic> json) {
    return TransferVerificationCheck(
      key: _text(json['key']),
      label: _text(json['label']),
      required: json['required'] != false,
      checked: json['checked'] == true,
    );
  }

  Map<String, dynamic> toJson({bool? checked}) => {
    'key': key,
    'checked': checked ?? this.checked,
  };
}

class TransferDuplicateCandidate {
  const TransferDuplicateCandidate({
    required this.patientId,
    required this.name,
    this.registerId,
    required this.phoneMatch,
    required this.nameAgeMatch,
  });

  final String patientId;
  final String name;
  final String? registerId;
  final bool phoneMatch;
  final bool nameAgeMatch;

  factory TransferDuplicateCandidate.fromJson(Map<String, dynamic> json) {
    return TransferDuplicateCandidate(
      patientId: _text(json['patientId']),
      name: _text(json['name']),
      registerId: _nullableText(json['registerId']),
      phoneMatch: json['phoneMatch'] == true,
      nameAgeMatch: json['nameAgeMatch'] == true,
    );
  }
}

class PatientTransferRequest {
  const PatientTransferRequest({
    required this.id,
    required this.patientId,
    required this.sourceUnitId,
    required this.destinationUnitId,
    required this.status,
    required this.reason,
    required this.transferDate,
    required this.handoverSummary,
    this.patient,
    this.sourceUnit,
    this.destinationUnit,
    this.newAddress,
    this.currentCareStatus,
    this.remarks,
    this.requestedByName,
    this.requestedAt,
    this.acceptedByName,
    this.acceptedAt,
    this.rejectionReason,
    this.expiresAt,
    this.equipmentCurrentlyIssued = const [],
    this.activeMedicines = const [],
    this.pendingVisitsAndTasks = const [],
    this.verificationChecklist = const [],
    this.duplicateCandidates = const [],
    this.version = 0,
  });

  final String id;
  final String patientId;
  final String sourceUnitId;
  final String destinationUnitId;
  final String status;
  final String reason;
  final DateTime transferDate;
  final String handoverSummary;
  final TransferPatientSummary? patient;
  final TransferUnitSummary? sourceUnit;
  final TransferUnitSummary? destinationUnit;
  final String? newAddress;
  final String? currentCareStatus;
  final String? remarks;
  final String? requestedByName;
  final DateTime? requestedAt;
  final String? acceptedByName;
  final DateTime? acceptedAt;
  final String? rejectionReason;
  final DateTime? expiresAt;
  final List<Map<String, dynamic>> equipmentCurrentlyIssued;
  final List<Map<String, dynamic>> activeMedicines;
  final List<Map<String, dynamic>> pendingVisitsAndTasks;
  final List<TransferVerificationCheck> verificationChecklist;
  final List<TransferDuplicateCandidate> duplicateCandidates;
  final int version;

  bool get isPending => status == 'PENDING';
  bool get hasPossibleDuplicate => duplicateCandidates.isNotEmpty;

  factory PatientTransferRequest.fromJson(Map<String, dynamic> json) {
    return PatientTransferRequest(
      id: _text(json['id'] ?? json['_id']),
      patientId: _text(json['patientId']),
      sourceUnitId: _text(json['sourceUnitId']),
      destinationUnitId: _text(json['destinationUnitId']),
      status: _text(json['status']).toUpperCase(),
      reason: _text(json['reason']),
      transferDate: _date(json['transferDate']) ?? DateTime.now(),
      handoverSummary: _text(json['handoverSummary']),
      patient: _object(json['patient']) == null
          ? null
          : TransferPatientSummary.fromJson(_object(json['patient'])!),
      sourceUnit: _object(json['sourceUnit']) == null
          ? null
          : TransferUnitSummary.fromJson(_object(json['sourceUnit'])!),
      destinationUnit: _object(json['destinationUnit']) == null
          ? null
          : TransferUnitSummary.fromJson(_object(json['destinationUnit'])!),
      newAddress: _nullableText(json['newAddress']),
      currentCareStatus: _nullableText(json['currentCareStatus']),
      remarks: _nullableText(json['remarks']),
      requestedByName: _nullableText(json['requestedByName']),
      requestedAt: _date(json['requestedAt']),
      acceptedByName: _nullableText(json['acceptedByName']),
      acceptedAt: _date(json['acceptedAt']),
      rejectionReason: _nullableText(json['rejectionReason']),
      expiresAt: _date(json['expiresAt']),
      equipmentCurrentlyIssued: _objectList(json['equipmentCurrentlyIssued']),
      activeMedicines: _objectList(json['activeMedicines']),
      pendingVisitsAndTasks: _objectList(json['pendingVisitsAndTasks']),
      verificationChecklist: _objectList(
        json['verificationChecklist'],
      ).map(TransferVerificationCheck.fromJson).toList(),
      duplicateCandidates: _objectList(
        json['duplicateCandidates'],
      ).map(TransferDuplicateCandidate.fromJson).toList(),
      version: int.tryParse(_text(json['version'])) ?? 0,
    );
  }
}

class PatientTransferDetails {
  const PatientTransferDetails({required this.request, this.preview});

  final PatientTransferRequest request;
  final PatientDetails? preview;

  factory PatientTransferDetails.fromJson(Map<String, dynamic> json) {
    final preview = _object(json['preview']);
    return PatientTransferDetails(
      request: PatientTransferRequest.fromJson(
        _object(json['request']) ?? const {},
      ),
      preview: preview == null ? null : PatientDetails.fromJson(preview),
    );
  }
}

class PatientTransferPage {
  const PatientTransferPage({
    required this.requests,
    required this.page,
    required this.total,
    required this.pages,
  });

  final List<PatientTransferRequest> requests;
  final int page;
  final int total;
  final int pages;

  factory PatientTransferPage.fromJson(Map<String, dynamic> json) {
    return PatientTransferPage(
      requests: _objectList(
        json['requests'],
      ).map(PatientTransferRequest.fromJson).toList(),
      page: int.tryParse(_text(json['page'])) ?? 1,
      total: int.tryParse(_text(json['total'])) ?? 0,
      pages: int.tryParse(_text(json['pages'])) ?? 0,
    );
  }
}

class TransferredPatientSummary {
  const TransferredPatientSummary({
    required this.id,
    required this.patientName,
    required this.destinationUnitName,
    required this.reason,
    required this.transferredAt,
    this.registerId,
  });

  final String id;
  final String patientName;
  final String destinationUnitName;
  final String reason;
  final String? registerId;
  final DateTime transferredAt;

  factory TransferredPatientSummary.fromJson(Map<String, dynamic> json) {
    return TransferredPatientSummary(
      id: _text(json['id'] ?? json['_id']),
      patientName: _text(json['patientName']),
      destinationUnitName: _text(json['destinationUnitName']),
      reason: _text(json['reason']),
      registerId: _nullableText(json['registerId']),
      transferredAt: _date(json['transferredAt']) ?? DateTime.now(),
    );
  }
}

class TransferredPatientPage {
  const TransferredPatientPage({
    required this.patients,
    required this.page,
    required this.total,
    required this.pages,
  });

  final List<TransferredPatientSummary> patients;
  final int page;
  final int total;
  final int pages;

  factory TransferredPatientPage.fromJson(Map<String, dynamic> json) {
    return TransferredPatientPage(
      patients: _objectList(
        json['patients'],
      ).map(TransferredPatientSummary.fromJson).toList(),
      page: int.tryParse(_text(json['page'])) ?? 1,
      total: int.tryParse(_text(json['total'])) ?? 0,
      pages: int.tryParse(_text(json['pages'])) ?? 0,
    );
  }
}

class TransferredPatientDetails {
  const TransferredPatientDetails({
    required this.patient,
    required this.details,
    required this.snapshot,
    required this.history,
    this.transfer,
  });

  final Patient patient;
  final PatientDetails details;
  final Map<String, dynamic> snapshot;
  final Map<String, List<Map<String, dynamic>>> history;
  final PatientTransferRequest? transfer;

  factory TransferredPatientDetails.fromJson(Map<String, dynamic> json) {
    final patientJson = _object(json['patient']) ?? const <String, dynamic>{};
    final history = _object(json['history']) ?? const <String, dynamic>{};
    final detailsJson = <String, dynamic>{
      'patient': patientJson,
      'homeVisits': history['homeVisits'] ?? const [],
      'equipmentSupplies': history['equipmentSupplies'] ?? const [],
      'visitAssessments': history['visitAssessments'] ?? const [],
      'medicineSupplies': history['medicineSupplies'] ?? const [],
      'socialSupports': history['socialSupports'] ?? const [],
    };
    final patient = Patient.fromJson(patientJson);
    final transferJson = _object(json['transfer']);
    final typedHistory = history.map(
      (key, value) => MapEntry(key, _objectList(value)),
    );
    return TransferredPatientDetails(
      patient: patient,
      details: PatientDetails.fromJson(detailsJson),
      snapshot: _object(json['snapshot']) ?? const {},
      history: typedHistory,
      transfer: transferJson == null
          ? null
          : PatientTransferRequest.fromJson(transferJson),
    );
  }
}

Map<String, dynamic>? _object(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return null;
}

List<Map<String, dynamic>> _objectList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_object).whereType<Map<String, dynamic>>().toList();
}

String _text(dynamic value) => value?.toString().trim() ?? '';

String? _nullableText(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}
