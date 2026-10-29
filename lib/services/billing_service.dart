import 'dart:typed_data';
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

  Future<ApiResult<BillingPortal>> getBillingPortal() => fetchBillingPortal();

  Future<Uint8List?> downloadInvoicePdf(String invoiceId) {
    return ApiService.getBytes('${ApiConfig.baseUrl}/billing/invoices/$invoiceId/download');
  }

  Future<Uint8List?> downloadReceiptPdf(String invoiceId) {
    return ApiService.getBytes('${ApiConfig.baseUrl}/billing/invoices/$invoiceId/receipt');
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

  Future<ApiResult<PaymentSubmission>> submitPaymentProof({
    required List<String> invoiceIds,
    required double declaredPaidAmount,
    required String transactionReference,
    required DateTime paidAt,
    required String paymentMethod,
    required String proofData,
    required String proofFileName,
    String? replacesSubmissionId,
  }) {
    return ApiService.post<PaymentSubmission>(
      ApiConfig.billingPaymentSubmissionsEndpoint,
      body: {
        'invoiceIds': invoiceIds,
        'declaredPaidAmount': declaredPaidAmount,
        'transactionReference': transactionReference.trim(),
        'paidAt': paidAt.toIso8601String(),
        'paymentMethod': paymentMethod,
        'proofData': proofData,
        'proofFileName': proofFileName,
        if (replacesSubmissionId != null)
          'replacesSubmissionId': replacesSubmissionId,
      },
      fromJson: (json) =>
          PaymentSubmission.fromJson(json as Map<String, dynamic>),
    );
  }
}
