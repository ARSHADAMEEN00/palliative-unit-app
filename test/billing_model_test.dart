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

  test('billing portal parses multiple payments and calculates non-maintenance summary correctly', () {
    final portal = BillingPortal.fromJson({
      'unit': {
        'id': 'unit-oruma',
        'name': 'Oruma palliative',
        'code': 'PAL-UN001',
        'status': 'active',
        'planId': 'clinical',
        'billingCycle': 'one_time',
        'subscriptionStatus': 'active',
      },
      'summary': {
        'planName': 'Clinical Pro',
        'planId': 'clinical',
        'billingCycle': 'one_time',
        'subscriptionStatus': 'active',
        'unitStatus': 'active',
        'outstandingAmount': 0,
        'verificationPendingAmount': 0,
        'hasVerificationPending': false,
        'upcomingPaymentAmount': 0,
        'upcomingPaymentLabel': 'No upcoming bill',
        'totalPaid': 9999,
        'totalInvoiced': 9999,
      },
      'plans': [],
      'maintenanceHistory': [],
      'paymentRows': [
        {
          'id': 'pay-1',
          'periodKey': 'custom_1793262141598_ovouu9',
          'label': 'Balance Payment',
          'recordType': 'payment',
          'invoiceType': 'subscription',
          'dueDate': '2026-10-21T00:00:00.000Z',
          'amount': 5000,
          'paidAmount': 5000,
          'status': 'paid',
          'paidAt': '2026-10-21T00:00:00.000Z',
          'method': 'manual',
        },
        {
          'id': 'pay-2',
          'periodKey': 'custom_1793262204088_os8g3l',
          'label': 'Opening Sale Offer',
          'recordType': 'payment',
          'invoiceType': 'subscription',
          'dueDate': '2026-10-29T00:00:00.000Z',
          'amount': 4999,
          'paidAmount': 4999,
          'status': 'paid',
          'paidAt': '2026-10-29T00:00:00.000Z',
          'method': 'manual',
        },
        {
          'id': 'inv-1',
          'invoiceNumber': 'PAL-UN001-S-6F62B9-ONE-TIME-2026-01-01',
          'periodKey': 'one-time-2026-01-01',
          'label': 'One-time license',
          'recordType': 'invoice',
          'invoiceType': 'subscription',
          'dueDate': '2026-01-01T00:00:00.000Z',
          'amount': 9999,
          'paidAmount': 9999,
          'remainingAmount': 0,
          'status': 'paid',
          'paidAt': '2026-10-29T08:37:48.389Z',
          'method': 'manual',
        },
      ],
    });

    final payments = portal.paymentRows.where((r) => r.isPayment).toList();
    expect(payments.length, 2);
    expect(payments[0].label, 'Balance Payment');
    expect(payments[0].amount, 5000);
    expect(payments[1].label, 'Opening Sale Offer');
    expect(payments[1].amount, 4999);
    expect(portal.summary.totalInvoiced, 9999);
    expect(portal.summary.totalPaid, 9999);
    expect(portal.summary.outstandingAmount, 0);
  });
}
