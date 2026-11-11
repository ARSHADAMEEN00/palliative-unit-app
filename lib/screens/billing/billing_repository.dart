import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/models/billing.dart';
import 'package:oruma_app/screens/billing/billing_models.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';
import 'package:oruma_app/services/billing_service.dart';

class BillingFetchResult {
  const BillingFetchResult({
    required this.summary,
    required this.groups,
    this.totalCount = 0,
    this.hasMore = false,
  });

  final BillingStatsSummary summary;
  final List<BillingMonthGroup> groups;
  final int totalCount;
  final bool hasMore;
}

class BillingRepository {
  BillingRepository({this.useMock = false});

  /// Toggle this flag to switch between mock data and real backend API.
  bool useMock;

  static final NumberFormat inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final DateFormat dateFormat = DateFormat('d MMM yyyy');

  String formatCurrency(num amount, {bool isNegative = false}) {
    final absVal = amount.abs();
    final formatted = inrFormat.format(absVal);
    if (isNegative || amount < 0) {
      return '−$formatted';
    }
    return formatted;
  }

  String formatDate(DateTime? date) {
    if (date == null) return '—';
    return dateFormat.format(date);
  }

  /// Fetches transactions either from backend or from memory mock data.
  Future<BillingFetchResult> getTransactions(TransactionFilter filter) async {
    if (!useMock) {
      try {
        final queryParams = <String, String>{};
        if (filter.type != TransactionType.all) {
          queryParams['type'] = filter.type.name;
        }
        if (filter.status != TransactionStatus.all) {
          queryParams['status'] = filter.status == TransactionStatus.underReview ? 'under_review' : filter.status.name;
        }
        if (filter.searchQuery.trim().isNotEmpty) {
          queryParams['q'] = filter.searchQuery.trim();
        }

        final now = DateTime.now();
        if (filter.dateFilter == DateFilter.thisMonth) {
          queryParams['from'] = DateTime(now.year, now.month, 1).toIso8601String();
        } else if (filter.dateFilter == DateFilter.last3Months) {
          queryParams['from'] = DateTime(now.year, now.month - 3, 1).toIso8601String();
        } else if (filter.dateFilter == DateFilter.thisYear) {
          queryParams['from'] = DateTime(now.year, 1, 1).toIso8601String();
        } else if (filter.dateFilter == DateFilter.custom) {
          if (filter.customFrom != null) queryParams['from'] = filter.customFrom!.toIso8601String();
          if (filter.customTo != null) queryParams['to'] = filter.customTo!.toIso8601String();
        }

        final uri = Uri.parse('${ApiConfig.baseUrl}/billing/transactions').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
        final response = await ApiService.get<Map<String, dynamic>>(
          uri.toString(),
          fromJson: (json) => json as Map<String, dynamic>,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!;
          final summaryJson = data['summary'] as Map<String, dynamic>? ?? {};
          final groupsList = (data['groups'] as List? ?? [])
              .map((g) => BillingMonthGroup.fromJson(g as Map<String, dynamic>))
              .toList();

          return BillingFetchResult(
            summary: BillingStatsSummary.fromJson(summaryJson),
            groups: groupsList,
            totalCount: (data['pagination']?['total'] as num?)?.toInt() ?? 0,
            hasMore: data['pagination']?['has_more'] == true,
          );
        }

        // Fallback to active live portal endpoint if /transactions is not available yet
        final portalResult = await const BillingService().fetchBillingPortal();
        if (portalResult.isSuccess && portalResult.data != null) {
          return _buildResultFromPortal(portalResult.data!, filter);
        }
      } catch (e) {
        debugPrint('BillingRepository API error, checking portal endpoint: $e');
        try {
          final portalResult = await const BillingService().fetchBillingPortal();
          if (portalResult.isSuccess && portalResult.data != null) {
            return _buildResultFromPortal(portalResult.data!, filter);
          }
        } catch (_) {}
      }
    }

    // Simulate network delay for natural feel
    await Future.delayed(const Duration(milliseconds: 300));
    return _buildMockResult(filter);
  }

