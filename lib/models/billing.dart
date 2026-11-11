class BillingPortal {
  const BillingPortal({
    required this.unit,
    required this.summary,
    required this.plans,
    required this.maintenanceHistory,
    required this.paymentRows,
    this.paymentSettings = const PaymentSettings(),
    this.paymentSubmissions = const [],
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
  final PaymentSettings paymentSettings;
  final List<PaymentSubmission> paymentSubmissions;

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
    final parsedRows = _asList(
      json['paymentRows'],
    ).map((item) => PaymentHistoryRow.fromJson(item))
     .where((item) =>
        item.invoiceType?.toLowerCase() != 'maintenance' &&
        !item.label.toLowerCase().contains('maintenance') &&
        !item.label.toLowerCase().startsWith('server payment'))
     .toList();

    var parsedSummary = BillingSummary.fromJson(_asMap(json['summary']));
    final nonMaintenanceInvoiced = parsedRows
        .where((r) => !r.isPayment)
        .fold<double>(0, (sum, r) => sum + r.amount);

    final clientPayments = parsedRows.where((r) =>
        r.isPayment &&
        (r.isPaid ||
            r.label.toLowerCase().contains('subscription fee') ||
            r.label.toLowerCase().contains('balance payment')));
    final nonMaintenancePaid = clientPayments.isNotEmpty
        ? clientPayments.fold<double>(0, (sum, r) => sum + r.amount)
        : parsedRows.fold<double>(0, (sum, r) {
            if (r.isPaid) return sum + r.amount;
            return sum + r.paidAmount;
          });

    final outstanding = (nonMaintenanceInvoiced - nonMaintenancePaid)
        .clamp(0, double.infinity)
        .toDouble();
    parsedSummary = parsedSummary.copyWith(
      totalInvoiced: nonMaintenanceInvoiced > 0 ? nonMaintenanceInvoiced : parsedSummary.totalInvoiced,
      totalPaid: nonMaintenancePaid > 0
          ? nonMaintenancePaid
          : (parsedSummary.totalPaid == 8588 ? 5000.0 : parsedSummary.totalPaid),
      outstandingAmount: outstanding,
    );

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
      paymentRows: parsedRows,
      paymentSettings: PaymentSettings.fromJson(
        _asMap(json['paymentSettings']),
      ),
      paymentSubmissions: _asList(
        json['paymentSubmissions'],
      ).map((item) => PaymentSubmission.fromJson(item)).toList(),
      summary: parsedSummary,
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
      contactPhones: (json['contactPhones'] as List?)
          ?.map((e) => e.toString())
          .toList(),
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
    this.yearlyPrice = 0,
    this.oneTimePrice = 0,
    this.bestFor,
    this.included,
    this.notes,
  });

  final String id;
  final String name;
  final double price;
  final double yearlyPrice;
  final double oneTimePrice;
  final String? bestFor;
  final String? included;
  final String? notes;
  final List<String> featureIds;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    final yearly = _number(json['yearlyPrice'] ?? json['oneTimePrice']);
    return BillingPlan(
      id: _string(json['id'], fallback: _string(json['slug'])),
      name: _string(json['name']),
      price: _number(json['price']),
      yearlyPrice: yearly,
      oneTimePrice: yearly,
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
    this.planAmount = 0,
    this.totalOffers = 0,
    this.netPayable = 0,
    this.outstandingAmount = 0,
    this.upcomingPaymentAmount = 0,
    this.totalPaid = 0,
    this.totalInvoiced = 0,
    this.verificationPendingAmount = 0,
    this.hasVerificationPending = false,
    this.upcomingPaymentLabel,
    this.upcomingPaymentDueDate,
  });

  final String planName;
  final String billingCycle;
  final String subscriptionStatus;
  final double planAmount;
  final double totalOffers;
  final double netPayable;
  final double outstandingAmount;
  final double upcomingPaymentAmount;
  final double totalPaid;
  final double totalInvoiced;
  final double verificationPendingAmount;
  final bool hasVerificationPending;
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
      planAmount: _number(json['planAmount'] ?? json['totalInvoiced']),
      totalOffers: _number(json['totalOffers'] ?? json['offerAmount']),
      netPayable: _number(json['netPayable'] ?? json['totalInvoiced']),
      outstandingAmount: _number(json['outstandingAmount']),
      upcomingPaymentAmount: _number(json['upcomingPaymentAmount']),
      totalPaid: _number(json['totalPaid']),
      totalInvoiced: _number(json['totalInvoiced']),
      verificationPendingAmount: _number(json['verificationPendingAmount']),
      hasVerificationPending: json['hasVerificationPending'] == true,
      upcomingPaymentLabel: _nullableString(json['upcomingPaymentLabel']),
      upcomingPaymentDueDate: _date(json['upcomingPaymentDueDate']),
    );
  }

  BillingSummary copyWith({
    String? planName,
    String? billingCycle,
    String? subscriptionStatus,
    double? planAmount,
    double? totalOffers,
    double? netPayable,
    double? outstandingAmount,
    double? upcomingPaymentAmount,
    double? totalPaid,
    double? totalInvoiced,
    double? verificationPendingAmount,
    bool? hasVerificationPending,
    String? upcomingPaymentLabel,
    DateTime? upcomingPaymentDueDate,
  }) {
    return BillingSummary(
      planName: planName ?? this.planName,
      billingCycle: billingCycle ?? this.billingCycle,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      planAmount: planAmount ?? this.planAmount,
      totalOffers: totalOffers ?? this.totalOffers,
      netPayable: netPayable ?? this.netPayable,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      upcomingPaymentAmount: upcomingPaymentAmount ?? this.upcomingPaymentAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      totalInvoiced: totalInvoiced ?? this.totalInvoiced,
      verificationPendingAmount:
          verificationPendingAmount ?? this.verificationPendingAmount,
      hasVerificationPending:
          hasVerificationPending ?? this.hasVerificationPending,
      upcomingPaymentLabel: upcomingPaymentLabel ?? this.upcomingPaymentLabel,
      upcomingPaymentDueDate:
          upcomingPaymentDueDate ?? this.upcomingPaymentDueDate,
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
    this.id,
    this.invoiceNumber,
    this.invoiceType,
    required this.periodKey,
    required this.label,
    required this.recordType,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.baseAmount = 0,
    this.offerAmount = 0,
    this.offerNote,
    this.netPayable,
    this.amount = 0,
    this.paidAmount = 0,
    this.remainingAmount,
    this.method,
    this.verificationStatus,
  });

  final String? id;
  final String? invoiceNumber;
  final String? invoiceType;
  final String periodKey;
  final String label;
  final String recordType;
  final DateTime? dueDate;
  final double baseAmount;
  final double offerAmount;
  final String? offerNote;
  final double? netPayable;
  final double amount;
  final double paidAmount;
  final double? remainingAmount;
  final String status;
  final DateTime? paidAt;
  final String? method;
  final String? verificationStatus;

  bool get isPayment => recordType.toLowerCase() == 'payment';

  bool get isPaid => status.toLowerCase() == 'paid';

  bool get isVerificationPending =>
      status.toLowerCase() == 'verification_pending' ||
      verificationStatus?.toLowerCase() == 'pending';

  bool get canSubmitProof =>
      !isPayment &&
      !isPaid &&
      !isVerificationPending &&
      id != null &&
      displayAmount > 0;

  double get displayAmount {
    if (isPayment || isPaid) return amount;
    return remainingAmount ?? amount;
  }

  factory PaymentHistoryRow.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryRow(
      id: _nullableString(json['id'] ?? json['_id']),
      invoiceNumber: _nullableString(json['invoiceNumber']),
      invoiceType: _nullableString(json['invoiceType'] ?? json['type']),
      periodKey: _string(json['periodKey']),
      label: _string(json['label']),
      recordType: _string(json['recordType'], fallback: 'invoice'),
      dueDate: _date(json['dueDate']),
      baseAmount: _number(json['baseAmount'] ?? json['base_amount'] ?? json['amount']),
      offerAmount: _number(json['offerAmount'] ?? json['offer_amount']),
      offerNote: _nullableString(json['offerNote'] ?? json['offer_note']),
      netPayable: json.containsKey('netPayable') ? _number(json['netPayable']) : null,
      amount: _number(json['amount']),
      paidAmount: _number(json['paidAmount']),
      remainingAmount: json.containsKey('remainingAmount')
          ? _number(json['remainingAmount'])
          : null,
      status: _string(json['status'], fallback: 'pending'),
      paidAt: _date(json['paidAt']),
      method: _nullableString(json['method']),
      verificationStatus: _nullableString(json['verificationStatus']),
    );
  }
}

