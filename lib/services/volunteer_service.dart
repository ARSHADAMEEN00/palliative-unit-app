import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/app_cache.dart';

class VolunteerService {
  VolunteerService._();

  static const _prefix = 'volunteers:';
  static const _keyAll = 'volunteers:all';
  static const _ttl = Duration(minutes: 10);

  static Future<List<Volunteer>> getVolunteers({
    String? search,
    String? village,
    String? ward,
  }) async {
    final hasFilters =
        (search?.trim().isNotEmpty ?? false) ||
        (village?.trim().isNotEmpty ?? false) ||
        (ward?.trim().isNotEmpty ?? false);

    if (hasFilters) {
      return _fetchVolunteers(search: search, village: village, ward: ward);
    }

    return AppCache.get<List<Volunteer>>(
      _keyAll,
      ttl: _ttl,
      loader: () => _fetchVolunteers(),
    );
  }

  static Future<List<Volunteer>> _fetchVolunteers({
    String? search,
    String? village,
    String? ward,
  }) async {
    final query = <String, String>{};
    if (search?.trim().isNotEmpty == true) query['search'] = search!.trim();
    if (village?.trim().isNotEmpty == true) query['village'] = village!.trim();
    if (ward?.trim().isNotEmpty == true) query['ward'] = ward!.trim();

    final uri = Uri.parse(
      ApiConfig.v2VolunteersEndpoint,
    ).replace(queryParameters: query.isEmpty ? null : query);

    final result = await ApiService.get<List<dynamic>>(uri.toString());
    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => Volunteer.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw Exception(result.error ?? 'Failed to fetch volunteers');
  }

  static Future<Volunteer> getVolunteerById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.v2VolunteersEndpoint}/$id',
    );
    if (result.isSuccess && result.data != null) {
      return Volunteer.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to fetch volunteer');
  }

  static Future<Volunteer> createVolunteer(Volunteer volunteer) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.v2VolunteersEndpoint,
      body: volunteer.toJson(),
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Volunteer.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to create volunteer');
  }

  static Future<Volunteer> updateVolunteer(
    String id,
    Volunteer volunteer,
  ) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.v2VolunteersEndpoint}/$id',
      body: volunteer.toJson(),
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Volunteer.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update volunteer');
  }

  static Future<bool> deleteVolunteer(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.v2VolunteersEndpoint}/$id',
    );
    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      return true;
    }
    throw Exception(result.error ?? 'Failed to delete volunteer');
  }

  static Future<Volunteer> reviewApplication(String id, String status) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.v2VolunteersEndpoint}/$id/application',
      body: {'status': status},
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return Volunteer.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to review volunteer application');
  }
}
