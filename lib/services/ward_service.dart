import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/ward.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/app_cache.dart';

class WardService {
  WardService._();

  static const _cacheKey = 'wards:all';

  static Future<List<Ward>> getWards({
    bool includeInactive = false,
    bool forceRefresh = false,
  }) async {
    Future<List<Ward>> load() async {
      final suffix = includeInactive ? '?includeInactive=true' : '';
      final result = await ApiService.get<Map<String, dynamic>>(
        '${ApiConfig.wardsEndpoint}$suffix',
      );
      if (result.isSuccess && result.data != null) {
        return (result.data!['wards'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => Ward.fromJson(Map<String, dynamic>.from(value)))
            .toList();
      }
      throw Exception(result.error ?? 'Failed to fetch wards');
    }

    if (forceRefresh) AppCache.invalidate(_cacheKey);
    return AppCache.get<List<Ward>>(
      includeInactive ? '$_cacheKey:inactive' : _cacheKey,
      ttl: const Duration(minutes: 10),
      loader: load,
    );
  }

  static Future<List<Ward>> getTransferTargets() async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/transfer-targets',
    );
    if (result.isSuccess && result.data != null) {
      return (result.data!['wards'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => Ward.fromJson(Map<String, dynamic>.from(value)))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch ward choices');
  }

  static Future<Ward> createWard({required String name, String? code}) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.wardsEndpoint,
      body: {'name': name.trim(), 'code': code?.trim()},
    );
    if (result.isSuccess && result.data != null) {
      _invalidate();
      return Ward.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to create ward');
  }

  static Future<Ward> updateWard(
    String id, {
    required String name,
    String? code,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/$id',
      body: {'name': name.trim(), 'code': code?.trim()},
    );
    if (result.isSuccess && result.data != null) {
      _invalidate();
      return Ward.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update ward');
  }

  static Future<Ward> deactivateWard(String id) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/$id/deactivate',
      body: const {},
    );
    if (result.isSuccess && result.data != null) {
      _invalidate();
      return Ward.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to deactivate ward');
  }

  static Future<List<Ward>> setStaffWards(
    String userId,
    List<String> wardIds,
  ) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/staff/$userId',
      body: {'wardIds': wardIds},
    );
    if (result.isSuccess && result.data != null) {
      return (result.data!['wards'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => Ward.fromJson(Map<String, dynamic>.from(value)))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to update staff wards');
  }

  static Future<List<PatientWardHistoryEntry>> getPatientHistory(
    String patientId,
  ) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/patients/$patientId/history',
    );
    if (result.isSuccess && result.data != null) {
      return (result.data!['history'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (value) => PatientWardHistoryEntry.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch ward history');
  }

  static Future<Patient> transferPatient({
    required String patientId,
    required String toWardId,
    String? note,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/patients/$patientId/transfer',
      body: {'toWardId': toWardId, 'note': note?.trim()},
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix('patients:');
      return Patient.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to move patient');
  }

  static Future<List<WardPatientCount>> getPatientCounts() async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.wardsEndpoint}/patient-counts',
    );
    if (result.isSuccess && result.data != null) {
      return (result.data!['counts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                WardPatientCount.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList();
    }
    throw Exception(result.error ?? 'Failed to fetch ward patient counts');
  }

  static void _invalidate() {
    AppCache.invalidatePrefix('wards:');
  }
}
