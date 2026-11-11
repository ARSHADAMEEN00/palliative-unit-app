import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/screens/billing/billing_models.dart';

void main() {
  test('BillingTransaction identifies client payment correctly and parses from JSON', () {
    final clientPaymentJson = {
      'id': '6ae3023dc612c881c4edc267',
      'type': 'plan',
      'is_payment': true,
      'record_type': 'payment',
      'title': 'Subscription fee',
      'status': 'paid',
      'paid_at': '2026-10-21T00:00:00.000Z',
      'amount': 5000.0,
    };

    final tx = BillingTransaction.fromJson(clientPaymentJson);
    expect(tx.isClientPayment, isTrue);
    expect(tx.status, TransactionStatus.paid);
    expect(tx.status.shouldShowPill, isFalse);
    expect(tx.amount, 5000.0);
  });

  test('BillingTransaction identifies plan invoice correctly as non-client payment', () {
    final invoiceJson = {
      'id': 'inv-2026',
      'type': 'plan',
      'title': '2026',
      'status': 'pending',
      'amount': 11999.0,
    };

    final tx = BillingTransaction.fromJson(invoiceJson);
    expect(tx.isClientPayment, isFalse);
    expect(tx.status, TransactionStatus.pending);
    expect(tx.status.shouldShowPill, isTrue);
  });

  test('BillingTransaction identifies discount/offer correctly and never shows pending badge', () {
    final offerJson = {
      'id': 'tx-offer-1',
      'type': 'offer',
      'title': 'Discounted',
      'status': 'paid',
      'amount': 5000.0,
      'offer_amount': 5000.0,
    };

    final tx = BillingTransaction.fromJson(offerJson);
    expect(tx.isOffer, isTrue);
    expect(tx.isClientPayment, isFalse);
    expect(tx.status, TransactionStatus.paid);
  });
}

