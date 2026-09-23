import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredCredentials {
  const StoredCredentials({this.token, this.role});

  final String? token;
  final String? role;
}

/// Stores authentication credentials in platform-protected encrypted storage.
///
/// Existing installations are migrated once from SharedPreferences so users do
/// not have to sign in again after this production security update.
class CredentialStore {
  CredentialStore._();

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _storage = FlutterSecureStorage();

  static Future<StoredCredentials> read() async {
    var token = await _storage.read(key: _tokenKey);
    var role = await _storage.read(key: _roleKey);

    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString(_tokenKey);
    final legacyRole = preferences.getString(_roleKey);

    if (token == null && legacyToken != null) {
      token = legacyToken;
      await _storage.write(key: _tokenKey, value: legacyToken);
    }
    if (role == null && legacyRole != null) {
      role = legacyRole;
      await _storage.write(key: _roleKey, value: legacyRole);
    }

    if (legacyToken != null || legacyRole != null) {
      await preferences.remove(_tokenKey);
      await preferences.remove(_roleKey);
    }

    return StoredCredentials(token: token, role: role);
  }

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<void> write({required String token, String? role}) async {
    await _storage.write(key: _tokenKey, value: token);
    if (role == null) {
      await _storage.delete(key: _roleKey);
    } else {
      await _storage.write(key: _roleKey, value: role);
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);

    // Also remove legacy values in case an interrupted migration left them.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
  }
}
