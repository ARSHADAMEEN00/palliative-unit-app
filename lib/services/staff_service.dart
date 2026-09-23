import 'package:oruma_app/models/staff_user.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/app_cache.dart';

class StaffService {
  StaffService._();

  static const _keyAll = 'staff:all';
  static const _ttl = Duration(minutes: 10);

  static Future<List<StaffUser>> getStaff() async {
    return AppCache.get<List<StaffUser>>(
      _keyAll,
      ttl: _ttl,
      loader: _fetchStaff,
    );
  }

  static Future<List<StaffUser>> _fetchStaff() async {
    final result = await ApiService.get<List<dynamic>>(ApiConfig.staffEndpoint);

    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => StaffUser.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw Exception(result.error ?? 'Failed to fetch staff');
  }

  static Future<StaffUser> createStaff({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.staffEndpoint,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
      },
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidate(_keyAll);
      return StaffUser.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to create staff');
  }

  static Future<StaffUser> updateRole(String id, String role) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.staffEndpoint}/$id/role',
      body: {'role': role},
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidate(_keyAll);
      return StaffUser.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to update staff role');
  }
}
