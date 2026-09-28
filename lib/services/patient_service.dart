import '../models/patient.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

/// Patient service for CRUD operations via the backend API.
class PatientService {
  PatientService._();

  static const _prefix = 'patients:';
  static const _ttl = Duration(minutes: 5);

  /// Get all patients from the API. Adapter for legacy calls.
  static Future<List<Patient>> getAllPatients({bool? isDead}) async {
    String filter = 'all';
    if (isDead == true) {
      filter = 'dead';
    } else if (isDead == false) {
      filter = 'alive';
    }

    final response = await getPatientsList(filter: filter);
    return response.patients;
  }

  /// Get patients with filter and counts.
  /// Results are cached per unique [filter] string when no village/ward
  /// filter is applied. Filtered sub-views are always fetched live.
  static Future<PatientListResponse> getPatientsList({
    String filter = 'all',
    String? village,
    String? ward,
  }) async {
    final hasSubFilter =
        (village != null && village.isNotEmpty) ||
        (ward != null && ward.isNotEmpty);

    // Only cache unfiltered list views — village/ward sub-views are live
    if (!hasSubFilter) {
      return AppCache.get<PatientListResponse>(
        'patients:$filter',
        ttl: _ttl,
        loader: () => _fetchPatientsList(
          filter: filter,
          village: village,
          ward: ward,
        ),
      );
    }

    return _fetchPatientsList(filter: filter, village: village, ward: ward);
  }

  static Future<PatientListResponse> _fetchPatientsList({
    String filter = 'all',
    String? village,
    String? ward,
  }) async {
    String query =
        '${ApiConfig.patientsEndpoint}?filter=$filter&populate=createdBy';
    if (village != null && village.isNotEmpty) {
      query += '&village=${Uri.encodeComponent(village)}';
    }
    if (ward != null && ward.isNotEmpty) {
      query += '&ward=${Uri.encodeComponent(ward)}';
    }
    final result = await ApiService.get<dynamic>(query);

    if (result.isSuccess && result.data != null) {
      if (result.data is Map<String, dynamic>) {
        return PatientListResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
      } else if (result.data is List) {
        final list = (result.data as List)
            .map((json) => Patient.fromJson(json as Map<String, dynamic>))
            .toList();

        final allCount = list.length;
        final deadCount = list.where((p) => p.isDead).length;
        final aliveCount = list.where((p) => !p.isDead).length;

        return PatientListResponse(
          patients: list,
          counts: PatientCounts(
            allCount: allCount,
            deadCount: deadCount,
            aliveCount: aliveCount,
          ),
        );
      }
    }

    throw Exception(result.error ?? 'Failed to fetch patients');
  }

  /// Get a single patient by ID (not cached — low repeat rate).
  static Future<Patient> getPatientById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.patientsEndpoint}/$id?populate=createdBy',
    );

    if (result.isSuccess && result.data != null) {
      return Patient.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to fetch patient');
  }

  /// Create a new patient and invalidate the patients cache.
  static Future<Patient> createPatient(Patient patient) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.patientsEndpoint,
      body: patient.toJson(),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Patient.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to create patient');
  }

  /// Update an existing patient and invalidate the patients cache.
  static Future<Patient> updatePatient(String id, Patient patient) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.patientsEndpoint}/$id',
      body: patient.toJson(),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Patient.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to update patient');
  }

  /// Delete a patient and invalidate the patients cache.
  static Future<bool> deletePatient(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.patientsEndpoint}/$id',
    );

    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      return true;
    }

    throw Exception(result.error ?? 'Failed to delete patient');
  }

  /// Search patients by name or register number — always live, bypasses cache.
  static Future<List<Patient>> searchPatients(
    String query, {
    bool? isDead,
  }) async {
    String searchQuery =
        '${ApiConfig.patientsEndpoint}?search=${Uri.encodeComponent(query)}&populate=createdBy';
    if (isDead != null) {
      searchQuery += '&isDead=$isDead';
    }

    final result = await ApiService.get<dynamic>(searchQuery);

    if (result.isSuccess && result.data != null) {
      if (result.data is Map<String, dynamic>) {
        final rawList = (result.data as Map<String, dynamic>)['patients'];
        if (rawList is List) {
          return rawList
              .map((json) => Patient.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } else if (result.data is List) {
        return (result.data as List)
            .map((json) => Patient.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    throw Exception(result.error ?? 'Failed to search patients');
  }
}
