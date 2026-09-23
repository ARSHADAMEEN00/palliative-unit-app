import '../models/medicine.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

class MedicineService {
  MedicineService._();

  static const _prefix = 'medicines:';
  static const _keyAll = 'medicines:all';
  static const _ttl = Duration(minutes: 15);

  /// Get all medicines. Cached for [_ttl] when no search query is given.
  /// Search results are always fetched live (dynamic, parameterised queries).
  static Future<List<Medicine>> getMedicines({String? search}) async {
    final trimmed = search?.trim();
    final hasSearch = trimmed != null && trimmed.isNotEmpty;

    // Skip cache for search queries — results are highly dynamic
    if (hasSearch) {
      return _fetchMedicines(search: trimmed);
    }

    return AppCache.get<List<Medicine>>(
      _keyAll,
      ttl: _ttl,
      loader: () => _fetchMedicines(),
    );
  }

  static Future<List<Medicine>> _fetchMedicines({String? search}) async {
    var url = ApiConfig.v2MedicinesEndpoint;
    if (search != null) {
      url += '?search=${Uri.encodeQueryComponent(search)}';
    }
    final result = await ApiService.get<List<dynamic>>(url);
    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((item) => Medicine.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch medicines');
  }

  static Future<Medicine> getMedicineById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.v2MedicinesEndpoint}/$id',
    );
    if (result.isSuccess && result.data != null) {
      return Medicine.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to fetch medicine');
  }

  static Future<String> getNextMedicineCode() async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.v2MedicinesEndpoint}/next-code',
    );
    final code = result.data?['code']?.toString().trim();
    if (result.isSuccess && code != null && code.isNotEmpty) {
      return code;
    }
    throw Exception(result.error ?? 'Failed to generate medicine code');
  }

  /// Create a medicine and invalidate the medicines cache.
  static Future<Medicine> createMedicine(Medicine medicine) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.v2MedicinesEndpoint,
      body: medicine.toJson(),
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Medicine.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to create medicine');
  }

  /// Update a medicine and invalidate the medicines cache.
  static Future<Medicine> updateMedicine(String id, Medicine medicine) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.v2MedicinesEndpoint}/$id',
      body: medicine.toJson(),
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Medicine.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update medicine');
  }

  /// Delete a medicine and invalidate the medicines cache.
  static Future<bool> deleteMedicine(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.v2MedicinesEndpoint}/$id',
    );
    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      return true;
    }
    throw Exception(result.error ?? 'Failed to delete medicine');
  }
}
