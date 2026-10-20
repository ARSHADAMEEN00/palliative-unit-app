import 'package:oruma_app/models/staff_user.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/app_cache.dart';

class RolePermissionSettings {
  const RolePermissionSettings({
    required this.allModuleIds,
    required this.subscribedModuleIds,
    required this.rolePermissions,
  });

  final List<String> allModuleIds;
  final Set<String> subscribedModuleIds;
  final Map<String, Set<String>> rolePermissions;

  factory RolePermissionSettings.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['rolePermissions'];
    final roles = rawRoles is Map
        ? Map<String, dynamic>.from(rawRoles)
        : <String, dynamic>{};
    return RolePermissionSettings(
      allModuleIds: _stringList(json['allModuleIds']),
      subscribedModuleIds: _stringList(json['subscribedModuleIds']).toSet(),
      rolePermissions: {
        for (final role in const ['admin', 'staff', 'member', 'volunteer'])
          role: _stringList(roles[role]).toSet(),
      },
    );
  }
}

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

  static const _keyPermissions = 'staff:permissions';

  static Future<RolePermissionSettings> getRolePermissions() async {
    return AppCache.get<RolePermissionSettings>(
      _keyPermissions,
      ttl: const Duration(minutes: 15),
      loader: () async {
        final result = await ApiService.get<Map<String, dynamic>>(
          ApiConfig.rolePermissionsEndpoint,
        );
        if (result.isSuccess && result.data != null) {
          return RolePermissionSettings.fromJson(result.data!);
        }
        throw Exception(result.error ?? 'Failed to fetch role permissions');
      },
    );
  }

  static Future<Set<String>> updateRolePermissions({
    required String role,
    required List<String> permittedModuleIds,
  }) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.rolePermissionsEndpoint}/$role',
      body: {'permittedModuleIds': permittedModuleIds},
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidate(_keyPermissions);
      return _stringList(result.data!['permittedModuleIds']).toSet();
    }
    throw Exception(result.error ?? 'Failed to update role permissions');
  }

  static Future<StaffUser> createStaff({
    required String name,
    required String email,
    required String password,
    required String role,
    List<String>? permittedModuleIds,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.staffEndpoint,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        if (permittedModuleIds != null)
          'permittedModuleIds': permittedModuleIds,
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

  static Future<StaffUser> updateStaff({
    required String id,
    required String name,
    required String email,
    required String role,
    required List<String> permittedModuleIds,
    String? password,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.staffEndpoint}/$id',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'permittedModuleIds': permittedModuleIds,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidate(_keyAll);
      return StaffUser.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to update staff');
  }

  static Future<void> deleteStaff(String id) async {
    final result = await ApiService.delete('${ApiConfig.staffEndpoint}/$id');
    if (result.isSuccess) {
      AppCache.invalidate(_keyAll);
      return;
    }
    throw Exception(result.error ?? 'Failed to delete staff');
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
