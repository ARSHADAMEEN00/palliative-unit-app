import 'package:oruma_app/models/volunteer_assignment.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class VolunteerAssignmentService {
  VolunteerAssignmentService._();

  static Future<List<VolunteerAssignment>> getAssignments({
    String filter = 'all',
  }) async {
    final endpoint = '${ApiConfig.volunteerAssignmentsEndpoint}?filter=$filter';
    final result = await ApiService.get<List<dynamic>>(endpoint);

    if (result.isSuccess && result.data != null) {
      return result.data!
          .whereType<Map>()
          .map(
            (item) =>
                VolunteerAssignment.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    throw Exception(result.error ?? 'Failed to load assignments');
  }

  static Future<VolunteerAssignment?> getAssignment(String id) async {
    final endpoint = '${ApiConfig.volunteerAssignmentsEndpoint}/$id';
    final result = await ApiService.get<Map<String, dynamic>>(endpoint);

    if (result.isSuccess && result.data != null) {
      return VolunteerAssignment.fromJson(result.data!);
    }

    throw Exception(result.error ?? 'Failed to load assignment details');
  }

  static Future<Map<String, dynamic>> updateStatus(
    String id,
    String status, {
    String? notes,
  }) async {
    final endpoint = '${ApiConfig.volunteerAssignmentsEndpoint}/$id/status';
    final result = await ApiService.patch<Map<String, dynamic>>(
      endpoint,
      body: {
        'status': status,
        if (notes != null) 'notes': notes.trim(),
      },
    );

    if (result.isSuccess && result.data != null) {
      final assignmentMap = Map<String, dynamic>.from(
        result.data!['assignment'] ?? {},
      );
      final assignment = VolunteerAssignment.fromJson(assignmentMap);
      return {'assignment': assignment};
    }

    throw Exception(result.error ?? 'Failed to update assignment status');
  }

  static Future<VolunteerAssignment> cancelAssignment(
    String id, {
    String? reason,
  }) async {
    final endpoint = '${ApiConfig.volunteerAssignmentsEndpoint}/$id/cancel';
    final result = await ApiService.post<Map<String, dynamic>>(
      endpoint,
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    if (result.isSuccess && result.data != null) {
      final assignmentMap = Map<String, dynamic>.from(
        result.data!['assignment'] ?? result.data!,
      );
      return VolunteerAssignment.fromJson(assignmentMap);
    }

    throw Exception(result.error ?? 'Failed to cancel assignment');
  }

  static Future<List<VolunteerLeaderboardEntry>> getLeaderboard() async {
    final endpoint = ApiConfig.volunteerLeaderboardEndpoint;
    final result = await ApiService.get<List<dynamic>>(endpoint);

    if (result.isSuccess && result.data != null) {
      return result.data!
          .whereType<Map>()
          .map(
            (item) => VolunteerLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return const [];
  }

  static Future<List<String>> getAssignedVolunteerIds(
    String taskType,
    String taskId,
  ) async {
    try {
      final endpoint = ApiConfig.volunteerTaskAssignmentsEndpoint(
        taskType,
        taskId,
      );
      final result = await ApiService.get<List<dynamic>>(endpoint);

      if (result.isSuccess && result.data != null) {
        return result.data!
            .whereType<Map>()
            .map((item) => item['volunteerId']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
