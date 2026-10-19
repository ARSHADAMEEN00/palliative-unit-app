import 'package:oruma_app/models/volunteer_home_visit_request.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class VolunteerHomeVisitRequestService {
  VolunteerHomeVisitRequestService._();

  static Future<List<VolunteerHomeVisitRequest>> getRequests({
    String? status,
  }) async {
    final suffix = status == null ? '' : '?status=$status';
    final result = await ApiService.get<List<dynamic>>(
      '${ApiConfig.volunteerHomeVisitRequestsEndpoint}$suffix',
    );
    if (result.isSuccess && result.data != null) {
      return result.data!
          .whereType<Map>()
          .map(
            (item) => VolunteerHomeVisitRequest.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }
    throw Exception(result.error ?? 'Failed to load volunteer requests');
  }

  static Future<VolunteerHomeVisitRequest> submit(String homeVisitId) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.volunteerHomeVisitRequestsEndpoint,
      body: {'homeVisitId': homeVisitId},
    );
    if (result.isSuccess && result.data != null) {
      return VolunteerHomeVisitRequest.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to submit availability');
  }

  static Future<VolunteerHomeVisitRequest> review(
    String requestId,
    String status,
  ) async {
    final result = await ApiService.patch<Map<String, dynamic>>(
      '${ApiConfig.volunteerHomeVisitRequestsEndpoint}/$requestId/review',
      body: {'status': status},
    );
    if (result.isSuccess && result.data != null) {
      return VolunteerHomeVisitRequest.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to review volunteer request');
  }
}
