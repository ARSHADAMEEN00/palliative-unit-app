import '../models/equipment.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

/// Response from bulk equipment creation
class CreateEquipmentResponse {
  final String message;
  final int count;
  final List<Equipment> equipment;

  CreateEquipmentResponse({
    required this.message,
    required this.count,
    required this.equipment,
  });

  factory CreateEquipmentResponse.fromJson(Map<String, dynamic> json) {
    final equipmentList =
        (json['equipment'] as List<dynamic>?)
            ?.map((e) => Equipment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CreateEquipmentResponse(
      message: json['message']?.toString() ?? '',
      count: json['count'] as int? ?? equipmentList.length,
      equipment: equipmentList,
    );
  }
}

/// Equipment service for CRUD operations via the backend API.
class EquipmentService {
  EquipmentService._();

  static const _prefix = 'equipment:';
  static const _keyAll = 'equipment:all';
  static const _keyAvailable = 'equipment:available';
  static const _ttl = Duration(minutes: 10);

  /// Get all equipment from the API.
  /// Results without filters are cached; searches with [search] bypass cache.
  static Future<List<Equipment>> getAllEquipment({
    String? status,
    String? search,
  }) async {
    final hasSearch = search != null && search.trim().isNotEmpty;

    // Determine a stable cache key for unfiltered/status-only requests
    final cacheKey = switch (status) {
      'available' when !hasSearch => _keyAvailable,
      null when !hasSearch => _keyAll,
      _ => null, // search or combined filters → always live
    };

    if (cacheKey != null) {
      return AppCache.get<List<Equipment>>(
        cacheKey,
        ttl: _ttl,
        loader: () => _fetchEquipment(status: status, search: search),
      );
    }

    // Search / combined filter – skip cache
    return _fetchEquipment(status: status, search: search);
  }

  static Future<List<Equipment>> _fetchEquipment({
    String? status,
    String? search,
  }) async {
    final queryParameters = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final url = Uri.parse(ApiConfig.equipmentEndpoint)
        .replace(
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        )
        .toString();

    final result = await ApiService.get<List<dynamic>>(url);
    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => Equipment.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch equipment');
  }

  /// Get only available equipment.
  static Future<List<Equipment>> getAvailableEquipment({String? search}) async {
    return getAllEquipment(status: 'available', search: search);
  }

  /// Get equipment kept in inventory, including damaged items under repair.
  /// Supplied items are shown in the distribution tab instead.
  static Future<List<Equipment>> getInventoryEquipment({String? search}) async {
    final equipment = await getAllEquipment(search: search);
    return equipment.where((item) => item.status != 'supplied').toList();
  }

  /// Get a single equipment by ID (not cached — low repeat rate).
  static Future<Equipment> getEquipmentById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.equipmentEndpoint}/$id',
    );
    if (result.isSuccess && result.data != null) {
      return Equipment.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to fetch equipment');
  }

  /// Create new equipment and invalidate the equipment cache.
  static Future<CreateEquipmentResponse> createEquipment({
    required String name,
    required int quantity,
    required String purchasedFrom,
    DateTime? purchaseDate,
    required String place,
    required String phone,
    String? serialNo,
    String? storagePlace,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.equipmentEndpoint,
      body: {
        'name': name,
        'quantity': quantity,
        'purchasedFrom': purchasedFrom,
        if (purchaseDate != null)
          'purchaseDate': purchaseDate.toIso8601String(),
        'place': place,
        'phone': phone,
        if (serialNo != null) 'serialNo': serialNo,
        if (storagePlace != null) 'storagePlace': storagePlace,
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return CreateEquipmentResponse.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to create equipment');
  }

  /// Update an existing equipment and invalidate the equipment cache.
  static Future<Equipment> updateEquipment(
    String id, {
    String? name,
    String? serialNo,
    String? purchasedFrom,
    DateTime? purchaseDate,
    String? place,
    String? phone,
    String? storagePlace,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (serialNo != null) body['serialNo'] = serialNo;
    if (purchasedFrom != null) body['purchasedFrom'] = purchasedFrom;
    if (purchaseDate != null) {
      body['purchaseDate'] = purchaseDate.toIso8601String();
    }
    if (place != null) body['place'] = place;
    if (phone != null) body['phone'] = phone;
    if (storagePlace != null) body['storagePlace'] = storagePlace;
    if (status != null) body['status'] = status;

    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.equipmentEndpoint}/$id',
      body: body,
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Equipment.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update equipment');
  }

  /// Update equipment status and invalidate the equipment cache.
  static Future<Equipment> updateStatus(String id, String status) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.equipmentEndpoint}/$id',
      body: {'status': status},
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Equipment.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update equipment status');
  }

  /// Mark equipment as damaged and unavailable for distribution.
  static Future<Equipment> markDamaged(
    String id,
    String reason, {
    DateTime? damagedAt,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.equipmentEndpoint}/$id/damage',
      body: {
        'reason': reason.trim(),
        if (damagedAt != null) 'damagedAt': _dateOnly(damagedAt),
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Equipment.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to mark equipment as damaged');
  }

  /// Clear the damaged state once repairs are complete.
  static Future<Equipment> clearDamage(
    String id, {
    required DateTime repairedAt,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.equipmentEndpoint}/$id/damage/clear',
      body: {'repairedAt': _dateOnly(repairedAt)},
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Equipment.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to clear equipment damage');
  }

  /// Delete an equipment and invalidate the equipment cache.
  static Future<bool> deleteEquipment(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.equipmentEndpoint}/$id',
    );

    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      return true;
    }
    throw Exception(result.error ?? 'Failed to delete equipment');
  }

  /// Search equipment by name or uniqueId (always live, bypasses cache).
  static Future<List<Equipment>> searchEquipment(
    String query, {
    String? status,
  }) async {
    return getAllEquipment(status: status, search: query);
  }

  static String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
