class MedicineSupplyItem {
  final String? id;
  final dynamic medicineId;
  final dynamic stockEntryId;
  final int qtyGiven;
  final String status;
  final int? qtyReturned;
  final DateTime? returnedAt;
  final DateTime? cancelledAt;
  final String? staffNote;

  const MedicineSupplyItem({
    this.id,
    required this.medicineId,
    this.stockEntryId,
    required this.qtyGiven,
    this.status = 'given',
    this.qtyReturned,
    this.returnedAt,
    this.cancelledAt,
    this.staffNote,
  });

  factory MedicineSupplyItem.fromJson(Map<String, dynamic> json) {
    return MedicineSupplyItem(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      medicineId: json['medicineId'],
      stockEntryId: json['stockEntryId'],
      qtyGiven: (json['qtyGiven'] is num)
          ? (json['qtyGiven'] as num).toInt()
          : int.tryParse(json['qtyGiven']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'given',
      qtyReturned: (json['qtyReturned'] is num)
          ? (json['qtyReturned'] as num).toInt()
          : int.tryParse(json['qtyReturned']?.toString() ?? ''),
      returnedAt: json['returnedAt'] != null
          ? DateTime.tryParse(json['returnedAt'].toString())
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
      staffNote: json['staffNote']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicineId': MedicineSupply._getId(medicineId),
      if (MedicineSupply._getId(stockEntryId) != null)
        'stockEntryId': MedicineSupply._getId(stockEntryId),
      'qtyGiven': qtyGiven,
      'status': status,
      if (qtyReturned != null) 'qtyReturned': qtyReturned,
      if (returnedAt != null) 'returnedAt': returnedAt!.toIso8601String(),
      if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
      if (staffNote != null) 'staffNote': staffNote,
    };
  }

  String get medicineName {
    if (medicineId is Map) {
      return medicineId['name']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  String get medicineCode {
    if (medicineId is Map) {
      return medicineId['code']?.toString() ?? '';
    }
    return '';
  }

  String get batchNumber {
    if (stockEntryId is Map) {
      return stockEntryId['batchNumber']?.toString() ?? 'No batch';
    }
    return 'No batch';
  }

  String get qtyUnit {
    if (stockEntryId is Map) return stockEntryId['qtyUnit']?.toString() ?? '';
    return '';
  }

  DateTime? get entryDate {
    if (stockEntryId is Map && stockEntryId['entryDate'] != null) {
      return DateTime.tryParse(stockEntryId['entryDate'].toString());
    }
    return null;
  }

  String get sourceLabel {
    if (stockEntryId is Map) {
      return stockEntryId['sourceLabel']?.toString() ?? 'Main Stock';
    }
    return 'Main Stock';
  }

  String? get sourcePatientName {
    if (stockEntryId is Map) {
      return stockEntryId['sourcePatientName']?.toString();
    }
    return null;
  }

  String? get sourcePatientRegisterId {
    if (stockEntryId is Map) {
      return stockEntryId['sourcePatientRegisterId']?.toString();
    }
    return null;
  }

  DateTime? get expiryDate {
    if (stockEntryId is Map && stockEntryId['expiryDate'] != null) {
      return DateTime.tryParse(stockEntryId['expiryDate'].toString());
    }
    return null;
  }

  bool get canReturn => status != 'cancelled' && remainingQty > 0;

  bool get canCancel => status == 'given' && (qtyReturned ?? 0) <= 0;

  int get returnedQty => qtyReturned ?? 0;

  int get remainingQty => (qtyGiven - returnedQty).clamp(0, qtyGiven).toInt();
}

/// MedicineSupply model that matches the v2 backend schema.
class MedicineSupply {
  final String? id;
  final dynamic patientId; // Can be String ID or Map
  final dynamic medicineId; // Can be String ID or Map
  final dynamic givenByStaff; // Can be String ID or Map
  final DateTime givenAt;
  final int qtyGiven;
  final List<MedicineSupplyItem> items;
  final String? status;
  final int? qtyReturned;
  final DateTime? returnedAt;
  final String? staffNote;
  final String? prescribedBy;
  final String? doctorPrescription;
  final int? supplyDays;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicineSupply({
    this.id,
    required this.patientId,
    required this.medicineId,
    required this.givenByStaff,
    required this.givenAt,
    required this.qtyGiven,
    this.items = const [],
    this.status = 'given',
    this.qtyReturned,
    this.returnedAt,
    this.staffNote,
    this.prescribedBy,
    this.doctorPrescription,
    this.supplyDays,
    this.createdAt,
    this.updatedAt,
  });

  /// Create MedicineSupply from JSON (API response).
  factory MedicineSupply.fromJson(Map<String, dynamic> json) {
    return MedicineSupply(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      patientId: json['patientId'],
      medicineId: json['medicineId'],
      givenByStaff: json['givenByStaff'],
      givenAt: json['givenAt'] != null
          ? DateTime.tryParse(json['givenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      qtyGiven: (json['qtyGiven'] is num)
          ? (json['qtyGiven'] as num).toInt()
          : int.tryParse(json['qtyGiven']?.toString() ?? '0') ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MedicineSupplyItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      status: json['status']?.toString(),
      qtyReturned: (json['qtyReturned'] is num || json['qty_returned'] is num)
          ? ((json['qtyReturned'] ?? json['qty_returned']) as num).toInt()
          : int.tryParse(
              (json['qtyReturned'] ?? json['qty_returned'])?.toString() ?? '',
            ),
      returnedAt: (json['returnedAt'] ?? json['returned_at']) != null
          ? DateTime.tryParse(
              (json['returnedAt'] ?? json['returned_at']).toString(),
            )
          : null,
      staffNote: json['staffNote']?.toString(),
      prescribedBy: json['prescribedBy']?.toString(),
      doctorPrescription: json['doctorPrescription']?.toString(),
      supplyDays: (json['supplyDays'] is num)
          ? (json['supplyDays'] as num).toInt()
          : int.tryParse(json['supplyDays']?.toString() ?? ''),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  /// Convert MedicineSupply to JSON for API requests.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'patientId': _getId(patientId),
      'medicineId': _getId(medicineId),
      'givenByStaff': _getId(givenByStaff),
      'givenAt': givenAt.toIso8601String(),
      'qtyGiven': qtyGiven,
    };

    if (items.isNotEmpty) {
      map['items'] = items.map((item) => item.toJson()).toList();
    }

    if (status != null) {
      map['status'] = status;
    }
    if (qtyReturned != null) {
      map['qtyReturned'] = qtyReturned;
    }
    if (returnedAt != null) {
      map['returnedAt'] = returnedAt!.toIso8601String();
    }
    if (staffNote != null) {
      map['staffNote'] = staffNote;
    }
    if (prescribedBy != null) {
      map['prescribedBy'] = prescribedBy;
    }
    if (doctorPrescription != null) {
      map['doctorPrescription'] = doctorPrescription;
    }
    if (supplyDays != null) {
      map['supplyDays'] = supplyDays;
    }

    return map;
  }

  static String? _getId(dynamic field) {
    if (field == null) return null;
    if (field is String) return field;
    if (field is Map && field['_id'] != null) return field['_id'].toString();
    if (field is Map && field['id'] != null) return field['id'].toString();
    return field.toString();
  }

  /// Helper methods to safely get populated fields
  String get patientName {
    if (patientId is Map) return patientId['name']?.toString() ?? 'Unknown';
    return 'Unknown';
  }

  String? get patientRegisterId {
    if (patientId is Map) {
      return (patientId['registerId'] ??
              patientId['register_id'] ??
              patientId['registerNo'] ??
              patientId['regNo'])
          ?.toString();
    }
    return null;
  }

  String get patientPhone {
    if (patientId is Map) return patientId['phone']?.toString() ?? '';
    return '';
  }

  String get patientAddress {
    if (patientId is Map) return patientId['address']?.toString() ?? '';
    return '';
  }

  String get patientPlace {
    if (patientId is Map) return patientId['place']?.toString() ?? '';
    return '';
  }

  String get patientGender {
    if (patientId is Map) return patientId['gender']?.toString() ?? '';
    return '';
  }

  int get patientAge {
    if (patientId is Map) {
      return (patientId['age'] is num)
          ? (patientId['age'] as num).toInt()
          : int.tryParse(patientId['age']?.toString() ?? '0') ?? 0;
    }
    return 0;
  }

  List<String> get patientDiseases {
    if (patientId is Map && patientId['disease'] is List) {
      return List<String>.from(patientId['disease'] as List);
    }
    if (patientId is Map && patientId['disease'] != null) {
      return [patientId['disease'].toString()];
    }
    return const [];
  }

  String get medicineName {
    if (items.isNotEmpty) {
      final firstName = items.first.medicineName;
      if (items.length == 1) return firstName;
      return '$firstName + ${items.length - 1} more';
    }
    if (medicineId is Map) return medicineId['name']?.toString() ?? 'Unknown';
    return 'Unknown';
  }

  String get medicineSummary {
    if (items.isEmpty) return medicineName;
    return items
        .map((item) {
          final unit = item.qtyUnit.trim();
          final qty = unit.isEmpty
              ? '${item.qtyGiven}'
              : '${item.qtyGiven} $unit';
          return '${item.medicineName} ($qty)';
        })
        .join(', ');
  }

  String get staffName {
    if (givenByStaff is Map) {
      return givenByStaff['name']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  MedicineSupply copyWith({
    String? id,
    dynamic patientId,
    dynamic medicineId,
    dynamic givenByStaff,
    DateTime? givenAt,
    int? qtyGiven,
    List<MedicineSupplyItem>? items,
    String? status,
    int? qtyReturned,
    DateTime? returnedAt,
    String? staffNote,
    String? prescribedBy,
    String? doctorPrescription,
    int? supplyDays,
  }) {
    return MedicineSupply(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      medicineId: medicineId ?? this.medicineId,
      givenByStaff: givenByStaff ?? this.givenByStaff,
      givenAt: givenAt ?? this.givenAt,
      qtyGiven: qtyGiven ?? this.qtyGiven,
      items: items ?? this.items,
      status: status ?? this.status,
      qtyReturned: qtyReturned ?? this.qtyReturned,
      returnedAt: returnedAt ?? this.returnedAt,
      staffNote: staffNote ?? this.staffNote,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      doctorPrescription: doctorPrescription ?? this.doctorPrescription,
      supplyDays: supplyDays ?? this.supplyDays,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
