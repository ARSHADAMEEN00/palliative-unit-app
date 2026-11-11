import 'package:flutter/material.dart';

enum TransactionType {
  all,
  plan,
  server,
  offer,
  balance;

  String get label {
    switch (this) {
      case TransactionType.all:
        return 'All';
      case TransactionType.plan:
        return 'Plan';
      case TransactionType.server:
        return 'Server';
      case TransactionType.offer:
        return 'Offer';
      case TransactionType.balance:
        return 'Balance';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionType.all:
        return Icons.layers_outlined;
      case TransactionType.plan:
        return Icons.verified_outlined;
      case TransactionType.server:
        return Icons.dns_outlined;
      case TransactionType.offer:
        return Icons.local_offer_outlined;
      case TransactionType.balance:
        return Icons.check_circle_outlined;
    }
  }

  Color bgTint(bool isDark) {
    if (isDark) {
      switch (this) {
        case TransactionType.plan:
          return const Color(0xFF1E293B);
        case TransactionType.server:
          return const Color(0xFF1E293B);
        case TransactionType.offer:
          return const Color(0xFF064E3B);
        case TransactionType.balance:
          return const Color(0xFF064E3B);
        case TransactionType.all:
          return const Color(0xFF1F2937);
      }
    }
    switch (this) {
      case TransactionType.plan:
        return const Color(0xFFEFF6FF); // light blue
      case TransactionType.server:
        return const Color(0xFFF1F5F9); // slate
      case TransactionType.offer:
        return const Color(0xFFECFDF5); // emerald green
      case TransactionType.balance:
        return const Color(0xFFDCFCE7); // light green
      case TransactionType.all:
        return const Color(0xFFF3F4F6);
    }
  }

  Color iconColor(bool isDark) {
    if (isDark) {
      switch (this) {
        case TransactionType.plan:
          return const Color(0xFF60A5FA);
        case TransactionType.server:
          return const Color(0xFF94A3B8);
        case TransactionType.offer:
          return const Color(0xFF34D399);
        case TransactionType.balance:
          return const Color(0xFF4ADE80);
        case TransactionType.all:
          return const Color(0xFF9CA3AF);
      }
    }
    switch (this) {
      case TransactionType.plan:
        return const Color(0xFF2563EB);
      case TransactionType.server:
        return const Color(0xFF475569);
      case TransactionType.offer:
        return const Color(0xFF059669);
      case TransactionType.balance:
        return const Color(0xFF16A34A);
      case TransactionType.all:
        return const Color(0xFF6B7280);
    }
  }

  static TransactionType fromString(String? raw) {
    if (raw == null) return TransactionType.plan;
    final val = raw.trim().toLowerCase();
    if (val.contains('server') || val.contains('maintenance')) return TransactionType.server;
    if (val.contains('offer') || val.contains('discount')) return TransactionType.offer;
    if (val.contains('balance')) return TransactionType.balance;
    if (val.contains('plan') || val.contains('subscription')) return TransactionType.plan;
    return TransactionType.plan;
  }
}

enum TransactionStatus {
  all,
  paid,
  pending,
  underReview,
  failed;

