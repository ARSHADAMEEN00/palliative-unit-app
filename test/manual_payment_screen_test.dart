import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/manual_payment_screen.dart';
import 'package:oruma_app/models/billing.dart';

void main() {
  testWidgets('shows due invoice and configured UPI instructions', (
    tester,
  ) async {
    final portal = BillingPortal(
      unit: const BillingUnit(
        id: 'unit-1',
        name: 'Care Unit',
        code: 'CU-1',
        status: 'active',
        planId: 'standard',
        billingCycle: 'monthly',
        subscriptionStatus: 'active',
      ),
      summary: const BillingSummary(
        planName: 'Standard',
        billingCycle: 'monthly',
        subscriptionStatus: 'active',
        outstandingAmount: 1200,
      ),
      plans: const [],
      maintenanceHistory: const [],
      paymentRows: const [
        PaymentHistoryRow(
          id: 'invoice-1',
          invoiceNumber: 'PAL-CU-1-2026-10',
          periodKey: '2026-10',
          label: 'October 2026',
          recordType: 'invoice',
          status: 'open',
          amount: 1200,
          remainingAmount: 1200,
        ),
      ],
      paymentSettings: const PaymentSettings(
        status: 'active',
        upiId: 'pay@example',
        enabledMethods: ['upi_id'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ManualPaymentScreen(portal: portal)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment instructions'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('pay@example'), findsOneWidget);
    expect(find.text('Submit for verification'), findsOneWidget);
  });

  testWidgets('shows verification pending instead of upload form', (
    tester,
  ) async {
    final portal = BillingPortal(
      unit: const BillingUnit(
        id: 'unit-1',
        name: 'Care Unit',
        code: 'CU-1',
        status: 'active',
        planId: 'standard',
        billingCycle: 'monthly',
        subscriptionStatus: 'active',
      ),
      summary: const BillingSummary(
        planName: 'Standard',
        billingCycle: 'monthly',
        subscriptionStatus: 'active',
        outstandingAmount: 1200,
        verificationPendingAmount: 1200,
        hasVerificationPending: true,
      ),
      plans: const [],
      maintenanceHistory: const [],
      paymentRows: const [],
      paymentSubmissions: const [
        PaymentSubmission(
          id: 'submission-1',
          submissionNumber: 'PS-1',
          status: 'submitted',
          expectedAmount: 1200,
          transactionReference: 'UTR123',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ManualPaymentScreen(portal: portal)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment proof submitted'), findsOneWidget);
    expect(find.text('Submit for verification'), findsNothing);
    expect(find.text('UTR123'), findsOneWidget);
  });
}
