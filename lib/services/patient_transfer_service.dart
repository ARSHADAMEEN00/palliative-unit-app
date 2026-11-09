import '../models/patient_transfer.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

class PatientTransferService {
  PatientTransferService._();

  static Future<List<TransferUnitSummary>> destinations() async {
    final result = await ApiService.get<List<TransferUnitSummary>>(
      '${ApiConfig.patientTransfersEndpoint}/destinations',
      fromJson: (json) => (json as List<dynamic>)
          .map(
            (item) => TransferUnitSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
    return _data(result, 'Could not load destination units');
  }

  static Future<int> incomingCount() async {
    final result = await ApiService.get<Map<String, dynamic>>(
      '${ApiConfig.patientTransfersEndpoint}/incoming/count',
    );
    final data = _data(result, 'Could not load incoming transfer count');
    return int.tryParse(data['pendingCount']?.toString() ?? '') ?? 0;
  }

  static Future<PatientTransferPage> requests({
    required bool incoming,
    String? status,
    int page = 1,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '30'};
    if (status != null && status != 'all') query['status'] = status;
    final uri = Uri.parse(
      '${ApiConfig.patientTransfersEndpoint}/${incoming ? 'incoming' : 'outgoing'}',
    ).replace(queryParameters: query);
    final result = await ApiService.get<PatientTransferPage>(
      uri.toString(),
      fromJson: (json) =>
          PatientTransferPage.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return _data(result, 'Could not load transfer requests');
  }

  static Future<PatientTransferDetails> details(String id) async {
    final result = await ApiService.get<PatientTransferDetails>(
      '${ApiConfig.patientTransfersEndpoint}/$id',
      fromJson: (json) => PatientTransferDetails.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    return _data(result, 'Could not load transfer request');
  }

  static Future<PatientTransferRequest> create({
    required String patientId,
    required String destinationUnitId,
    required String reason,
    required DateTime transferDate,
    required String handoverSummary,
    String? newAddress,
    String? currentCareStatus,
    String? remarks,
    bool draft = false,
  }) async {
    final result = await ApiService.post<PatientTransferRequest>(
      ApiConfig.patientTransfersEndpoint,
      body: {
        'patientId': patientId,
        'destinationUnitId': destinationUnitId,
        'reason': reason.trim(),
        'transferDate': transferDate.toUtc().toIso8601String(),
        'handoverSummary': handoverSummary.trim(),
        'newAddress': newAddress?.trim(),
        'currentCareStatus': currentCareStatus?.trim(),
        'remarks': remarks?.trim(),
        'draft': draft,
      },
      fromJson: (json) => PatientTransferRequest.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    final request = _data(result, 'Could not submit transfer request');
    _invalidatePatientCaches();
    return request;
  }

  static Future<PatientTransferRequest> accept({
    required PatientTransferRequest request,
    required Set<String> checkedKeys,
    required String verifierName,
    String? duplicateResolutionReason,
  }) async {
    final result = await ApiService.post<PatientTransferRequest>(
      '${ApiConfig.patientTransfersEndpoint}/${request.id}/accept',
      body: {
        'verificationChecklist': request.verificationChecklist
            .map((item) => item.toJson(checked: checkedKeys.contains(item.key)))
            .toList(),
        'verifierName': verifierName.trim(),
        if (request.hasPossibleDuplicate)
          'duplicateResolution': 'NOT_SAME_PERSON',
        if (duplicateResolutionReason?.trim().isNotEmpty == true)
          'duplicateResolutionReason': duplicateResolutionReason!.trim(),
      },
      timeout: const Duration(minutes: 2),
      fromJson: (json) => PatientTransferRequest.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    final accepted = _data(result, 'Could not accept transfer request');
    _invalidatePatientCaches();
    return accepted;
  }

  static Future<PatientTransferRequest> reject(String id, String reason) async {
    final result = await ApiService.post<PatientTransferRequest>(
      '${ApiConfig.patientTransfersEndpoint}/$id/reject',
      body: {'reason': reason.trim()},
      fromJson: (json) => PatientTransferRequest.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    final rejected = _data(result, 'Could not reject transfer request');
    _invalidatePatientCaches();
    return rejected;
  }

  static Future<PatientTransferRequest> cancel(String id) async {
    final result = await ApiService.post<PatientTransferRequest>(
      '${ApiConfig.patientTransfersEndpoint}/$id/cancel',
      body: const {},
      fromJson: (json) => PatientTransferRequest.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    final cancelled = _data(result, 'Could not cancel transfer request');
    _invalidatePatientCaches();
    return cancelled;
  }

  static Future<List<PatientTransferRequest>> patientHistory(
    String patientId,
  ) async {
    final result = await ApiService.get<List<PatientTransferRequest>>(
      '${ApiConfig.patientTransfersEndpoint}/patient/$patientId/history',
      fromJson: (json) => (json as List<dynamic>)
          .map(
            (item) => PatientTransferRequest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
    return _data(result, 'Could not load transfer history');
  }

  static Future<TransferredPatientPage> transferredPatients({
    String? search,
    String? destinationUnitId,
    DateTime? from,
    DateTime? to,
    int page = 1,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '30'};
    if (search?.trim().isNotEmpty == true) query['search'] = search!.trim();
    if (destinationUnitId?.isNotEmpty == true) {
      query['destinationUnitId'] = destinationUnitId!;
    }
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) {
      query['to'] = DateTime(
        to.year,
        to.month,
        to.day,
        23,
        59,
        59,
        999,
      ).toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      ApiConfig.transferredPatientsEndpoint,
    ).replace(queryParameters: query);
    final result = await ApiService.get<TransferredPatientPage>(
      uri.toString(),
      fromJson: (json) => TransferredPatientPage.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    return _data(result, 'Could not load transferred patients');
  }

  static Future<TransferredPatientDetails> transferredPatient(
    String snapshotId,
  ) async {
    final result = await ApiService.get<TransferredPatientDetails>(
      '${ApiConfig.transferredPatientsEndpoint}/$snapshotId',
      fromJson: (json) => TransferredPatientDetails.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    return _data(result, 'Could not load transferred patient');
  }

  static T _data<T>(ApiResult<T> result, String fallback) {
    if (result.isSuccess && result.data != null) return result.data as T;
    throw Exception(result.error ?? fallback);
  }

  static void _invalidatePatientCaches() {
    AppCache.invalidatePrefix('patients:');
  }
}
