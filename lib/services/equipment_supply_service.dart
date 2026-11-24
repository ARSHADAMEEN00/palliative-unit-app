import '../models/equipment_supply.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

class EquipmentSupplyService {
  EquipmentSupplyService._();

  static const _prefix = 'eq_supplies:';
  static const _keyAll = 'eq_supplies:all';
  static const _keyActive = 'eq_supplies:active';
  static const _ttlActive = Duration(minutes: 5);
  static const _ttlAll = Duration(minutes: 10);

  /// Get all supplies. Cached when no search query is provided.
  static Future<List<EquipmentSupply>> getAllSupplies({
    String? search,
    String? localBody,
    String? wardId,
  }) async {
    final hasSearch = search != null && search.trim().isNotEmpty;

    if (hasSearch) {
      return _fetchAllSupplies(
        search: search,
        localBody: localBody,
        wardId: wardId,
      );
    }

    final hasLocationFilter =
        localBody?.trim().isNotEmpty == true ||
        wardId?.trim().isNotEmpty == true;
    if (hasLocationFilter) {
      return _fetchAllSupplies(localBody: localBody, wardId: wardId);
    }

    return AppCache.get<List<EquipmentSupply>>(
      _keyAll,
      ttl: _ttlAll,
      loader: () => _fetchAllSupplies(),
    );
  }

  static Future<List<EquipmentSupply>> _fetchAllSupplies({
    String? search,
    String? localBody,
    String? wardId,
  }) async {
    final query = <String, String>{
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (localBody?.trim().isNotEmpty == true) 'localBody': localBody!.trim(),
      if (wardId?.trim().isNotEmpty == true) 'wardId': wardId!.trim(),
    };
    final url = Uri.parse(
      ApiConfig.equipmentSuppliesEndpoint,
    ).replace(queryParameters: query.isEmpty ? null : query).toString();
    final result = await ApiService.get<List<dynamic>>(url);
    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => EquipmentSupply.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch supplies');
  }

  /// Get active supplies. Cached when no search query is provided.
  static Future<List<EquipmentSupply>> getActiveSupplies({
    String? search,
    String? localBody,
    String? wardId,
  }) async {
    final hasSearch = search != null && search.trim().isNotEmpty;

    if (hasSearch) {
      return _fetchActiveSupplies(
        search: search,
        localBody: localBody,
        wardId: wardId,
      );
    }

    final hasLocationFilter =
        localBody?.trim().isNotEmpty == true ||
        wardId?.trim().isNotEmpty == true;
    if (hasLocationFilter) {
      return _fetchActiveSupplies(localBody: localBody, wardId: wardId);
    }

    return AppCache.get<List<EquipmentSupply>>(
      _keyActive,
      ttl: _ttlActive,
      loader: () => _fetchActiveSupplies(),
    );
  }

  static Future<List<EquipmentSupply>> _fetchActiveSupplies({
    String? search,
    String? localBody,
    String? wardId,
  }) async {
    final query = <String, String>{
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (localBody?.trim().isNotEmpty == true) 'localBody': localBody!.trim(),
      if (wardId?.trim().isNotEmpty == true) 'wardId': wardId!.trim(),
    };
    final url = Uri.parse(
      '${ApiConfig.equipmentSuppliesEndpoint}/active',
    ).replace(queryParameters: query.isEmpty ? null : query).toString();
    final result = await ApiService.get<List<dynamic>>(url);
    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => EquipmentSupply.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch active supplies');
  }

  /// Get supply by ID (not cached — single-record lookup).
  static Future<EquipmentSupply> getById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.equipmentSuppliesEndpoint}/$id',
    );
    if (result.isSuccess && result.data != null) {
      return EquipmentSupply.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to fetch supply');
  }

  /// Create new supply and invalidate the equipment supplies cache.
  static Future<EquipmentSupply> createSupply(EquipmentSupply supply) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.equipmentSuppliesEndpoint,
      body: supply.toJson(),
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return EquipmentSupply.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to create supply');
  }

  /// Update supply and invalidate the equipment supplies cache.
  static Future<EquipmentSupply> updateSupply(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.equipmentSuppliesEndpoint}/$id',
      body: updates,
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return EquipmentSupply.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update supply');
  }

  /// Mark supply as returned and invalidate the equipment supplies cache.
  static Future<EquipmentSupply> returnSupply(
    String id, {
    DateTime? date,
    String? note,
  }) async {
    final updates = {
      if (date != null) 'actualReturnDate': date.toIso8601String(),
      if (note != null && note.isNotEmpty) 'returnNote': note,
    };
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.equipmentSuppliesEndpoint}/$id/return',
      body: updates,
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return EquipmentSupply.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to mark supply as returned');
  }

  /// Delete supply and invalidate the equipment supplies cache.
  static Future<bool> deleteSupply(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.equipmentSuppliesEndpoint}/$id',
    );
    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      return true;
    }
    throw Exception(result.error ?? 'Failed to delete supply');
  }
}
