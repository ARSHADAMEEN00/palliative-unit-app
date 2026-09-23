import 'package:oruma_app/models/billing.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class BillingService {
  const BillingService();

  Future<ApiResult<BillingPortal>> fetchBillingPortal() {
    return ApiService.get<BillingPortal>(
      ApiConfig.billingPortalEndpoint,
      fromJson: (json) => BillingPortal.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createPlanEnquiry({
    required String selectedPlanId,
    required String contactNumber,
  }) {
    return ApiService.post<Map<String, dynamic>>(
      ApiConfig.billingEnquiriesEndpoint,
      body: {'selectedPlanId': selectedPlanId, 'contactNumber': contactNumber},
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }
}
