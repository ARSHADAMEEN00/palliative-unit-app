import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredCredentials {
  const StoredCredentials({this.token, this.role, this.unitId});

  final String? token;
  final String? role;
  final String? unitId;
}

/// Stores authentication credentials in platform-protected encrypted storage.
///
/// Existing installations are migrated once from SharedPreferences so users do
/// not have to sign in again after this production security update.
class CredentialStore {
  CredentialStore._();

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _unitIdKey = 'auth_unit_id';
  static const _storage = FlutterSecureStorage();

  static String? _cachedToken;
  static String? _cachedRole;
  static String? _cachedUnitId;

  static Future<StoredCredentials> read() async {
    if (_cachedToken != null) {
      return StoredCredentials(
        token: _cachedToken,
        role: _cachedRole,
        unitId: _cachedUnitId,
      );
    }

    var token = await _storage.read(key: _tokenKey);
    var role = await _storage.read(key: _roleKey);
    var unitId = await _storage.read(key: _unitIdKey);

    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString(_tokenKey);
    final legacyRole = preferences.getString(_roleKey);
    final legacyUnitId = preferences.getString(_unitIdKey);

    if (token == null && legacyToken != null) {
      token = legacyToken;
      await _storage.write(key: _tokenKey, value: legacyToken);
    }
    if (role == null && legacyRole != null) {
      role = legacyRole;
      await _storage.write(key: _roleKey, value: legacyRole);
    }
    if (unitId == null && legacyUnitId != null) {
      unitId = legacyUnitId;
      await _storage.write(key: _unitIdKey, value: legacyUnitId);
    }

    if (legacyToken != null || legacyRole != null || legacyUnitId != null) {
      await preferences.remove(_tokenKey);
      await preferences.remove(_roleKey);
      await preferences.remove(_unitIdKey);
    }

    _cachedToken = token;
    _cachedRole = role;
    _cachedUnitId = unitId;

    return StoredCredentials(token: token, role: role, unitId: unitId);
  }

  static Future<String?> readToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  static Future<String?> readUnitId() async {
    if (_cachedUnitId != null) return _cachedUnitId;
    _cachedUnitId = await _storage.read(key: _unitIdKey);
    return _cachedUnitId;
  }

  static Future<void> write({
    required String token,
    String? role,
    String? unitId,
  }) async {
    _cachedToken = token;
    _cachedRole = role;
    _cachedUnitId = unitId;

    await _storage.write(key: _tokenKey, value: token);
    if (role == null) {
      await _storage.delete(key: _roleKey);
    } else {
      await _storage.write(key: _roleKey, value: role);
    }
    if (unitId == null) {
      await _storage.delete(key: _unitIdKey);
    } else {
      await _storage.write(key: _unitIdKey, value: unitId);
    }
  }

  static Future<void> clear() async {
    _cachedToken = null;
    _cachedRole = null;
    _cachedUnitId = null;

    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _unitIdKey);

    // Also remove legacy values in case an interrupted migration left them.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
    await preferences.remove(_unitIdKey);
  }
}
