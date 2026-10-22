import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class VolunteerAvailabilityRequestService {
  VolunteerAvailabilityRequestService._();

  static Future<List<VolunteerAvailabilityRequest>> getRequests({
    String? status,
  }) async {
    final suffix = status == null ? '' : '?status=$status';
    final result = await ApiService.get<List<dynamic>>(
      '${ApiConfig.volunteerAvailabilityRequestsEndpoint}$suffix',
    );
    if (result.isSuccess && result.data != null) {
      return result.data!
          .whereType<Map>()
          .map(
            (item) => VolunteerAvailabilityRequest.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }
    throw Exception(result.error ?? 'Failed to load availability requests');
  }

  static Future<VolunteerAvailabilityRequest> submit({
    required String requestedDate,
    required String contactName,
    required String phone,
    String? address,
    String? timeSlot,
  }) async {
    final cleanAddress = address?.trim() ?? '';
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.volunteerAvailabilityRequestsEndpoint,
      body: {
        'requestedDate': requestedDate,
        'contactName': contactName,
        'phone': phone,
        if (cleanAddress.isNotEmpty) 'address': cleanAddress,
        if (timeSlot != null && timeSlot.trim().isNotEmpty)
          'timeSlot': timeSlot.trim(),
      },
    );
    if (result.isSuccess && result.data != null) {
      return VolunteerAvailabilityRequest.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to submit availability');
  }

  static Future<VolunteerAvailabilityRequest> review(
    String requestId,
    String status, {
    required String decisionNote,
  }) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.volunteerAvailabilityRequestsEndpoint}/$requestId/review',
      body: {'status': status, 'decisionNote': decisionNote},
    );
    if (result.isSuccess && result.data != null) {
      return VolunteerAvailabilityRequest.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to review availability request');
  }

  static Future<VolunteerAvailabilityRequest> cancel(
    String requestId, {
    String? reason,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      '${ApiConfig.volunteerAvailabilityRequestsEndpoint}/$requestId/cancel',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (result.isSuccess && result.data != null) {
      return VolunteerAvailabilityRequest.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to cancel availability request');
  }
}