  String get label {
    switch (this) {
      case TransactionStatus.all:
        return 'All';
      case TransactionStatus.paid:
        return 'Paid';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.underReview:
        return 'Under review';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  bool get shouldShowPill => this == pending || this == underReview || this == failed;

  Color pillBg(bool isDark) {
    if (isDark) {
      switch (this) {
        case TransactionStatus.pending:
          return const Color(0xFF451A03);
        case TransactionStatus.underReview:
          return const Color(0xFF172554);
        case TransactionStatus.failed:
          return const Color(0xFF450A0A);
        case TransactionStatus.paid:
          return const Color(0xFF064E3B);
        case TransactionStatus.all:
          return Colors.transparent;
      }
    }
    switch (this) {
      case TransactionStatus.pending:
        return const Color(0xFFFEF3C7); // amber
      case TransactionStatus.underReview:
        return const Color(0xFFDBEAFE); // blue
      case TransactionStatus.failed:
        return const Color(0xFFFEE2E2); // red
      case TransactionStatus.paid:
        return const Color(0xFFDCFCE7); // green
      case TransactionStatus.all:
        return Colors.transparent;
    }
  }

  Color pillText(bool isDark) {
    if (isDark) {
      switch (this) {
        case TransactionStatus.pending:
          return const Color(0xFFFBBF24);
        case TransactionStatus.underReview:
          return const Color(0xFF93C5FD);
        case TransactionStatus.failed:
          return const Color(0xFFF87171);
        case TransactionStatus.paid:
          return const Color(0xFF4ADE80);
        case TransactionStatus.all:
          return Colors.white;
      }
    }
    switch (this) {
      case TransactionStatus.pending:
        return const Color(0xFFB45309);
      case TransactionStatus.underReview:
        return const Color(0xFF1D4ED8);
      case TransactionStatus.failed:
        return const Color(0xFFB91C1C);
      case TransactionStatus.paid:
        return const Color(0xFF15803D);
      case TransactionStatus.all:
        return Colors.black;
    }
  }

  static TransactionStatus fromString(String? raw) {
    if (raw == null) return TransactionStatus.paid;
    final val = raw.trim().toLowerCase();
    if (val.contains('under_review') || val.contains('under review') || val.contains('verification')) {
      return TransactionStatus.underReview;
    }
    if (val.contains('failed') || val.contains('rejected')) {
      return TransactionStatus.failed;
    }
    if (val.contains('pending') || val.contains('due') || val.contains('unpaid')) {
      return TransactionStatus.pending;
    }
    return TransactionStatus.paid;
  }
}

enum DateFilter {
  all,
  thisMonth,
  last3Months,
  thisYear,
  custom;

  String get label {
    switch (this) {
      case DateFilter.all:
        return 'Date: All';
      case DateFilter.thisMonth:
        return 'This month';
      case DateFilter.last3Months:
        return 'Last 3 months';
      case DateFilter.thisYear:
        return 'This year';
      case DateFilter.custom:
        return 'Custom';
    }
  }
}

class TimelineStep {
  const TimelineStep({
    required this.step,
    required this.label,
    this.date,
    this.completed = false,
    this.isCurrent = false,
  });

  final String step;
  final String label;
  final DateTime? date;
  final bool completed;
  final bool isCurrent;

  factory TimelineStep.fromJson(Map<String, dynamic> json) {
    return TimelineStep(
      step: json['step']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      completed: json['completed'] == true,
      isCurrent: json['current'] == true,
    );
  }
}

class BillingTransaction {
  const BillingTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.amount,
    this.paidAt,
    this.dueDate,
    this.invoiceNo,
    this.offerAmount = 0,
    this.note,
    this.method,
    this.planAmount,
    this.netPayable,
    this.paidAmount,
    this.balance,
    this.timeline,
    this.isPayment = false,
    this.recordType,
  });

  final String id;
  final TransactionType type;
  final String title;
  final TransactionStatus status;
  final double amount;
  final DateTime? paidAt;
  final DateTime? dueDate;
  final String? invoiceNo;
  final double offerAmount;
  final String? note;
  final String? method;
  final double? planAmount;
  final double? netPayable;
  final double? paidAmount;
  final double? balance;
  final List<TimelineStep>? timeline;
  final bool isPayment;
  final String? recordType;

  bool get isOffer =>
      type == TransactionType.offer ||
      amount < 0 ||
      recordType?.toLowerCase() == 'offer' ||
      title.toLowerCase().contains('discount') ||
      title.toLowerCase().contains('offer');

  bool get isClientPayment =>
      isPayment ||
      recordType?.toLowerCase() == 'payment' ||
      type == TransactionType.balance ||
      (status == TransactionStatus.paid &&
          (title.toLowerCase().contains('payment') ||
              title.toLowerCase().contains('fee') ||
              title.toLowerCase().contains('clearance')) &&
          type != TransactionType.server);

