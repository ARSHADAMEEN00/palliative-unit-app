class EquipmentSupply {
  final String? id;
  final String equipmentId;
  final String equipmentUniqueId;
  final String equipmentName;
  final String? patientId;
  final String? patientName;
  final String? patientPhone;
  final String? patientAddress;
  final String? patientPlace;
  final String? careOf;
  final String? receiverName;
  final String? receiverPhone;
  final String? receiverAddress;
  final String? receiverPlace;
  final DateTime supplyDate;
  final DateTime? returnDate;
  final DateTime? actualReturnDate;
  final String status; // 'active', 'returned', 'lost'
  final String? notes;
  final String? returnNote;
  final String? createdBy;
  final DateTime? createdAt;
  final String? originUnitId;
  final String? transferRequestId;
  final String? externalCustodianUnitId;
  final bool isExternalCustody;
  final String? ownerUnitId;
  final String? ownerUnitName;
  final String? custodyStatus;

  const EquipmentSupply({
    this.id,
    required this.equipmentId,
    required this.equipmentUniqueId,
    required this.equipmentName,
    this.patientId,
    this.patientName,
    this.patientPhone,
    this.patientAddress,
    this.patientPlace,
    this.careOf,
    this.receiverName,
    this.receiverPhone,
    this.receiverAddress,
    this.receiverPlace,
    required this.supplyDate,
    this.returnDate,
    this.actualReturnDate,
    this.status = 'active',
    this.notes,
    this.returnNote,
    this.createdBy,
    this.createdAt,
    this.originUnitId,
    this.transferRequestId,
    this.externalCustodianUnitId,
    this.isExternalCustody = false,
    this.ownerUnitId,
    this.ownerUnitName,
    this.custodyStatus,
  });

  factory EquipmentSupply.fromJson(Map<String, dynamic> json) {
    return EquipmentSupply(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      equipmentId: json['equipmentId']?.toString() ?? '',
      equipmentUniqueId: json['equipmentUniqueId']?.toString() ?? '',
      equipmentName: json['equipmentName']?.toString() ?? '',
      patientId: _idFromJson(json['patientId']),
      patientName: json['patientName']?.toString(),
      patientPhone: json['patientPhone']?.toString(),
      patientAddress: json['patientAddress']?.toString(),
      patientPlace: json['patientPlace']?.toString(),
      careOf: json['careOf']?.toString(),
      receiverName: json['receiverName']?.toString(),
      receiverPhone: json['receiverPhone']?.toString(),
      receiverAddress: json['receiverAddress']?.toString(),
      receiverPlace: json['receiverPlace']?.toString(),
      supplyDate:
          DateTime.tryParse(json['supplyDate']?.toString() ?? '') ??
          DateTime.now(),
      returnDate: json['returnDate'] != null
          ? DateTime.tryParse(json['returnDate'].toString())
          : null,
      actualReturnDate: json['actualReturnDate'] != null
          ? DateTime.tryParse(json['actualReturnDate'].toString())
          : null,
      status: json['status']?.toString() ?? 'active',
      notes: json['notes']?.toString(),
      returnNote: json['returnNote']?.toString(),
      createdBy: json['createdBy'] is Map
          ? json['createdBy']['name']?.toString()
          : json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      originUnitId: _idFromJson(json['originUnitId']),
      transferRequestId: _idFromJson(json['transferRequestId']),
      externalCustodianUnitId: _idFromJson(json['externalCustodianUnitId']),
      isExternalCustody: json['isExternalCustody'] == true,
      ownerUnitId: _idFromJson(json['ownerUnitId']),
      ownerUnitName: json['ownerUnitName']?.toString(),
      custodyStatus: json['custodyStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'equipmentId': equipmentId,
      'equipmentUniqueId': equipmentUniqueId,
      'equipmentName': equipmentName,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientAddress': patientAddress,
      'patientPlace': patientPlace,
      'careOf': careOf,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'receiverAddress': receiverAddress,
      'receiverPlace': receiverPlace,
      'supplyDate': supplyDate.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'actualReturnDate': actualReturnDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'returnNote': returnNote,
      'createdAt': createdAt?.toIso8601String(),
      'originUnitId': originUnitId,
      'transferRequestId': transferRequestId,
      'externalCustodianUnitId': externalCustodianUnitId,
      'isExternalCustody': isExternalCustody,
      'ownerUnitId': ownerUnitId,
      'ownerUnitName': ownerUnitName,
      'custodyStatus': custodyStatus,
    };
  }

  static String? _idFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value['_id']?.toString() ?? value['id']?.toString();
    }
    final id = value.toString().trim();
    return id.isEmpty ? null : id;
  }
}