  BillingFetchResult _buildResultFromPortal(BillingPortal portal, TransactionFilter filter) {
    final transactions = <BillingTransaction>[];

    for (final row in portal.paymentRows) {
      final label = row.label;
      final lower = label.toLowerCase();
      TransactionType type = TransactionType.plan;
      if (lower.contains('server') || lower.contains('maintenance')) {
        type = TransactionType.server;
      } else if (lower.contains('offer') || lower.contains('discount') || row.offerAmount > 0) {
        type = TransactionType.offer;
      } else if (lower.contains('balance')) {
        type = TransactionType.balance;
      }

      TransactionStatus status = TransactionStatus.paid;
      if (row.isVerificationPending) {
        status = TransactionStatus.underReview;
      } else if (row.status.toLowerCase() == 'failed') {
        status = TransactionStatus.failed;
      } else if (row.status.toLowerCase() == 'paid' || row.isPaid) {
        status = TransactionStatus.paid;
      } else if (row.status.toLowerCase() == 'pending' || !row.isPaid) {
        status = TransactionStatus.pending;
      }

      final isPayment = row.isPayment || row.recordType.toLowerCase() == 'payment';

      transactions.add(
        BillingTransaction(
          id: row.id ?? row.periodKey,
          type: type,
          title: label,
          status: status,
          amount: type == TransactionType.offer && row.offerAmount > 0 ? row.offerAmount : row.amount,
          offerAmount: row.offerAmount,
          paidAt: row.paidAt ?? row.dueDate,
          dueDate: row.dueDate,
          invoiceNo: row.invoiceNumber,
          note: row.offerNote,
          method: row.method,
          planAmount: row.baseAmount > 0 ? row.baseAmount : row.amount,
          netPayable: row.netPayable,
          paidAmount: row.paidAmount,
          balance: row.displayAmount,
          isPayment: isPayment,
          recordType: row.recordType,
        ),
      );
    }

    for (final maint in portal.maintenanceHistory) {
      transactions.add(
        BillingTransaction(
          id: maint.id ?? maint.periodKey ?? maint.label,
          type: TransactionType.server,
          title: maint.label,
          status: maint.isDue ? TransactionStatus.pending : TransactionStatus.paid,
          amount: maint.amount,
          dueDate: maint.dueDate,
          paidAt: maint.dueDate,
          invoiceNo: maint.periodKey,
          method: 'Auto debit',
          note: maint.notes,
        ),
      );
    }

    final summary = BillingStatsSummary(
      planName: portal.summary.planName,
      billingCycle: portal.summary.billingCycle,
      status: portal.summary.subscriptionStatus,
      totalPaid: portal.summary.totalPaid,
      outstanding: portal.summary.outstandingAmount,
      upcoming: portal.summary.upcomingPaymentAmount,
      nextPaymentAmount: portal.summary.outstandingAmount > 0
          ? portal.summary.outstandingAmount
          : portal.summary.upcomingPaymentAmount,
      nextPaymentDate: portal.summary.upcomingPaymentDueDate ?? portal.unit.renewalDate,
    );

    return _filterAndGroupTransactions(transactions, filter, summary);
  }

  BillingFetchResult _buildMockResult(TransactionFilter filter) {
    final allSampleTransactions = _generateSampleTransactions();

    final summary = BillingStatsSummary(
      planName: 'Clinical Pro',
      billingCycle: 'Yearly',
      status: 'Active',
      totalPaid: 5000.0,
      outstanding: 6999.0,
      upcoming: 0.0,
      nextPaymentAmount: 6999.0,
      nextPaymentDate: DateTime(2026, 1, 1),
    );

    return _filterAndGroupTransactions(allSampleTransactions, filter, summary);
  }

