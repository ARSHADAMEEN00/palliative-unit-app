import '../models/medicine_stock_entry.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

class MedicineStockService {
  MedicineStockService._();

  static const _prefix = 'medicine_stock_entries:';
  static const _keyHistory = 'medicine_stock_entries:history';
  static const _ttl = Duration(minutes: 5);

  static Future<List<MedicineStockEntry>> getHistory({
    String? search,
    String? medicineId,
  }) async {
    final trimmed = search?.trim();
    final trimmedMedicineId = medicineId?.trim();
    final hasSearch = trimmed != null && trimmed.isNotEmpty;
    final hasMedicineFilter =
        trimmedMedicineId != null && trimmedMedicineId.isNotEmpty;
    if (hasSearch || hasMedicineFilter) {
      return _fetchHistory(search: trimmed, medicineId: trimmedMedicineId);
    }

    return AppCache.get<List<MedicineStockEntry>>(
      _keyHistory,
      ttl: _ttl,
      loader: _fetchHistory,
    );
  }

  static Future<List<MedicineStockEntry>> _fetchHistory({
    String? search,
    String? medicineId,
  }) async {
    var url = ApiConfig.v2MedicineStockEntriesEndpoint;
    final params = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (medicineId != null && medicineId.trim().isNotEmpty) {
      params['medicineId'] = medicineId.trim();
    }
    if (params.isNotEmpty) {
      url += '?${Uri(queryParameters: params).query}';
    }

    final result = await ApiService.get<List<dynamic>>(url);
    if (result.isSuccess && result.data != null) {
      return result.data!
          .map(
            (json) => MedicineStockEntry.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception(result.error ?? 'Failed to fetch medicine stock history');
  }

  static Future<List<MedicineStockEntry>> createBulkStockEntries(
    List<MedicineStockEntryDraft> entries,
  ) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineStockEntriesEndpoint}/bulk',
      body: {'entries': entries.map((entry) => entry.toJson()).toList()},
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');

      final rawEntries = result.data!['entries'] as List<dynamic>? ?? const [];
      return rawEntries
          .map(
            (json) => MedicineStockEntry.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception(result.error ?? 'Failed to add medicine stock');
  }

  static Future<MedicineStockEntry> updateStockEntry(
    String id, {
    required double quantity,
    required DateTime expiryDate,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineStockEntriesEndpoint}/$id',
      body: {'quantity': quantity, 'expiryDate': expiryDate.toIso8601String()},
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      return MedicineStockEntry.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to update medicine stock');
  }

  static Future<MedicineStockEntry> returnBatchToMainStock(
    String batchId, {
    required double qtyReturned,
    String? note,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.v2MedicineStockEntriesEndpoint}/$batchId/return',
      body: {
        'qtyReturned': qtyReturned,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidatePrefix('medicines:');
      final entry = result.data!['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        return MedicineStockEntry.fromJson(entry);
      }
    }

    throw Exception(result.error ?? 'Failed to return medicine batch');
  }

  static void invalidateCache() {
    AppCache.invalidatePrefix(_prefix);
  }
}
