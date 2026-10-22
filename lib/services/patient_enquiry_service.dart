import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/patient_enquiry.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicUnitLocationConfig {
  final List<String> villages;
  final List<WardConfig> wards;

  const PublicUnitLocationConfig({
    required this.villages,
    required this.wards,
  });

  factory PublicUnitLocationConfig.fromJson(Map<String, dynamic> json) {
    final rawVillages = json['villages'] as List<dynamic>? ?? const [];
    final rawWards = json['wards'] as List<dynamic>? ?? const [];

    return PublicUnitLocationConfig(
      villages: rawVillages.map((e) => e.toString()).toList()..sort(),
      wards: rawWards
          .whereType<Map>()
          .map((e) => WardConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class PatientEnquiryService {
  PatientEnquiryService._();

  /// Load public care units for the enquiry form selector.
  static Future<List<PublicUnit>> getPublicUnits() async {
    return VolunteerApplicationService.getUnits();
  }

  /// Load villages and wards for a specific unit (publicly accessible).
  static Future<PublicUnitLocationConfig> getPublicUnitConfig(
    String unitId,
  ) async {
    final result = await ApiService.get<Map<String, dynamic>>(
      ApiConfig.publicUnitConfigEndpoint(unitId),
    );
    if (result.isSuccess && result.data != null) {
      return PublicUnitLocationConfig.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to load unit locations');
  }

  /// Submit enquiry via public endpoint.
  static Future<void> submitPublic({
    required String unitId,
    required String name,
    required String phone,
    required String village,
    int? age,
    String address = '',
    String? phone2,
    String? ward,
    String? caregiverName,
    String? caregiverPhone,
    String? referredByName,
    String? referredByPhone,
    String? submittedByVolunteerId,
    String? submittedByVolunteerName,
  }) async {
    final refName = (referredByName ?? caregiverName)?.trim();
    final refPhone = (referredByPhone ?? caregiverPhone)?.trim();
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.publicPatientEnquiriesEndpoint,
      body: {
        'unitId': unitId,
        'name': name.trim(),
        if (age != null) 'age': age,
        'address': address.trim(),
        'phone': phone.trim(),
        if (phone2 != null && phone2.trim().isNotEmpty) 'phone2': phone2.trim(),
        'village': village.trim(),
        if (ward != null && ward.trim().isNotEmpty) 'ward': ward.trim(),
        if (refName != null && refName.isNotEmpty) ...{
          'caregiverName': refName,
          'referredByName': refName,
        },
        if (refPhone != null && refPhone.isNotEmpty) ...{
          'caregiverPhone': refPhone,
          'referredByPhone': refPhone,
        },
        if (submittedByVolunteerId != null)
          'submittedByVolunteerId': submittedByVolunteerId,
        if (submittedByVolunteerName != null)
          'submittedByVolunteerName': submittedByVolunteerName.trim(),
      },
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Failed to submit patient enquiry');
    }
  }

  /// Submit enquiry via authenticated endpoint (logged in volunteer/staff/admin).
  static Future<void> submitAuthenticated({
    required String name,
    required String phone,
    required String village,
    int? age,
    String address = '',
    String? phone2,
    String? ward,
    String? caregiverName,
    String? caregiverPhone,
    String? referredByName,
    String? referredByPhone,
  }) async {
    final refName = (referredByName ?? caregiverName)?.trim();
    final refPhone = (referredByPhone ?? caregiverPhone)?.trim();
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.patientEnquiriesEndpoint,
      body: {
        'name': name.trim(),
        if (age != null) 'age': age,
        'address': address.trim(),
        'phone': phone.trim(),
        if (phone2 != null && phone2.trim().isNotEmpty) 'phone2': phone2.trim(),
        'village': village.trim(),
        if (ward != null && ward.trim().isNotEmpty) 'ward': ward.trim(),
        if (refName != null && refName.isNotEmpty) ...{
          'caregiverName': refName,
          'referredByName': refName,
        },
        if (refPhone != null && refPhone.isNotEmpty) ...{
          'caregiverPhone': refPhone,
          'referredByPhone': refPhone,
        },
      },
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Failed to submit patient enquiry');
    }
  }

  /// Get list of patient enquiries for the current unit.
  static Future<List<PatientEnquiry>> getEnquiries({
    String? status,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse(
      ApiConfig.patientEnquiriesEndpoint,
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final result = await ApiService.get<Map<String, dynamic>>(uri.toString());
    if (result.isSuccess && result.data != null) {
      final list = result.data!['enquiries'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map>()
          .map((e) => PatientEnquiry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(result.error ?? 'Failed to load patient enquiries');
  }

  /// Get count of pending enquiries for badges.
  static Future<int> getPendingCount() async {
    try {
      final result = await ApiService.get<Map<String, dynamic>>(
        ApiConfig.patientEnquiriesCountEndpoint,
      );
      if (result.isSuccess && result.data != null) {
        return (result.data!['pendingCount'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Update enquiry status ('verified' | 'rejected' | 'pending').
  static Future<void> updateStatus(
    String id,
    String status, {
    String? notes,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      ApiConfig.patientEnquiryStatusEndpoint(id),
      body: {'status': status, if (notes != null) 'notes': notes},
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Failed to update enquiry status');
    }
  }

  /// Delete enquiry.
  static Future<void> deleteEnquiry(String id) async {
    final result = await ApiService.delete(
      ApiConfig.patientEnquiryDetailEndpoint(id),
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Failed to delete enquiry');
    }
  }

  /// Formats all data with labels and shares to WhatsApp for verification.
  /// Also copies formatted text to clipboard as a reliable backup.
  static Future<void> shareToWhatsApp(
    PatientEnquiry enquiry,
    BuildContext context, {
    String? unitName,
  }) async {
    final message = enquiry.toWhatsAppMessage(unitName: unitName);

    // Copy to clipboard for easy fallback
    await Clipboard.setData(ClipboardData(text: message));

    final encoded = Uri.encodeComponent(message);

    // Try whatsapp:// scheme first, then web wa.me
    final appUri = Uri.parse('whatsapp://send?text=$encoded');
    final webUri = Uri.parse('https://wa.me/?text=$encoded');

    bool launched = false;
    try {
      if (await canLaunchUrl(appUri)) {
        launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (!launched) {
      try {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  launched
                      ? 'Opening WhatsApp with formatted patient data...'
                      : 'Formatted patient data copied to clipboard!',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
