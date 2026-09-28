import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/features/reports/models/report_models.dart';

class ReportColumn {
  const ReportColumn(this.key, this.label, {this.numeric = false});

  final String key;
  final String label;
  final bool numeric;
}

class ReportChoice {
  const ReportChoice(this.value, this.label);

  final String value;
  final String label;
}

class ReportFilterDefinition {
  const ReportFilterDefinition({
    required this.key,
    required this.label,
    required this.choices,
  });

  final String key;
  final String label;
  final List<ReportChoice> choices;
}

class ReportSortDefinition {
  const ReportSortDefinition(this.field, this.label);

  final String field;
  final String label;
}

class ReportDefinition {
  const ReportDefinition({
    required this.type,
    required this.icon,
    required this.color,
    required this.summaryLabels,
    required this.columns,
    required this.filters,
    required this.sorts,
  });

  final ReportType type;
  final IconData icon;
  final Color color;
  final Map<String, String> summaryLabels;
  final List<ReportColumn> columns;
  final List<ReportFilterDefinition> filters;
  final List<ReportSortDefinition> sorts;
}

const reportDefinitions = <ReportType, ReportDefinition>{
  ReportType.medicineStock: ReportDefinition(
    type: ReportType.medicineStock,
    icon: Icons.medication_outlined,
    color: Color(0xFF0F766E),
    summaryLabels: {
      'medicines': 'Medicines',
      'batches': 'Batches',
      'totalQuantity': 'Total Qty',
      'lowStock': 'Low Stock',
      'outOfStock': 'Out of Stock',
      'expired': 'Expired',
      'expiringSoon': 'Expiring Soon',
    },
    columns: [
      ReportColumn('medicineCode', 'Code'),
      ReportColumn('medicineName', 'Medicine'),
      ReportColumn('category', 'Category'),
      ReportColumn('batchNumber', 'Batch'),
      ReportColumn('batchQuantity', 'Batch Qty', numeric: true),
      ReportColumn('totalQuantity', 'Total Qty', numeric: true),
      ReportColumn('qtyUnit', 'Unit'),
      ReportColumn('expiryDate', 'Expiry'),
      ReportColumn('daysToExpiry', 'Days', numeric: true),
      ReportColumn('stockStatus', 'Stock Status'),
      ReportColumn('expiryStatus', 'Expiry Status'),
    ],
    filters: [
      ReportFilterDefinition(
        key: 'stockStatus',
        label: 'Stock status',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('in_stock', 'In stock'),
          ReportChoice('low_stock', 'Low stock'),
          ReportChoice('out_of_stock', 'Out of stock'),
        ],
      ),
      ReportFilterDefinition(
        key: 'expiryStatus',
        label: 'Expiry status',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('near_expiry', 'Expiring soon'),
          ReportChoice('expired', 'Expired'),
          ReportChoice('valid', 'Valid'),
          ReportChoice('depleted', 'Depleted batch'),
          ReportChoice('not_recorded', 'Not recorded'),
        ],
      ),
      ReportFilterDefinition(
        key: 'category',
        label: 'Category',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('opioid', 'Opioid'),
          ReportChoice('nsaid', 'NSAID'),
          ReportChoice('antiemetic', 'Antiemetic'),
          ReportChoice('anxiolytic', 'Anxiolytic'),
          ReportChoice('corticosteroid', 'Corticosteroid'),
          ReportChoice('laxative', 'Laxative'),
          ReportChoice('other', 'Other'),
        ],
      ),
      ReportFilterDefinition(
        key: 'formulation',
        label: 'Formulation',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('tablet', 'Tablet'),
          ReportChoice('capsule', 'Capsule'),
          ReportChoice('syrup', 'Syrup'),
          ReportChoice('injection', 'Injection'),
          ReportChoice('patch', 'Patch'),
          ReportChoice('suppository', 'Suppository'),
          ReportChoice('drops', 'Drops'),
        ],
      ),
      ReportFilterDefinition(
        key: 'isActive',
        label: 'Medicine state',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('true', 'Active'),
          ReportChoice('false', 'Inactive'),
        ],
      ),
    ],
    sorts: [
      ReportSortDefinition('medicineName', 'Medicine name'),
      ReportSortDefinition('medicineCode', 'Medicine code'),
      ReportSortDefinition('totalQuantity', 'Total quantity'),
      ReportSortDefinition('expiryDate', 'Expiry date'),
      ReportSortDefinition('category', 'Category'),
    ],
  ),
  ReportType.medicineSupplies: ReportDefinition(
    type: ReportType.medicineSupplies,
    icon: Icons.vaccines_outlined,
    color: Color(0xFF0F766E),
    summaryLabels: {
      'records': 'Supply Records',
      'patients': 'Patients',
      'quantityGiven': 'Qty Given',
      'quantityReturned': 'Qty Returned',
      'netQuantity': 'Net Supplied',
    },
    columns: [
      ReportColumn('givenAt', 'Date'),
      ReportColumn('registerId', 'Register ID'),
      ReportColumn('patientName', 'Patient'),
      ReportColumn('medicineCode', 'Medicine Code'),
      ReportColumn('medicineName', 'Medicine'),
      ReportColumn('qtyGiven', 'Given', numeric: true),
      ReportColumn('qtyReturned', 'Returned', numeric: true),
      ReportColumn('netQuantity', 'Net', numeric: true),
      ReportColumn('givenBy', 'Given By'),
      ReportColumn('prescribedBy', 'Prescribed By'),
      ReportColumn('status', 'Status'),
    ],
    filters: [
      ReportFilterDefinition(
        key: 'status',
        label: 'Status',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('given', 'Given'),
          ReportChoice('partially_given', 'Partially returned'),
          ReportChoice('returned', 'Returned'),
          ReportChoice('cancelled', 'Cancelled'),
        ],
      ),
    ],
    sorts: [
      ReportSortDefinition('givenAt', 'Supply date'),
      ReportSortDefinition('patientName', 'Patient'),
      ReportSortDefinition('medicineName', 'Medicine'),
      ReportSortDefinition('netQuantity', 'Net quantity'),
      ReportSortDefinition('status', 'Status'),
    ],
  ),
  ReportType.equipmentStock: ReportDefinition(
    type: ReportType.equipmentStock,
    icon: Icons.inventory_2_outlined,
    color: Color(0xFFD97706),
    summaryLabels: {
      'total': 'Total',
      'available': 'Available',
      'supplied': 'Supplied',
      'maintenance': 'Damaged',
    },
    columns: [
      ReportColumn('uniqueId', 'Unique ID'),
      ReportColumn('equipmentName', 'Equipment'),
      ReportColumn('status', 'Status'),
      ReportColumn('damageReason', 'Damage Reason'),
      ReportColumn('damagedAt', 'Damaged On'),
      ReportColumn('storagePlace', 'Storage'),
      ReportColumn('purchasedFrom', 'Purchased From'),
      ReportColumn('purchaseDate', 'Purchase Date'),
      ReportColumn('place', 'Place'),
      ReportColumn('createdBy', 'Added By'),
    ],
    filters: [
      ReportFilterDefinition(
        key: 'status',
        label: 'Status',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('available', 'Available'),
          ReportChoice('supplied', 'Supplied'),
          ReportChoice('maintenance', 'Damaged'),
        ],
      ),
    ],
    sorts: [
      ReportSortDefinition('equipmentName', 'Equipment name'),
      ReportSortDefinition('uniqueId', 'Unique ID'),
      ReportSortDefinition('purchaseDate', 'Purchase date'),
      ReportSortDefinition('status', 'Status'),
      ReportSortDefinition('storagePlace', 'Storage place'),
    ],
  ),
  ReportType.equipmentDamageHistory: ReportDefinition(
    type: ReportType.equipmentDamageHistory,
    icon: Icons.home_repair_service_outlined,
    color: Color(0xFFDC2626),
    summaryLabels: {
      'incidents': 'Incidents',
      'equipment': 'Equipment',
      'damaged': 'Still Damaged',
      'repaired': 'Repaired',
    },
    columns: [
      ReportColumn('uniqueId', 'Unique ID'),
      ReportColumn('equipmentName', 'Equipment'),
      ReportColumn('damageReason', 'Damage Reason'),
      ReportColumn('damagedAt', 'Damaged On'),
      ReportColumn('repairedAt', 'Repaired On'),
      ReportColumn('repairStatus', 'Status'),
      ReportColumn('downtimeDays', 'Days Out', numeric: true),
      ReportColumn('damagedBy', 'Recorded By'),
      ReportColumn('repairedBy', 'Repaired By'),
    ],
    filters: [
      ReportFilterDefinition(
        key: 'repairStatus',
        label: 'Repair status',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('damaged', 'Still Damaged'),
          ReportChoice('repaired', 'Repaired'),
        ],
      ),
    ],
    sorts: [
      ReportSortDefinition('damagedAt', 'Damage date'),
      ReportSortDefinition('repairedAt', 'Repair date'),
      ReportSortDefinition('equipmentName', 'Equipment name'),
      ReportSortDefinition('uniqueId', 'Unique ID'),
      ReportSortDefinition('downtimeDays', 'Days out of service'),
      ReportSortDefinition('repairStatus', 'Repair status'),
    ],
  ),
  ReportType.equipmentSupplies: ReportDefinition(
    type: ReportType.equipmentSupplies,
    icon: Icons.wheelchair_pickup_outlined,
    color: Color(0xFFD97706),
    summaryLabels: {
      'records': 'Records',
      'active': 'Active',
      'returned': 'Returned',
      'lost': 'Lost',
      'overdue': 'Overdue',
      'dueSoon': 'Due Soon',
    },
    columns: [
      ReportColumn('equipmentUniqueId', 'Equipment ID'),
      ReportColumn('equipmentName', 'Equipment'),
      ReportColumn('patientName', 'Patient / Receiver'),
      ReportColumn('patientPlace', 'Place'),
      ReportColumn('supplyDate', 'Supplied'),
      ReportColumn('returnDate', 'Expected Return'),
      ReportColumn('actualReturnDate', 'Actual Return'),
      ReportColumn('durationDays', 'Days', numeric: true),
      ReportColumn('reportStatus', 'Status'),
    ],
    filters: [
      ReportFilterDefinition(
        key: 'status',
        label: 'Status',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('active', 'Active'),
          ReportChoice('returned', 'Returned'),
          ReportChoice('lost', 'Lost'),
          ReportChoice('overdue', 'Overdue'),
          ReportChoice('due_soon', 'Due soon'),
        ],
      ),
    ],
    sorts: [
      ReportSortDefinition('supplyDate', 'Supply date'),
      ReportSortDefinition('returnDate', 'Expected return'),
      ReportSortDefinition('patientName', 'Patient / receiver'),
      ReportSortDefinition('equipmentName', 'Equipment'),
      ReportSortDefinition('durationDays', 'Duration'),
    ],
  ),
  ReportType.socialSupport: ReportDefinition(
    type: ReportType.socialSupport,
    icon: Icons.volunteer_activism_outlined,
    color: Color(0xFFBE185D),
    summaryLabels: {
      'records': 'Records',
      'patients': 'Patients',
      'volunteers': 'Volunteers',
      'rationKits': 'Ration Kits',
      'vegetables': 'Vegetables',
      'medicine': 'Medicine',
    },
    columns: [
      ReportColumn('givenAt', 'Date'),
      ReportColumn('registerId', 'Register ID'),
      ReportColumn('patientName', 'Patient'),
      ReportColumn('patientPlace', 'Place'),
      ReportColumn('supportTypesLabel', 'Support'),
      ReportColumn('volunteerName', 'Volunteer'),
      ReportColumn('volunteerContact', 'Contact'),
      ReportColumn('note', 'Notes'),
    ],
    filters: [
      ReportFilterDefinition(
        key: 'supportType',
        label: 'Support type',
        choices: [
          ReportChoice('', 'All'),
          ReportChoice('ration_kit', 'Ration Kit'),
          ReportChoice('vegetables', 'Vegetables'),
          ReportChoice('medicine', 'Medicine'),
        ],
      ),
    ],
    sorts: [
      ReportSortDefinition('givenAt', 'Support date'),
      ReportSortDefinition('patientName', 'Patient'),
      ReportSortDefinition('volunteerName', 'Volunteer'),
      ReportSortDefinition('supportTypesLabel', 'Support type'),
    ],
  ),
};

String formatReportValue(String key, dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return '—';
  if (value is List) {
    return value.map((item) => _title(item.toString())).join(', ');
  }
  if (key.toLowerCase().contains('date') || key.endsWith('At')) {
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return DateFormat('dd MMM yyyy').format(parsed.toLocal());
    }
  }
  if (value is num) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }
  if (key.toLowerCase().contains('status') || key == 'category') {
    return _title(value.toString());
  }
  return value.toString();
}

String _title(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