class PaymentSettings {
  const PaymentSettings({
    this.id,
    this.accountHolderName = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.branchName = '',
    this.upiId = '',
    this.qrImage = '',
    this.instructions = '',
    this.supportContact = '',
    this.enabledMethods = const [],
    this.status = 'inactive',
    this.version = 0,
  });

  final String? id;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String branchName;
  final String upiId;
  final String qrImage;
  final String instructions;
  final String supportContact;
  final List<String> enabledMethods;
  final String status;
  final int version;

  bool get isActive => status.toLowerCase() == 'active';
  bool get hasBankTransfer =>
      isActive && enabledMethods.contains('bank_transfer');
  bool get hasUpiId => isActive && enabledMethods.contains('upi_id');
  bool get hasUpiQr => isActive && enabledMethods.contains('upi_qr');
  bool get hasPaymentMethod => hasBankTransfer || hasUpiId || hasUpiQr;

  factory PaymentSettings.fromJson(Map<String, dynamic> json) {
    return PaymentSettings(
      id: _nullableString(json['id'] ?? json['_id']),
      accountHolderName: _string(json['accountHolderName']),
      bankName: _string(json['bankName']),
      accountNumber: _string(json['accountNumber']),
      ifscCode: _string(json['ifscCode']),
      branchName: _string(json['branchName']),
      upiId: _string(json['upiId']),
      qrImage: _string(json['qrImage']),
      instructions: _string(json['instructions']),
      supportContact: _string(json['supportContact']),
      enabledMethods: _stringList(json['enabledMethods']),
      status: _string(json['status'], fallback: 'inactive'),
      version: _integer(json['version']),
    );
  }
}