  factory BillingTransaction.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString();
    final statusStr = json['status']?.toString();
    final rawAmount = (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0;
    final rawOfferAmount = (json['offer_amount'] is num)
        ? (json['offer_amount'] as num).toDouble()
        : (json['offerAmount'] is num ? (json['offerAmount'] as num).toDouble() : 0.0);
    final rawIsPayment = json['is_payment'] == true ||
        json['isPayment'] == true ||
        json['record_type']?.toString().toLowerCase() == 'payment' ||
        json['recordType']?.toString().toLowerCase() == 'payment';
    final rawRecordType = json['record_type']?.toString() ?? json['recordType']?.toString();

    List<TimelineStep>? steps;
    if (json['timeline'] is List) {
      steps = (json['timeline'] as List)
          .map((item) => TimelineStep.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return BillingTransaction(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      type: TransactionType.fromString(typeStr),
      title: json['title']?.toString() ?? 'Transaction',
      status: TransactionStatus.fromString(statusStr),
      amount: rawAmount,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : (json['paidAt'] != null ? DateTime.tryParse(json['paidAt'].toString()) : null),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      invoiceNo: json['invoice_no']?.toString() ?? json['invoiceNumber']?.toString(),
      offerAmount: rawOfferAmount,
      note: json['note']?.toString() ?? json['notes']?.toString(),
      method: json['method']?.toString(),
      planAmount: (json['plan_amount'] as num?)?.toDouble() ?? (json['baseAmount'] as num?)?.toDouble(),
      netPayable: (json['net_payable'] as num?)?.toDouble() ?? (json['netPayable'] as num?)?.toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? (json['paidAmount'] as num?)?.toDouble(),
      balance: (json['balance'] as num?)?.toDouble() ?? (json['remainingAmount'] as num?)?.toDouble(),
      timeline: steps,
      isPayment: rawIsPayment,
      recordType: rawRecordType,
    );
  }
}

class BillingMonthGroup {
  const BillingMonthGroup({
    required this.monthKey,
    required this.monthLabel,
    required this.monthTotal,
    required this.transactions,
  });

  final String monthKey;
  final String monthLabel;
  final double monthTotal;
  final List<BillingTransaction> transactions;

  factory BillingMonthGroup.fromJson(Map<String, dynamic> json) {
    final list = (json['transactions'] as List? ?? [])
        .map((item) => BillingTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
    return BillingMonthGroup(
      monthKey: json['month_key']?.toString() ?? '',
      monthLabel: json['month_label']?.toString() ?? '',
      monthTotal: (json['month_total'] as num?)?.toDouble() ?? 0.0,
      transactions: list,
    );
  }
}

class BillingStatsSummary {
  const BillingStatsSummary({
    required this.planName,
    required this.billingCycle,
    required this.status,
    required this.totalPaid,
    required this.outstanding,
    required this.upcoming,
    this.nextPaymentAmount = 0,
    this.nextPaymentDate,
  });

  final String planName;
  final String billingCycle;
  final String status;
  final double totalPaid;
  final double outstanding;
  final double upcoming;
  final double nextPaymentAmount;
  final DateTime? nextPaymentDate;

  bool get hasDues => outstanding > 0;

  factory BillingStatsSummary.fromJson(Map<String, dynamic> json) {
    DateTime? nextDate;
    double nextAmt = 0;
    if (json['next_payment'] is Map) {
      final np = json['next_payment'] as Map;
      nextAmt = (np['amount'] as num?)?.toDouble() ?? 0.0;
      if (np['date'] != null) {
        nextDate = DateTime.tryParse(np['date'].toString());
      }
    }

    return BillingStatsSummary(
      planName: json['plan_name']?.toString() ?? 'Clinical Pro',
      billingCycle: json['billing_cycle']?.toString() ?? 'Yearly',
      status: json['status']?.toString() ?? 'active',
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0.0,
      upcoming: (json['upcoming'] as num?)?.toDouble() ?? 0.0,
      nextPaymentAmount: nextAmt,
      nextPaymentDate: nextDate,
    );
  }
}

class TransactionFilter {
  const TransactionFilter({
    this.type = TransactionType.all,
    this.status = TransactionStatus.all,
    this.dateFilter = DateFilter.all,
    this.searchQuery = '',
    this.customFrom,
    this.customTo,
  });

  final TransactionType type;
  final TransactionStatus status;
  final DateFilter dateFilter;
  final String searchQuery;
  final DateTime? customFrom;
  final DateTime? customTo;

  bool get isFiltered =>
      type != TransactionType.all ||
      status != TransactionStatus.all ||
      dateFilter != DateFilter.all ||
      searchQuery.trim().isNotEmpty ||
      customFrom != null ||
      customTo != null;

  TransactionFilter copyWith({
    TransactionType? type,
    TransactionStatus? status,
    DateFilter? dateFilter,
    String? searchQuery,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustomDates = false,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      status: status ?? this.status,
      dateFilter: dateFilter ?? this.dateFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      customFrom: clearCustomDates ? null : (customFrom ?? this.customFrom),
      customTo: clearCustomDates ? null : (customTo ?? this.customTo),
    );
  }
}

