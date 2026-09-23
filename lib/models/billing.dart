class BillingPortal {
  const BillingPortal({
    required this.unit,
    required this.summary,
    required this.plans,
    required this.maintenanceHistory,
    required this.paymentRows,
    this.subscription,
    this.currentPlan,
  });

  final BillingUnit unit;
  final BillingSummary summary;
  final BillingSubscription? subscription;
  final BillingPlan? currentPlan;
  final List<BillingPlan> plans;
  final List<MaintenanceHistoryEntry> maintenanceHistory;
  final List<PaymentHistoryRow> paymentRows;

  List<MaintenanceHistoryEntry> get pendingMaintenanceEntries {
    final entries = maintenanceHistory.where((entry) => entry.isDue).toList();
    entries.sort((a, b) {
      final aTime = a.dueDate?.millisecondsSinceEpoch ?? 0;
      final bTime = b.dueDate?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    return entries;
  }

  factory BillingPortal.fromJson(Map<String, dynamic> json) {
    return BillingPortal(
      unit: BillingUnit.fromJson(_asMap(json['unit'])),
      subscription: json['subscription'] is Map<String, dynamic>
          ? BillingSubscription.fromJson(_asMap(json['subscription']))
          : null,
      currentPlan: json['currentPlan'] is Map<String, dynamic>
          ? BillingPlan.fromJson(_asMap(json['currentPlan']))
          : null,
      plans: _asList(
        json['plans'],
      ).map((item) => BillingPlan.fromJson(item)).toList(),
      maintenanceHistory: _asList(
        json['maintenanceHistory'],
      ).map((item) => MaintenanceHistoryEntry.fromJson(item)).toList(),
      paymentRows: _asList(
        json['paymentRows'],
      ).map((item) => PaymentHistoryRow.fromJson(item)).toList(),
      summary: BillingSummary.fromJson(_asMap(json['summary'])),
    );
  }
}

class BillingUnit {
  const BillingUnit({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.planId,
    required this.billingCycle,
    required this.subscriptionStatus,
    this.district,
    this.village,
    this.contactEmail,
    this.contactPhones,
    this.subscriptionStartDate,
    this.trialEndDate,
    this.renewalDate,
    this.maintenanceFee = 0,
  });

  final String id;
  final String name;
  final String code;
  final String status;
  final String planId;
  final String billingCycle;
  final String subscriptionStatus;
  final String? district;
  final String? village;
  final String? contactEmail;
  final List<String>? contactPhones;
  final DateTime? subscriptionStartDate;
  final DateTime? trialEndDate;
  final DateTime? renewalDate;
  final double maintenanceFee;

  factory BillingUnit.fromJson(Map<String, dynamic> json) {
    return BillingUnit(
      id: _string(json['id']),
      name: _string(json['name']),
      code: _string(json['code']),
      status: _string(json['status']),
      planId: _string(json['planId']),
      billingCycle: _string(json['billingCycle'], fallback: 'monthly'),
      subscriptionStatus: _string(
        json['subscriptionStatus'],
        fallback: 'trial',
      ),
      district: _nullableString(json['district']),
      village: _nullableString(json['village']),
      contactEmail: _nullableString(json['contactEmail']),
      contactPhones: (json['contactPhones'] as List?)?.map((e) => e.toString()).toList(),
      subscriptionStartDate: _date(json['subscriptionStartDate']),
      trialEndDate: _date(json['trialEndDate']),
      renewalDate: _date(json['renewalDate']),
      maintenanceFee: _number(json['maintenanceFee']),
    );
  }
}

class BillingSubscription {
  const BillingSubscription({
    required this.id,
    required this.status,
    required this.planId,
    required this.billingCycle,
    required this.addOns,
    this.startDate,
    this.trialEndDate,
    this.renewalDate,
    this.maintenanceFee = 0,
  });

  final String id;
  final String status;
  final String planId;
  final String billingCycle;
  final DateTime? startDate;
  final DateTime? trialEndDate;
  final DateTime? renewalDate;
  final double maintenanceFee;
  final List<BillingAddOn> addOns;

  factory BillingSubscription.fromJson(Map<String, dynamic> json) {
    return BillingSubscription(
      id: _string(json['id']),
      status: _string(json['status'], fallback: 'trial'),
      planId: _string(json['planId']),
      billingCycle: _string(json['billingCycle'], fallback: 'monthly'),
      startDate: _date(json['startDate']),
      trialEndDate: _date(json['trialEndDate']),
      renewalDate: _date(json['renewalDate']),
      maintenanceFee: _number(json['maintenanceFee']),
      addOns: _asList(
        json['addOns'],
      ).map((item) => BillingAddOn.fromJson(item)).toList(),
    );
  }
}

class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.name,
    required this.featureIds,
    this.price = 0,
    this.oneTimePrice = 0,
    this.bestFor,
    this.included,
    this.notes,
  });

  final String id;
  final String name;
  final double price;
  final double oneTimePrice;
  final String? bestFor;
  final String? included;
  final String? notes;
  final List<String> featureIds;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      id: _string(json['id'], fallback: _string(json['slug'])),
      name: _string(json['name']),
      price: _number(json['price']),
      oneTimePrice: _number(json['oneTimePrice']),
      bestFor: _nullableString(json['bestFor']),
      included: _nullableString(json['included']),
      notes: _nullableString(json['notes']),
      featureIds: _stringList(json['featureIds']),
    );
  }
}

