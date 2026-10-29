import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/billing.dart';

void main() {
  test('billing portal parses manual payment settings and pending proof', () {
    final portal = BillingPortal.fromJson({
      'unit': {
        'id': 'unit-1',
        'name': 'Care Unit',
        'code': 'CU-1',
        'status': 'active',
        'planId': 'standard',
        'billingCycle': 'monthly',
        'subscriptionStatus': 'active',
      },
      'summary': {
        'planName': 'Standard',
        'billingCycle': 'monthly',
        'subscriptionStatus': 'active',
        'outstandingAmount': 1200,
        'verificationPendingAmount': 1200,
        'hasVerificationPending': true,
      },
      'plans': [],
      'maintenanceHistory': [],
      'paymentRows': [
        {
          'id': 'invoice-1',
          'invoiceNumber': 'PAL-CU-1-2026-10',
          'periodKey': '2026-10',
          'label': 'October 2026',
          'recordType': 'invoice',
          'invoiceType': 'subscription',
          'status': 'verification_pending',
          'amount': 1200,
          'paidAmount': 0,
          'remainingAmount': 1200,
          'verificationStatus': 'pending',
        },
      ],
      'paymentSettings': {
        'status': 'active',
        'accountHolderName': 'Palliative App',
        'bankName': 'Test Bank',
        'accountNumber': '123456',
        'ifscCode': 'TEST0001',
        'upiId': 'pay@example',
        'enabledMethods': ['bank_transfer', 'upi_id'],
        'version': 3,
      },
      'paymentSubmissions': [
        {
          'id': 'submission-1',
          'submissionNumber': 'PS-1',
          'status': 'submitted',
          'invoiceIds': ['invoice-1'],
          'expectedAmount': 1200,
          'declaredPaidAmount': 1200,
          'transactionReference': 'UTR123',
        },
      ],
    });

    expect(portal.paymentSettings.isActive, isTrue);
    expect(portal.paymentSettings.hasBankTransfer, isTrue);
    expect(portal.paymentSettings.hasUpiId, isTrue);
    expect(portal.summary.hasVerificationPending, isTrue);
    expect(portal.summary.verificationPendingAmount, 1200);
    expect(portal.paymentRows.single.isVerificationPending, isTrue);
    expect(portal.paymentRows.single.canSubmitProof, isFalse);
    expect(portal.paymentSubmissions.single.isPending, isTrue);
  });

  test('open invoice can be selected for proof upload', () {
    final row = PaymentHistoryRow.fromJson({
      'id': 'invoice-2',
      'periodKey': '2026-11',
      'label': 'November 2026',
      'recordType': 'invoice',
      'status': 'open',
      'amount': 900,
      'paidAmount': 0,
      'remainingAmount': 900,
    });

    expect(row.canSubmitProof, isTrue);
    expect(row.displayAmount, 900);
  });
}
