import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/app_cache.dart';
import 'package:oruma_app/services/feature_permissions.dart';

class AuthService with ChangeNotifier {
  // Use ApiConfig to get the correct base URL
  String get _baseUrl => '${ApiConfig.baseUrl}/auth';

  String? _token;
  String? get token => _token;

  String? _role;
  String? get role => _role;

  bool _isFirstLogin = false;
  bool get isFirstLogin => _isFirstLogin;

  bool _isAccessBlocked = false;
  bool get isAccessBlocked => _isAccessBlocked;

  String? _accessBlockedMessage;
  String? get accessBlockedMessage => _accessBlockedMessage;

  Map<String, dynamic>? _accessBlockedSupport;
  Map<String, dynamic>? get accessBlockedSupport => _accessBlockedSupport;

  FeaturePermissionSnapshot? _featurePermissions;
  FeaturePermissionSnapshot? get featurePermissions => _featurePermissions;

  bool _featurePermissionsLoaded = false;
  bool get featurePermissionsLoaded => _featurePermissionsLoaded;

  String? _loginErrorMessage;
  String? get loginErrorMessage => _loginErrorMessage;

  bool get isAuthenticated => _token != null;
  bool get isAdmin => _role == 'admin';
  bool get isStaff => _role == 'staff';
  bool get isUser => _role == 'user';
  bool get isMember => _role == 'member';

  bool get canCreate =>
      _role == 'admin' || _role == 'staff' || _role == 'member';
  bool get canEdit => _role == 'admin' || _role == 'staff' || _role == 'member';
  bool get canDelete => _role == 'admin';
  bool get canAccessPatients => hasFeature(AppFeature.patients);
  bool get canAccessHomeVisits => hasFeature(AppFeature.homeVisits);
  bool get canAccessVolunteers => hasFeature(AppFeature.volunteers);
  bool get canAccessSocialSupport => hasFeature(AppFeature.socialSupport);
  bool get canAccessEquipment => hasFeature(AppFeature.equipment);
  bool get canAccessEquipmentDistribution =>
      hasFeature(AppFeature.equipmentDistribution);
  bool get canAccessMedicineMaster => hasFeature(AppFeature.medicineMaster);
  bool get canAccessMedicineStock => hasFeature(AppFeature.medicineStock);
  bool get canAccessMedicineSupply => hasFeature(AppFeature.medicineSupply);
  bool get canAccessMedicine =>
      canAccessMedicineMaster ||
      canAccessMedicineStock ||
      canAccessMedicineSupply;
  bool get canAccessNHC => hasFeature(AppFeature.nhcAssessment);
  bool get canAccessNHCReport => hasFeature(AppFeature.nhcPdf);
  bool get canAccessPatientPdf => hasFeature(AppFeature.patientPdf);

  Set<String> get enabledFeatureIds =>
      _featurePermissions?.enabledFeatureIds ??
      _stringSet(_user?['enabledFeatureIds'] ?? unit?['enabledFeatureIds']);