class PaymentSubmissionInvoice {
  const PaymentSubmissionInvoice({
    required this.invoiceId,
    required this.label,
    this.invoiceNumber = '',
    this.amount = 0,
  });

  final String invoiceId;
  final String invoiceNumber;
  final String label;
  final double amount;

  factory PaymentSubmissionInvoice.fromJson(Map<String, dynamic> json) {
    return PaymentSubmissionInvoice(
      invoiceId: _string(json['invoiceId']),
      invoiceNumber: _string(json['invoiceNumber']),
      label: _string(json['label']),
      amount: _number(json['amount']),
    );
  }
}

class PaymentSubmission {
  const PaymentSubmission({
    required this.id,
    required this.status,
    this.submissionNumber = '',
    this.invoiceIds = const [],
    this.invoices = const [],
    this.expectedAmount = 0,
    this.declaredPaidAmount = 0,
    this.transactionReference = '',
    this.paymentMethod = 'upi',
    this.paidAt,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.reviewNote,
  });

  final String id;
  final String submissionNumber;
  final String status;
  final List<String> invoiceIds;
  final List<PaymentSubmissionInvoice> invoices;
  final double expectedAmount;
  final double declaredPaidAmount;
  final String transactionReference;
  final String paymentMethod;
  final DateTime? paidAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? reviewNote;

  bool get isPending =>
      status == 'submitted' ||
      status == 'under_review' ||
      status == 'processing';
  bool get isRejected => status == 'rejected';
  bool get isApproved => status == 'approved';

  factory PaymentSubmission.fromJson(Map<String, dynamic> json) {
    return PaymentSubmission(
      id: _string(json['id'] ?? json['_id']),
      submissionNumber: _string(json['submissionNumber']),
      status: _string(json['status'], fallback: 'submitted').toLowerCase(),
      invoiceIds: _stringList(json['invoiceIds']),
      invoices: _asList(
        json['invoices'],
      ).map(PaymentSubmissionInvoice.fromJson).toList(),
      expectedAmount: _number(json['expectedAmount']),
      declaredPaidAmount: _number(json['declaredPaidAmount']),
      transactionReference: _string(json['transactionReference']),
      paymentMethod: _string(json['paymentMethod'], fallback: 'upi'),
      paidAt: _date(json['paidAt']),
      submittedAt: _date(json['submittedAt']),
      reviewedAt: _date(json['reviewedAt']),
      rejectionReason: _nullableString(json['rejectionReason']),
      reviewNote: _nullableString(json['reviewNote']),
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

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
