import 'medicine.dart';

class MedicineStockEntryDraft {
  final String? medicineId;
  final String medicineName;
  final double quantity;
  final String qtyUnit;
  final DateTime expiryDate;
  final DateTime? entryDate;
  final String? batchNumber;
  final String sourceType;
  final String sourceLabel;
  final String? sourcePatientName;
  final String? sourcePatientRegisterId;
  final String? sourceSupplyId;
  final String? note;

  const MedicineStockEntryDraft({
    this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.qtyUnit,
    required this.expiryDate,
    this.entryDate,
    this.batchNumber,
    this.sourceType = 'main_stock',
    this.sourceLabel = 'Main Stock',
    this.sourcePatientName,
    this.sourcePatientRegisterId,
    this.sourceSupplyId,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      if (medicineId != null) 'medicineId': medicineId,
      'medicineName': medicineName,
      'quantity': quantity,
      'qtyUnit': qtyUnit,
      'expiryDate': expiryDate.toIso8601String(),
      if (entryDate != null) 'entryDate': entryDate!.toIso8601String(),
      if (batchNumber?.trim().isNotEmpty == true)
        'batchNumber': batchNumber!.trim(),
      'sourceType': sourceType,
      'sourceLabel': sourceLabel,
      if (sourcePatientName?.trim().isNotEmpty == true)
        'sourcePatientName': sourcePatientName!.trim(),
      if (sourcePatientRegisterId?.trim().isNotEmpty == true)
        'sourcePatientRegisterId': sourcePatientRegisterId!.trim(),
      if (sourceSupplyId?.trim().isNotEmpty == true)
        'sourceSupplyId': sourceSupplyId!.trim(),
      if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    };
  }
}

class MedicineStockEntry {
  final String? id;
  final dynamic medicineId;
  final String medicineName;
  final double quantity;
  final double originalQuantity;
  final String qtyUnit;
  final DateTime entryDate;
  final DateTime expiryDate;
  final String? batchNumber;
  final String sourceType;
  final String sourceLabel;
  final String? sourcePatientName;
  final String? sourcePatientRegisterId;
  final String? sourceSupplyId;
  final String? note;
  final MedicineUserSummary? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicineStockEntry({
    this.id,
    this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.originalQuantity,
    required this.qtyUnit,
    required this.entryDate,
    required this.expiryDate,
    this.batchNumber,
    this.sourceType = 'main_stock',
    this.sourceLabel = 'Main Stock',
    this.sourcePatientName,
    this.sourcePatientRegisterId,
    this.sourceSupplyId,
    this.note,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicineStockEntry.fromJson(Map<String, dynamic> json) {
    return MedicineStockEntry(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      medicineId: json['medicineId'],
      medicineName:
          json['medicineName']?.toString() ??
          _medicineNameFromJson(json['medicineId']),
      quantity: _toDouble(json['quantity']) ?? 0,
      originalQuantity:
          _toDouble(json['originalQuantity']) ??
          _toDouble(json['quantity']) ??
          0,
      qtyUnit: json['qtyUnit']?.toString() ?? 'units',
      entryDate: _toDate(json['entryDate']) ?? DateTime.now(),
      expiryDate: _toDate(json['expiryDate']) ?? DateTime.now(),
      batchNumber: json['batchNumber']?.toString(),
      sourceType: json['sourceType']?.toString() ?? 'main_stock',
      sourceLabel: json['sourceLabel']?.toString() ?? 'Main Stock',
      sourcePatientName: json['sourcePatientName']?.toString(),
      sourcePatientRegisterId: json['sourcePatientRegisterId']?.toString(),
      sourceSupplyId: json['sourceSupplyId']?.toString(),
      note: json['note']?.toString(),
      createdBy: _userFromJson(json['createdBy']),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }

  String get medicineCode {
    final value = medicineId;
    if (value is Map && value['code'] != null) return value['code'].toString();
    return '';
  }

  static String _medicineNameFromJson(dynamic value) {
    if (value is Map && value['name'] != null) return value['name'].toString();
    return 'Unknown medicine';
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static MedicineUserSummary? _userFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MedicineUserSummary.fromJson(value);
    }
    return null;
  }
}
