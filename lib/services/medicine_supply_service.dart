import '../models/medicine_supply.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

/// MedicineSupply service for CRUD operations via the backend API.
class MedicineSupplyService {
  MedicineSupplyService._();

  static const _prefix = 'med_supplies:';
  static const _keyAll = 'med_supplies:all';
  static const _ttl = Duration(minutes: 5);

  /// Get all medicine supplies from the API. Cached for [_ttl].
  static Future<List<MedicineSupply>> getAllMedicineSupplies({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      AppCache.invalidate(_keyAll);
    }
    return AppCache.get<List<MedicineSupply>>(
      _keyAll,
      ttl: _ttl,
      loader: _fetchAllMedicineSupplies,
    );
  }

  static Future<List<MedicineSupply>> _fetchAllMedicineSupplies() async {
    final result = await ApiService.get<List<dynamic>>(
      ApiConfig.v2MedicineSuppliesEndpoint,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => MedicineSupply.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw Exception(result.error ?? 'Failed to fetch medicine supplies');
  }

  /// Get a single medicine supply by ID (not cached).
  static Future<MedicineSupply> getMedicineSupplyById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$id',
    );

    if (result.isSuccess && result.data != null) {
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to fetch medicine supply');
  }

  /// Create a new medicine supply and invalidate the cache.
  static Future<MedicineSupply> createMedicineSupply(
    MedicineSupply supply,
  ) async {
    final existingSupply = await _findExistingPatientSupply(supply);
    if (existingSupply?.id != null) {
      final existingItems = _itemsOwnedBySupply(existingSupply!);
      final appendedItems = [
        ...existingItems,
        ...supply.items.map(
          (item) => item.copyWith(givenAt: item.givenAt ?? supply.givenAt),
        ),
      ];
      final latestGivenAt = _latestDate([
        existingSupply.givenAt,
        supply.givenAt,
        ...appendedItems.map((item) => item.givenAt),
      ]);
      final updatedSupply = existingSupply.copyWith(
        medicineId: appendedItems.isNotEmpty
            ? appendedItems.first.medicineId
            : supply.medicineId,
        givenByStaff: supply.givenByStaff,
        givenAt: latestGivenAt,
        qtyGiven: appendedItems.fold<int>(
          0,
          (sum, item) => sum + item.qtyGiven,
        ),
        items: appendedItems,
        status: _aggregateStatus(appendedItems),
        staffNote: supply.staffNote ?? existingSupply.staffNote,
        prescribedBy: supply.prescribedBy ?? existingSupply.prescribedBy,
        doctorPrescription:
            supply.doctorPrescription ?? existingSupply.doctorPrescription,
        supplyDays: supply.supplyDays ?? existingSupply.supplyDays,
      );
      return updateMedicineSupply(existingSupply.id!, updatedSupply);
    }

    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.v2MedicineSuppliesEndpoint,
      body: supply.toJson(),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to create medicine supply');
  }

  static Future<MedicineSupply?> _findExistingPatientSupply(
    MedicineSupply supply,
  ) async {
    final targetKey = _patientIdentityKey(supply);
    if (targetKey == null) return null;

    final supplies = await _fetchAllMedicineSupplies();
    final matches =
        supplies
            .where((item) => _patientIdentityKey(item) == targetKey)
            .toList()
          ..sort((a, b) => b.givenAt.compareTo(a.givenAt));
    return matches.isEmpty ? null : matches.first;
  }

  static List<MedicineSupplyItem> _itemsOwnedBySupply(MedicineSupply supply) {
    final supplyId = supply.id;
    final owned = supply.items
        .where((item) => item.supplyId == null || item.supplyId == supplyId)
        .map((item) => item.copyWith(givenAt: item.givenAt ?? supply.givenAt))
        .toList();
    if (owned.isNotEmpty) return owned;
    return supply.items
        .map((item) => item.copyWith(givenAt: item.givenAt ?? supply.givenAt))
        .toList();
  }

  static DateTime _latestDate(Iterable<DateTime?> values) {
    DateTime? latest;
    for (final value in values) {
      if (value == null) continue;
      if (latest == null || value.isAfter(latest)) {
        latest = value;
      }
    }
    return latest ?? DateTime.now();
  }

  static String _aggregateStatus(List<MedicineSupplyItem> items) {
    if (items.isEmpty) return 'given';
    final statuses = items.map((item) => item.status).toList();
    if (statuses.every((status) => status == 'cancelled')) return 'cancelled';
    if (statuses.every((status) => status == 'returned')) return 'returned';
    if (statuses.every((status) => status == 'given')) return 'given';
    return 'partially_given';
  }

  static String? _patientIdentityKey(MedicineSupply supply) {
    final register = supply.patientRegisterId?.trim().toLowerCase();
    if (register != null && register.isNotEmpty) return 'reg:$register';

    final name = _normalizeName(supply.patientName);
    final phone = _digitsOnly(supply.patientPhone);
    if (name.isNotEmpty && phone.isNotEmpty) return 'name_phone:$name|$phone';
    if (name.isNotEmpty && name != 'unknown') return 'name:$name';

    final id = _fieldId(supply.patientId);
    return id == null ? null : 'id:$id';
  }

  static String? _fieldId(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Map && value['_id'] != null) return value['_id'].toString();
    if (value is Map && value['id'] != null) return value['id'].toString();
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  /// Update an existing medicine supply and invalidate the cache.
  static Future<MedicineSupply> updateMedicineSupply(
    String id,
    MedicineSupply supply,
  ) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$id',
      body: supply.toJson(),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to update medicine supply');
  }

  static Future<MedicineSupply> returnMedicineSupply(
    String id, {
    required int qtyReturned,
    required DateTime returnedAt,
    required DateTime expiryDate,
    String? staffNote,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$id/return',
      body: {
        'qtyReturned': qtyReturned,
        'returnedAt': returnedAt.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        if (staffNote?.trim().isNotEmpty == true)
          'staffNote': staffNote!.trim(),
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to return medicine supply');
  }

  static Future<MedicineSupply> returnMedicineSupplyItem(
    String supplyId,
    String itemId, {
    required int qtyReturned,
    required DateTime returnedAt,
    required DateTime expiryDate,
    String? staffNote,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$supplyId/items/$itemId/return',
      body: {
        'qtyReturned': qtyReturned,
        'returnedAt': returnedAt.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        if (staffNote?.trim().isNotEmpty == true)
          'staffNote': staffNote!.trim(),
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to return medicine item');
  }

  static Future<MedicineSupply> cancelMedicineSupply(String id) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$id/cancel',
      body: const {},
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to cancel medicine supply');
  }

  static Future<MedicineSupply> cancelMedicineSupplyItem(
    String supplyId,
    String itemId, {
    String? staffNote,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$supplyId/items/$itemId/cancel',
      body: {
        if (staffNote?.trim().isNotEmpty == true)
          'staffNote': staffNote!.trim(),
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return MedicineSupply.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to cancel medicine item');
  }

  /// Delete a medicine supply and invalidate the cache.
  static Future<bool> deleteMedicineSupply(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.v2MedicineSuppliesEndpoint}/$id',
    );

    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      AppCache.invalidatePrefix('medicine_stock_entries:');
      return true;
    }

    throw Exception(result.error ?? 'Failed to delete medicine supply');
  }
}
