/// API Configuration for the Palliative App.
///
/// Contains the base URL and common headers for API requests.
class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();

  /// Base URL for the API server.
  static const String baseUrl = 'https://api-erp-palliative.osperb.com/api';

  /// Health check endpoint
  static const String healthUrl =
      'https://api-erp-palliative.osperb.com/health';

  /// API Endpoints
  static String get patientsEndpoint => '$baseUrl/patients';
  static String get v2PatientsEndpoint => '$baseUrl/v2/patients';
  static String get v2MedicinesEndpoint => '$baseUrl/v2/medicines';
  static String get homeVisitsEndpoint => '$baseUrl/home-visits';
  static String get v2VisitAssessmentsEndpoint =>
      '$baseUrl/v2/visit-assessments';
  static String get equipmentEndpoint => '$baseUrl/equipment';
  static String get equipmentSuppliesEndpoint => '$baseUrl/equipment-supplies';
  static String get notificationsEndpoint => '$baseUrl/notifications';
  static String get billingPortalEndpoint => '$baseUrl/billing/me';
  static String get billingFeaturesEndpoint => '$baseUrl/billing/features';
  static String get billingEnquiriesEndpoint => '$baseUrl/billing/enquiries';
  static String get medicineSuppliesEndpoint => '$baseUrl/medicine-supplies';
  static String get v2MedicineSuppliesEndpoint =>
      '$baseUrl/v2/medicine-supplies';
  static String get v2MedicineStockEntriesEndpoint =>
      '$baseUrl/v2/medicine-stock-entries';
  static String get v2SocialSupportEndpoint => '$baseUrl/v2/social-support';
  static String get v2VolunteersEndpoint => '$baseUrl/v2/volunteers';
  static String get meEndpoint => '$baseUrl/auth/me';
  static String get staffEndpoint => '$baseUrl/auth/staff';

  /// Default headers for API requests
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Request timeout duration
  static const Duration timeout = Duration(seconds: 30);
}
