import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/app_cache.dart';

/// Service for fetching application configuration data.
class ConfigService {
  static const _keyConfig = 'config';
  static const _ttl = Duration(minutes: 60);

  static Future<Config> getConfig({bool forceRefresh = false}) async {
    if (forceRefresh) AppCache.invalidate(_keyConfig);
    return AppCache.get<Config>(
      _keyConfig,
      ttl: _ttl,
      loader: () => _fetchConfig(),
    );
  }

  static Future<Config> _fetchConfig() async {
    final url = '${ApiConfig.baseUrl}/config';
    final result = await ApiService.get<Config>(
      url,
      fromJson: (json) => Config.fromJson(json),
    );

    if (result.isSuccess && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.error ?? 'Failed to fetch configuration');
    }
  }

  /// Update configuration data. Invalidates the cache so the next
  /// [getConfig] call fetches fresh data from the server.
  static Future<Config> updateConfig(Config config) async {
    final url = '${ApiConfig.baseUrl}/config';
    final result = await ApiService.put<Config>(
      url,
      body: config.toJson(),
      fromJson: (json) => Config.fromJson(json),
    );

    if (result.isSuccess && result.data != null) {
      AppCache.invalidate(_keyConfig);
      return result.data!;
    } else {
      throw Exception(result.error ?? 'Failed to update configuration');
    }
  }

  static Future<Config> renameLocalBody({
    required String currentName,
    required String newName,
  }) {
    return _renameLsgEntry({
      'type': 'localBody',
      'currentName': currentName,
      'newName': newName,
    });
  }

  static Future<Config> renameWard({
    required String localBody,
    required String wardNumber,
    required String newName,
  }) {
    return _renameLsgEntry({
      'type': 'ward',
      'localBody': localBody,
      'wardNumber': wardNumber,
      'newName': newName,
    });
  }

  static Future<Config> _renameLsgEntry(Map<String, dynamic> body) async {
    final result = await ApiService.patch<Config>(
      '${ApiConfig.baseUrl}/config/lsg-name',
      body: body,
      fromJson: (json) => Config.fromJson(json),
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidate(_keyConfig);
      AppCache.invalidatePrefix('wards:');
      AppCache.invalidatePrefix('patients:');
      return result.data!;
    }
    throw Exception(result.error ?? 'Failed to rename LSG entry');
  }
}
