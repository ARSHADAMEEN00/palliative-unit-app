import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class AppFeature {
  AppFeature._();

  static const patients = 'patients';
  static const homeVisits = 'home_visits';
  static const volunteers = 'volunteers';
  static const socialSupport = 'social_support';
  static const equipment = 'equipment';
  static const equipmentDistribution = 'equipment_distribution';
  static const patientPdf = 'patient_pdf';
  static const nhcAssessment = 'nhc_assessment';
  static const nhcPdf = 'nhc_pdf';
  static const medicineMaster = 'medicine_master';
  static const medicineStock = 'medicine_stock';
  static const medicineSupply = 'medicine_supply';
  static const advancedReports = 'advanced_reports';
  static const analytics = 'analytics';
  static const backupExport = 'backup_export';
  static const whatsappSms = 'whatsapp_sms';
  static const multiCentre = 'multi_centre';
  static const customForms = 'custom_forms';

  static String label(String featureId) {
    return switch (featureId) {
      patients => 'Patient Management',
      homeVisits => 'Home Visits',
      volunteers => 'Volunteers',
      socialSupport => 'Social Support',
      equipment => 'Equipment Inventory',
      equipmentDistribution => 'Equipment Distribution',
      patientPdf => 'Patient PDF Reports',
      nhcAssessment => 'NHC Visit Assessment',
      nhcPdf => 'NHC PDF Report',
      medicineMaster => 'Medicine Master',
      medicineStock => 'Medicine Stock Entry',
      medicineSupply => 'Medicine Supply',
      advancedReports => 'Advanced Reports',
      analytics => 'Analytics Dashboard',
      backupExport => 'Backup & Export',
      whatsappSms => 'WhatsApp/SMS Reminders',
      multiCentre => 'Multi-Centre Mode',
      customForms => 'Custom Forms',
      _ => featureId,
    };
  }
}

class FeaturePermissionSnapshot {
  const FeaturePermissionSnapshot({
    required this.enabledFeatureIds,
    this.planId,
    this.planName,
    this.billingCycle,
    this.subscriptionStatus,
    this.unitStatus,
  });

  final Set<String> enabledFeatureIds;
  final String? planId;
  final String? planName;
  final String? billingCycle;
  final String? subscriptionStatus;
  final String? unitStatus;

  bool get hasServerPayload => true;

  bool has(String featureId) => enabledFeatureIds.contains(featureId);

  factory FeaturePermissionSnapshot.fromJson(Map<String, dynamic> json) {
    return FeaturePermissionSnapshot(
      enabledFeatureIds: _stringSet(json['enabledFeatureIds']),
      planId: _nullableString(json['planId']),
      planName: _nullableString(json['planName']),
      billingCycle: _nullableString(json['billingCycle']),
      subscriptionStatus: _nullableString(json['subscriptionStatus']),
      unitStatus: _nullableString(json['unitStatus']),
    );
  }
}

class FeaturePermissionService {
  const FeaturePermissionService();

  Future<ApiResult<FeaturePermissionSnapshot>> fetchFeaturePermissions() {
    return ApiService.get<FeaturePermissionSnapshot>(
      ApiConfig.billingFeaturesEndpoint,
      fromJson: (json) =>
          FeaturePermissionSnapshot.fromJson(json as Map<String, dynamic>),
    );
  }
}

Set<String> _stringSet(dynamic value) {
  if (value is! List) return {};
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