  bool hasFeature(String featureId) {
    if (_role == 'superadmin') return true;
    if (_featurePermissionsLoaded) {
      return _featurePermissions?.has(featureId) ?? false;
    }
    return _legacyFeatureAccess(featureId);
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _role = prefs.getString('auth_role');
    debugPrint('Auth service initialized. Role: $_role');
    if (_token != null) {
      await fetchUserProfile();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isAccessBlocked = false;
        _accessBlockedMessage = null;
        _accessBlockedSupport = null;
        _loginErrorMessage = null;
        _token = data['token'];
        _role = data['role']; // Get role from response

        final prefs = await SharedPreferences.getInstance();

        // Check if this is the first login for this user
        final wasLoggedInBefore = prefs.containsKey('auth_token');
        _isFirstLogin = !wasLoggedInBefore;

        await prefs.setString('auth_token', _token!);
        if (_role != null) {
          await prefs.setString('auth_role', _role!);
        }

        debugPrint('Login Successful. Role: $_role');

        // Fetch user profile after successful login
        await fetchUserProfile();

        notifyListeners();
        return true;
      }
      await _handleAuthFailure(response);
      return false;
    } catch (e) {
      print('Login error: $e');
      _loginErrorMessage = 'Unable to connect. Please try again.';
      return false;
    }
  }

  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;

  Map<String, dynamic>? get unit {
    final value = _user?['unit'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? get unitId => _cleanString(_user?['unitId'] ?? unit?['id']);

  String get unitName =>
      _firstText([unit?['name'], _user?['unitName']], fallback: 'CareNest');

  String get unitLocation {
    final locationParts = [
      _cleanString(unit?['village']),
      _cleanString(unit?['district']),
    ].whereType<String>().toList();
    if (locationParts.isNotEmpty) return locationParts.join(', ');
    return _firstText([unit?['address']], fallback: 'Healthcare Management');
  }

  String? get unitLogo => _cleanString(unit?['logo']);
  String? get unitAppIcon => _cleanString(unit?['appIcon']);
  String? get unitSupportQr => _cleanString(unit?['supportQr']);
  String? get unitStatus =>
      _cleanString(unit?['status'] ?? _user?['status'])?.toLowerCase();
  String? get unitSubscriptionStatus => _cleanString(
    unit?['subscriptionStatus'] ?? _user?['subscriptionStatus'],
  )?.toLowerCase();
  bool get isTrialUnit =>
      unitStatus == 'trial' || unitSubscriptionStatus == 'trial';

  String? get unitSupportName =>
      _cleanString(_supportValue('name')) ?? unitName;

  String? get unitSupportEmail =>
      _cleanString(_supportValue('email')) ??
      _cleanString(unit?['contactEmail']);

  String? get unitSupportPhone =>
      _cleanString(_supportValue('phone')) ??
      _cleanString(unit?['contactPhone']);

  String? get unitSupportPhoneDial {
    final phone = unitSupportPhone;
    if (phone == null) return null;
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> fetchUserProfile() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.meEndpoint),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data;
        _applyFeaturePermissions(data);
        await refreshFeaturePermissions(notify: false);
        _isAccessBlocked = false;
        _accessBlockedMessage = null;
        _accessBlockedSupport = null;
        notifyListeners();
      } else {
        await _handleAuthFailure(response);
        print('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  Future<void> refreshFeaturePermissions({bool notify = true}) async {
    if (_token == null) return;

    final result = await const FeaturePermissionService()
        .fetchFeaturePermissions();
    if (result.isSuccess && result.data != null) {
      _featurePermissions = result.data;
      _featurePermissionsLoaded = true;
      if (notify) notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _user = null;
    _featurePermissions = null;
    _featurePermissionsLoaded = false;
    _isAccessBlocked = false;
    _accessBlockedMessage = null;
    _accessBlockedSupport = null;
    _loginErrorMessage = null;
    // Clear all cached data so stale data cannot leak to another user session
    AppCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_role');
    notifyListeners();
  }

  // Helper to get headers for other services
  Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  void clearAccessBlocked() {
    _isAccessBlocked = false;
    _accessBlockedMessage = null;
    _accessBlockedSupport = null;
    _loginErrorMessage = null;
    notifyListeners();
  }

  Future<void> _handleAuthFailure(http.Response response) async {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }

    if (response.statusCode == 403 && data['code'] == 'TRIAL_ENDED') {
      _token = null;
      _role = null;
      _user = null;
      _featurePermissions = null;
      _featurePermissionsLoaded = false;
      _isAccessBlocked = true;
      _accessBlockedMessage =
          data['error']?.toString() ??
          'Trial period is ended. Contact support team to purchase a plan.';
      final support = data['support'];
      _accessBlockedSupport = support is Map
          ? Map<String, dynamic>.from(support)
          : null;
      await _clearStoredCredentials();
      AppCache.clear();
    } else {
      _loginErrorMessage =
          data['error']?.toString() ?? 'Invalid email or password';
    }

    notifyListeners();
  }

  Future<void> _clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_role');
  }

  void _applyFeaturePermissions(Map<String, dynamic> data) {
    final direct = data['featurePermissions'];
    final unitData = data['unit'];
    final nested = unitData is Map ? unitData['featurePermissions'] : null;
    final payload = direct is Map
        ? direct
        : nested is Map
        ? nested
        : null;

    if (payload == null) return;
    _featurePermissions = FeaturePermissionSnapshot.fromJson(
      Map<String, dynamic>.from(payload),
    );
    _featurePermissionsLoaded = true;
  }

  bool _legacyFeatureAccess(String featureId) {
    return switch (featureId) {
      AppFeature.patients ||
      AppFeature.homeVisits ||
      AppFeature.volunteers ||
      AppFeature.socialSupport ||
      AppFeature.equipment ||
      AppFeature.equipmentDistribution => true,
      AppFeature.patientPdf => _legacyPlanAllowsPatientPdf(),
      AppFeature.nhcAssessment ||
      AppFeature.nhcPdf ||
      AppFeature.medicineMaster ||
      AppFeature.medicineStock ||
      AppFeature.medicineSupply => !isMember,
      _ => false,
    };
  }

  bool _legacyPlanAllowsPatientPdf() {
    final planId = _cleanString(
      _user?['planId'] ?? unit?['planId'],
    )?.toLowerCase();
    return planId != null && planId != 'starter';
  }

  Object? _supportValue(String key) {
    final support = unit?['helpSupport'];
    if (support is Map<String, dynamic>) return support[key];
    if (support is Map) return support[key];
    return null;
  }

  static String _firstText(List<Object?> values, {required String fallback}) {
    for (final value in values) {
      final cleaned = _cleanString(value);
      if (cleaned != null) return cleaned;
    }
    return fallback;
  }

  static String? _cleanString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) return {};
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }
}
