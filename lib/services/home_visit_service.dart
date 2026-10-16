import '../models/home_visit.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

/// HomeVisit service for CRUD operations via the backend API.
class HomeVisitService {
  HomeVisitService._();

  static const _prefix = 'home_visits:';
  static const _keyAll = 'home_visits:all';
  static const _ttl = Duration(minutes: 5);

  /// Get all home visits from the API. Cached for [_ttl].
  static Future<List<HomeVisit>> getAllHomeVisits() async {
    return AppCache.get<List<HomeVisit>>(
      _keyAll,
      ttl: _ttl,
      loader: _fetchAllHomeVisits,
    );
  }

  static Future<List<HomeVisit>> _fetchAllHomeVisits() async {
    final result = await ApiService.get<List<dynamic>>(
      ApiConfig.homeVisitsEndpoint,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => HomeVisit.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw Exception(result.error ?? 'Failed to fetch home visits');
  }

  /// Get a single home visit by ID. Cached for [_ttl].
  static Future<HomeVisit> getHomeVisitById(String id) async {
    return AppCache.get<HomeVisit>(
      '$_prefix$id',
      ttl: _ttl,
      loader: () async {
        final result = await ApiService.get<Map<String, dynamic>>(
          '${ApiConfig.homeVisitsEndpoint}/$id',
        );

        if (result.isSuccess && result.data != null) {
          return HomeVisit.fromJson(result.data!);
        }

        throw Exception(result.error ?? 'Failed to fetch home visit');
      },
    );
  }

  /// Get a single home visit by ID, returning null when it was deleted.
  static Future<HomeVisit?> findHomeVisitById(String id) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.homeVisitsEndpoint}/$id',
    );

    if (result.isSuccess && result.data != null) {
      return HomeVisit.fromJson(result.data!);
    }

    if (result.statusCode == 404) {
      return null;
    }

    throw Exception(result.error ?? 'Failed to fetch home visit');
  }

  /// Create a new home visit and invalidate the home visits cache.
  static Future<HomeVisit> createHomeVisit(HomeVisit homeVisit) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.homeVisitsEndpoint,
      body: homeVisit.toJson(),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return HomeVisit.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to create home visit');
  }

  /// Update an existing home visit and invalidate the home visits cache.
  static Future<HomeVisit> updateHomeVisit(
    String id,
    HomeVisit homeVisit,
  ) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.homeVisitsEndpoint}/$id',
      body: homeVisit.toJson(),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return HomeVisit.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to update home visit');
  }

  /// Delete a home visit and invalidate the home visits cache.
  static Future<bool> deleteHomeVisit(String id) async {
    final result = await ApiService.delete(
      '${ApiConfig.homeVisitsEndpoint}/$id',
    );

    if (result.isSuccess) {
      AppCache.invalidatePrefix(_prefix);
      return true;
    }

    throw Exception(result.error ?? 'Failed to delete home visit');
  }
}
