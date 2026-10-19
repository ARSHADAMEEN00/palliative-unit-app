import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oruma_app/models/about_us.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/app_cache.dart';

class AboutUsService {
  static const _keyAboutUs = 'unit_about_us';
  static const _ttl = Duration(minutes: 30);
  static const _offlinePrefPrefix = 'cached_about_us_';

  /// Get the unit's About Us content with dynamic tags already replaced.
  /// Supports caching and offline fallback reading.
  static Future<AboutUsData> getAboutUs({bool refresh = false}) async {
    final unitId = AppCache.currentUnitId ?? 'default';
    final offlineKey = '$_offlinePrefPrefix$unitId';

    if (refresh) {
      AppCache.invalidate(_keyAboutUs);
    }

    try {
      final data = await AppCache.get<AboutUsData>(
        _keyAboutUs,
        ttl: _ttl,
        loader: () => _fetchAboutUs(offlineKey),
      );
      return data;
    } catch (e) {
      // Offline fallback: try reading from SharedPreferences
      final cachedJson = await _readOfflineCache(offlineKey);
      if (cachedJson != null) {
        return AboutUsData.fromJson(cachedJson);
      }
      rethrow;
    }
  }

  static Future<AboutUsData> _fetchAboutUs(String offlineKey) async {
    final result = await ApiService.get<AboutUsData>(
      ApiConfig.aboutUsEndpoint,
      fromJson: (json) => AboutUsData.fromJson(json as Map<String, dynamic>),
    );

    if (result.isSuccess && result.data != null) {
      // Save to persistent offline storage
      _saveOfflineCache(offlineKey, result.data!.toJson());
      return result.data!;
    } else {
      throw Exception(result.error ?? 'Failed to load About Us content');
    }
  }

  /// Get raw About Us template and available dynamic tags for admin editor.
  static Future<AboutUsData> getAdminAboutUs() async {
    final result = await ApiService.get<AboutUsData>(
      ApiConfig.adminAboutUsEndpoint,
      fromJson: (json) => AboutUsData.fromJson(json as Map<String, dynamic>),
    );

    if (result.isSuccess && result.data != null) {
      return result.data!;
    } else {
      throw Exception(
        result.error ?? 'Failed to load About Us editor settings',
      );
    }
  }

  /// Update the About Us content (admin only).
  static Future<bool> updateAboutUs({
    required String title,
    required String content,
  }) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      ApiConfig.adminAboutUsEndpoint,
      body: {'title': title.trim(), 'content': content.trim()},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (result.isSuccess) {
      AppCache.invalidate(_keyAboutUs);
      final unitId = AppCache.currentUnitId ?? 'default';
      final offlineKey = '$_offlinePrefPrefix$unitId';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(offlineKey);
      return true;
    } else {
      throw Exception(result.error ?? 'Failed to save About Us content');
    }
  }

  /// Preview the drafted content with dynamic tags rendered against live unit data.
  static Future<String> previewAboutUs(String content) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.adminAboutUsPreviewEndpoint,
      body: {'content': content},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!['preview']?.toString() ?? '';
    } else {
      throw Exception(result.error ?? 'Failed to generate preview');
    }
  }

  static Future<void> _saveOfflineCache(
    String key,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _readOfflineCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