  BillingFetchResult _filterAndGroupTransactions(
    List<BillingTransaction> allTransactions,
    TransactionFilter filter,
    BillingStatsSummary summary,
  ) {
    // 1. Filter by Type
    var filtered = allTransactions.where((t) {
      if (filter.type != TransactionType.all) {
        if (filter.type == TransactionType.plan) {
          if (t.type != TransactionType.plan) return false;
        } else if (filter.type == TransactionType.balance) {
          if (t.type != TransactionType.balance && !t.isClientPayment) return false;
        } else if (t.type != filter.type) {
          return false;
        }
      }

      // 2. Filter by Status
      if (filter.status != TransactionStatus.all && t.status != filter.status) {
        return false;
      }

      // 3. Filter by Search Query
      if (filter.searchQuery.trim().isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        final matchTitle = t.title.toLowerCase().contains(query);
        final matchInvoice = (t.invoiceNo ?? '').toLowerCase().contains(query);
        final matchNote = (t.note ?? '').toLowerCase().contains(query);
        if (!matchTitle && !matchInvoice && !matchNote) return false;
      }

      // 4. Filter by Date
      final txDate = t.paidAt ?? t.dueDate ?? DateTime(2026, 11, 1);
      final now = DateTime(2026, 11, 11); // Reference local app date
      switch (filter.dateFilter) {
        case DateFilter.thisMonth:
          if (txDate.year != now.year || txDate.month != now.month) return false;
          break;
        case DateFilter.last3Months:
          final cutoff = DateTime(now.year, now.month - 2, 1);
          if (txDate.isBefore(cutoff)) return false;
          break;
        case DateFilter.thisYear:
          if (txDate.year != now.year) return false;
          break;
        case DateFilter.custom:
          if (filter.customFrom != null && txDate.isBefore(filter.customFrom!)) return false;
          if (filter.customTo != null && txDate.isAfter(filter.customTo!.add(const Duration(days: 1)))) return false;
          break;
        case DateFilter.all:
          break;
      }

      return true;
    }).toList();

    // Sort descending by date
    filtered.sort((a, b) {
      final aTime = (a.paidAt ?? a.dueDate ?? DateTime(2026)).millisecondsSinceEpoch;
      final bTime = (b.paidAt ?? b.dueDate ?? DateTime(2026)).millisecondsSinceEpoch;
      return bTime.compareTo(aTime);
    });

    // Group by month
    final Map<String, List<BillingTransaction>> groupedMap = {};
    for (final tx in filtered) {
      final d = tx.paidAt ?? tx.dueDate ?? DateTime(2026, 11, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      groupedMap.putIfAbsent(key, () => []).add(tx);
    }

    final monthFormat = DateFormat('MMMM yyyy');
    final groups = <BillingMonthGroup>[];
    groupedMap.forEach((key, txList) {
      final firstDate = txList.first.paidAt ?? txList.first.dueDate ?? DateTime(2026, 11, 1);
      final monthLabel = monthFormat.format(firstDate);
      final total = txList
          .where((t) => t.type != TransactionType.offer && t.status == TransactionStatus.paid)
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      groups.add(
        BillingMonthGroup(
          monthKey: key,
          monthLabel: monthLabel,
          monthTotal: total,
          transactions: txList,
        ),
      );
    });

    return BillingFetchResult(
      summary: summary,
      groups: groups,
      totalCount: filtered.length,
      hasMore: false,
    );
  }

  List<BillingTransaction> _generateSampleTransactions() {
    return [
      BillingTransaction(
        id: 'tx-nov-01',
        type: TransactionType.server,
        title: 'Server maintenance',
        status: TransactionStatus.paid,
        amount: 835.0,
        paidAt: DateTime(2026, 11, 5, 10, 0),
        invoiceNo: 'SRV-2026-11',
        method: 'Auto debit / UPI',
        note: 'November cloud server and database maintenance fee',
        planAmount: 835.0,
        offerAmount: 0.0,
        netPayable: 835.0,
        paidAmount: 835.0,
        balance: 0.0,
      ),
      BillingTransaction(
        id: 'tx-oct-01',
        type: TransactionType.server,
        title: 'Server maintenance',
        status: TransactionStatus.paid,
        amount: 843.0,
        paidAt: DateTime(2026, 10, 30, 10, 0),
        invoiceNo: 'SRV-2026-10',
        method: 'UPI',
        note: 'October cloud server maintenance fee',
        planAmount: 843.0,
        offerAmount: 0.0,
        netPayable: 843.0,
        paidAmount: 843.0,
        balance: 0.0,
      ),
      BillingTransaction(
        id: 'tx-oct-03',
        type: TransactionType.balance,
        title: 'Balance payment',
        status: TransactionStatus.paid,
        amount: 5000.0,
        paidAt: DateTime(2026, 10, 21, 15, 20),
        invoiceNo: 'BAL-2026-10',
        method: 'Bank Transfer',
        note: 'First installment balance clearance',
        planAmount: 5000.0,
        offerAmount: 0.0,
        netPayable: 5000.0,
        paidAmount: 5000.0,
        balance: 0.0,
        isPayment: true,
        recordType: 'payment',
      ),
      BillingTransaction(
        id: 'tx-sep-01',
        type: TransactionType.server,
        title: 'Server maintenance',
        status: TransactionStatus.paid,
        amount: 837.0,
        paidAt: DateTime(2026, 9, 1, 10, 0),
        invoiceNo: 'SRV-2026-09',
        method: 'UPI',
        note: 'September server upkeep',
        planAmount: 837.0,
        offerAmount: 0.0,
        netPayable: 837.0,
        paidAmount: 837.0,
        balance: 0.0,
      ),
      BillingTransaction(
        id: 'tx-aug-01',
        type: TransactionType.server,
        title: 'Server maintenance',
        status: TransactionStatus.paid,
        amount: 839.0,
        paidAt: DateTime(2026, 8, 1, 10, 0),
        invoiceNo: 'SRV-2026-08',
        method: 'UPI',
        note: 'August server upkeep',
        planAmount: 839.0,
        offerAmount: 0.0,
        netPayable: 839.0,
        paidAmount: 839.0,
        balance: 0.0,
      ),
      BillingTransaction(
        id: 'tx-jul-01',
        type: TransactionType.server,
        title: 'Server maintenance',
        status: TransactionStatus.paid,
        amount: 833.0,
        paidAt: DateTime(2026, 7, 1, 10, 0),
        invoiceNo: 'SRV-2026-07',
        method: 'UPI',
        note: 'July server upkeep',
        planAmount: 833.0,
        offerAmount: 0.0,
        netPayable: 833.0,
        paidAmount: 833.0,
        balance: 0.0,
      ),
      BillingTransaction(
        id: 'tx-jun-01',
        type: TransactionType.server,
        title: 'Server maintenance',
        status: TransactionStatus.paid,
        amount: 836.0,
        paidAt: DateTime(2026, 6, 1, 10, 0),
        invoiceNo: 'SRV-2026-06',
        method: 'UPI',
        note: 'June server upkeep',
        planAmount: 836.0,
        offerAmount: 0.0,
        netPayable: 836.0,
        paidAmount: 836.0,
        balance: 0.0,
      ),
    ];
  }
}

