class MedicineUserSummary {
  final String? id;
  final String? name;
  final String? email;
  final String? role;

  const MedicineUserSummary({this.id, this.name, this.email, this.role});

  factory MedicineUserSummary.fromJson(Map<String, dynamic> json) {
    return MedicineUserSummary(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
    );
  }
}

class MedicineBatch {
  final String? id;
  final double quantity;
  final double originalQuantity;
  final String? qtyUnit;
  final DateTime? entryDate;
  final DateTime? expiryDate;
  final String? batchNumber;
  final String sourceType;
  final String sourceLabel;
  final String? sourcePatientName;
  final String? sourcePatientRegisterId;
  final String? sourceSupplyId;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicineBatch({
    this.id,
    this.quantity = 0,
    this.originalQuantity = 0,
    this.qtyUnit,
    this.entryDate,
    this.expiryDate,
    this.batchNumber,
    this.sourceType = 'main_stock',
    this.sourceLabel = 'Main Stock',
    this.sourcePatientName,
    this.sourcePatientRegisterId,
    this.sourceSupplyId,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicineBatch.fromJson(Map<String, dynamic> json) {
    final quantity = _toDouble(json['quantity']) ?? 0;
    return MedicineBatch(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      quantity: quantity,
      originalQuantity: _toDouble(json['originalQuantity']) ?? quantity,
      qtyUnit: json['qtyUnit']?.toString(),
      entryDate: _toDate(json['entryDate']),
      expiryDate: _toDate(json['expiryDate']),
      batchNumber: json['batchNumber']?.toString(),
      sourceType: json['sourceType']?.toString() ?? 'main_stock',
      sourceLabel: json['sourceLabel']?.toString() ?? 'Main Stock',
      sourcePatientName: json['sourcePatientName']?.toString(),
      sourcePatientRegisterId: json['sourcePatientRegisterId']?.toString(),
      sourceSupplyId: json['sourceSupplyId']?.toString(),
      note: json['note']?.toString(),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }

  bool get isEmpty => quantity <= 0;

  bool get expiresWithin60Days {
    final expiry = expiryDate;
    if (expiry == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return !expiryDay.isAfter(todayStart.add(const Duration(days: 60)));
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class Medicine {
  final String? id;
  final String code;
  final String? barcode;
  final String name;
  final List<String> brandNames;
  final String category;
  final String? formulation;
  final double? strength;
  final String? strengthUnit;
  final double qty;
  final String? qtyUnit;
  final String? netContent;
  final List<MedicineBatch> batches;
  final DateTime? earliestExpiryDate;
  final int expiringBatchCount;
  final int emptyBatchCount;
  final String? description;
  final List<String> photos;
  final bool isActive;
  final MedicineUserSummary? createdBy;
  final MedicineUserSummary? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Medicine({
    this.id,
    required this.code,
    this.barcode,
    required this.name,
    this.brandNames = const [],
    this.category = 'other',
    this.formulation,
    this.strength,
    this.strengthUnit,
    this.qty = 0,
    this.qtyUnit,
    this.netContent,
    this.batches = const [],
    this.earliestExpiryDate,
    this.expiringBatchCount = 0,
    this.emptyBatchCount = 0,
    this.description,
    this.photos = const [],
    this.isActive = true,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      code: json['code']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      name: json['name']?.toString() ?? '',
      brandNames: (json['brandNames'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      category: json['category']?.toString() ?? 'other',
      formulation: json['formulation']?.toString(),
      strength: _toDouble(json['strength']),
      strengthUnit: json['strengthUnit']?.toString(),
      qty: _toDouble(json['qty']) ?? 0,
      qtyUnit: json['qtyUnit']?.toString(),
      netContent: json['netContent']?.toString(),
      batches: (json['batches'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => MedicineBatch.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      earliestExpiryDate: json['earliestExpiryDate'] == null
          ? null
          : DateTime.tryParse(json['earliestExpiryDate'].toString()),
      expiringBatchCount: (json['expiringBatchCount'] as num?)?.toInt() ?? 0,
      emptyBatchCount: (json['emptyBatchCount'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString(),
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      isActive: json['isActive'] != false,
      createdBy: _userFromJson(json['createdBy']),
      updatedBy: _userFromJson(json['updatedBy']),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'barcode': barcode,
      'name': name,
      'brandNames': brandNames,
      'category': category,
      'formulation': formulation,
      'strength': strength,
      'strengthUnit': strengthUnit,
      'netContent': netContent,
      'description': description,
      'photos': photos,
      'isActive': isActive,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static MedicineUserSummary? _userFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MedicineUserSummary.fromJson(value);
    }
    return null;
  }
}