class BillingAddOn {
  const BillingAddOn({
    required this.id,
    required this.name,
    required this.billingType,
    this.monthlyPrice = 0,
    this.oneTimePrice = 0,
  });

  final String id;
  final String name;
  final String billingType;
  final double monthlyPrice;
  final double oneTimePrice;

  factory BillingAddOn.fromJson(Map<String, dynamic> json) {
    return BillingAddOn(
      id: _string(json['addOnId'], fallback: _string(json['id'])),
      name: _string(json['name']),
      billingType: _string(json['billingType'], fallback: 'monthly'),
      monthlyPrice: _number(json['monthlyPrice']),
      oneTimePrice: _number(json['oneTimePrice']),
    );
  }
}

class BillingSummary {
  const BillingSummary({
    required this.planName,
    required this.billingCycle,
    required this.subscriptionStatus,
    this.outstandingAmount = 0,
    this.upcomingPaymentAmount = 0,
    this.totalPaid = 0,
    this.totalInvoiced = 0,
    this.upcomingPaymentLabel,
    this.upcomingPaymentDueDate,
  });

  final String planName;
  final String billingCycle;
  final String subscriptionStatus;
  final double outstandingAmount;
  final double upcomingPaymentAmount;
  final double totalPaid;
  final double totalInvoiced;
  final String? upcomingPaymentLabel;
  final DateTime? upcomingPaymentDueDate;

  factory BillingSummary.fromJson(Map<String, dynamic> json) {
    return BillingSummary(
      planName: _string(json['planName'], fallback: 'Current plan'),
      billingCycle: _string(json['billingCycle'], fallback: 'monthly'),
      subscriptionStatus: _string(
        json['subscriptionStatus'],
        fallback: 'trial',
      ),
      outstandingAmount: _number(json['outstandingAmount']),
      upcomingPaymentAmount: _number(json['upcomingPaymentAmount']),
      totalPaid: _number(json['totalPaid']),
      totalInvoiced: _number(json['totalInvoiced']),
      upcomingPaymentLabel: _nullableString(json['upcomingPaymentLabel']),
      upcomingPaymentDueDate: _date(json['upcomingPaymentDueDate']),
    );
  }
}

class MaintenanceHistoryEntry {
  const MaintenanceHistoryEntry({
    this.id,
    this.periodKey,
    required this.label,
    required this.status,
    this.dueDate,
    this.amount = 0,
    this.notes,
  });

  final String? id;
  final String? periodKey;
  final String label;
  final DateTime? dueDate;
  final double amount;
  final String status;
  final String? notes;

  bool get isDue => status.toLowerCase() == 'due';

  factory MaintenanceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MaintenanceHistoryEntry(
      id: _nullableString(json['id'] ?? json['_id']),
      periodKey: _nullableString(json['periodKey']),
      label: _string(json['label']),
      dueDate: _date(json['dueDate']),
      amount: _number(json['amount']),
      status: _string(json['status'], fallback: 'due'),
      notes: _nullableString(json['notes']),
    );
  }
}

class PaymentHistoryRow {
  const PaymentHistoryRow({
    required this.periodKey,
    required this.label,
    required this.recordType,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.amount = 0,
    this.paidAmount = 0,
    this.remainingAmount,
    this.method,
  });

  final String periodKey;
  final String label;
  final String recordType;
  final DateTime? dueDate;
  final double amount;
  final double paidAmount;
  final double? remainingAmount;
  final String status;
  final DateTime? paidAt;
  final String? method;

  bool get isPayment => recordType.toLowerCase() == 'payment';

  bool get isPaid => status.toLowerCase() == 'paid';

  double get displayAmount {
    if (isPayment || isPaid) return amount;
    return remainingAmount ?? amount;
  }

  factory PaymentHistoryRow.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryRow(
      periodKey: _string(json['periodKey']),
      label: _string(json['label']),
      recordType: _string(json['recordType'], fallback: 'invoice'),
      dueDate: _date(json['dueDate']),
      amount: _number(json['amount']),
      paidAmount: _number(json['paidAmount']),
      remainingAmount: json.containsKey('remainingAmount')
          ? _number(json['remainingAmount'])
          : null,
      status: _string(json['status'], fallback: 'pending'),
      paidAt: _date(json['paidAt']),
      method: _nullableString(json['method']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return {};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is! List) return [];
  return value.map(_asMap).toList();
}

List<String> _stringList(dynamic value) {
  if (value is! List) return [];
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
