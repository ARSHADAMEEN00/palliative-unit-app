import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/theme/app_design_system.dart';
import 'models/patient_transfer.dart';
import 'services/patient_transfer_service.dart';
import 'shared/widgets/app_widgets.dart';

class TransferredPatientDetailsPage extends StatefulWidget {
  const TransferredPatientDetailsPage({super.key, required this.snapshotId});

  final String snapshotId;

  @override
  State<TransferredPatientDetailsPage> createState() =>
      _TransferredPatientDetailsPageState();
}

class _TransferredPatientDetailsPageState
    extends State<TransferredPatientDetailsPage> {
  TransferredPatientDetails? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final details = await PatientTransferService.transferredPatient(
        widget.snapshotId,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final historyEntries =
        details?.history.entries
            .where((entry) => entry.value.isNotEmpty)
            .toList() ??
        const [];
    return DefaultTabController(
      length: 1 + historyEntries.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(details?.patient.name ?? 'Transferred Patient'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          bottom: details == null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    const Tab(text: 'Overview'),
                    ...historyEntries.map(
                      (entry) => Tab(
                        text: '${_label(entry.key)} (${entry.value.length})',
                      ),
                    ),
                  ],
                ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? AppEmptyState(
                icon: Icons.error_outline,
                title: 'Could not load snapshot',
                message: _error!,
                action: AppPrimaryButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _load,
                ),
              )
            : TabBarView(
                children: [
                  _overview(details!),
                  ...historyEntries.map(
                    (entry) => _historyList(entry.key, entry.value),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _overview(TransferredPatientDetails details) {
    final snapshot = details.snapshot;
    final transfer = details.transfer;
    final transferredAt = DateTime.tryParse(
      snapshot['transferredAt']?.toString() ?? '',
    )?.toLocal();
    final destination =
        snapshot['destinationUnitName']?.toString() ??
        transfer?.destinationUnit?.name ??
        'another unit';
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Read-only transfer snapshot',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: AppColors.info),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Transferred to $destination'
                      '${transferredAt == null ? '' : ' on ${DateFormat('dd MMM yyyy').format(transferredAt)}'}. '
                      'This frozen record cannot be edited or reactivated.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _card(
          title: 'Patient',
          icon: Icons.person_outline,
          children: [
            _row('Name', details.patient.name),
            _row('Register ID', details.patient.registerId ?? '—'),
            _row(
              'Age / gender',
              '${details.patient.age} / ${details.patient.gender}',
            ),
            _row('Phone', details.patient.phone),
            _row(
              'Address',
              [
                details.patient.address,
                details.patient.place,
                details.patient.village,
              ].where((item) => item.trim().isNotEmpty).join(', '),
            ),
            _row('Diagnosis', details.patient.disease.join(', ')),
            _row('Care plan', details.patient.plan),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _card(
          title: 'Transfer details',
          icon: Icons.swap_horiz,
          children: [
            _row('Destination', destination),
            _row(
              'Reason',
              snapshot['reason']?.toString() ?? transfer?.reason ?? '—',
            ),
            _row(
              'Transfer date',
              _formatDate(snapshot['transferDate'] ?? transfer?.transferDate),
            ),
            _row(
              'Clinical handover',
              snapshot['handoverSummary']?.toString() ??
                  transfer?.handoverSummary ??
                  '—',
            ),
            _row(
              'Transferred by',
              snapshot['transferredByName']?.toString() ?? '—',
            ),
            _row(
              'Integrity',
              snapshot['integrityVerified'] == true
                  ? 'Verified'
                  : 'Not verified',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _card(
          title: 'Frozen history',
          icon: Icons.history,
          children: details.history.entries
              .map(
                (entry) =>
                    _row(_label(entry.key), '${entry.value.length} records'),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _historyList(String entityType, List<Map<String, dynamic>> records) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final record = records[index];
        final title = _recordTitle(entityType, record, index);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: ExpansionTile(
            leading: Icon(_icon(entityType), color: AppColors.primary),
            title: Text(title),
            subtitle: Text(
              _recordSubtitle(record),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(record),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

String _recordTitle(String entityType, Map<String, dynamic> record, int index) {
  for (final key in [
    'patientName',
    'equipmentName',
    'medicineName',
    'volunteerName',
    'title',
    'name',
    'taskType',
    'visitType',
  ]) {
    final value = record[key]?.toString().trim();
    if (value?.isNotEmpty == true) return value!;
  }
  return '${_label(entityType)} ${index + 1}';
}

String _recordSubtitle(Map<String, dynamic> record) {
  for (final key in [
    'visitDate',
    'givenAt',
    'supplyDate',
    'scheduledDate',
    'createdAt',
    'status',
    'notes',
  ]) {
    final value = record[key]?.toString().trim();
    if (value?.isNotEmpty == true) return value!;
  }
  return 'Tap to view the complete frozen record';
}

String _label(String key) {
  const labels = {
    'homeVisits': 'Home visits',
    'visitAssessments': 'Assessments',
    'equipmentSupplies': 'Equipment',
    'externalEquipmentCustodies': 'External equipment custody',
    'medicineSupplies': 'Medicine supplies',
    'legacyMedicineSupplies': 'Legacy medicine supplies',
    'socialSupports': 'Social support',
    'volunteerAssignments': 'Volunteer assignments',
    'volunteerActivityPointLogs': 'Volunteer activity',
    'medicineReferences': 'Medicine references',
    'medicineStockReferences': 'Medicine stock references',
    'equipmentReferences': 'Equipment references',
    'notifications': 'Notifications',
  };
  return labels[key] ?? key;
}

IconData _icon(String key) => switch (key) {
  'homeVisits' => Icons.home_work_outlined,
  'visitAssessments' => Icons.assignment_outlined,
  'equipmentSupplies' ||
  'externalEquipmentCustodies' => Icons.medical_services_outlined,
  'medicineSupplies' || 'legacyMedicineSupplies' => Icons.medication_outlined,
  'socialSupports' => Icons.volunteer_activism_outlined,
  'volunteerAssignments' ||
  'volunteerActivityPointLogs' => Icons.people_outline,
  _ => Icons.description_outlined,
};

String _formatDate(dynamic value) {
  final date = value is DateTime
      ? value
      : DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '—' : DateFormat('dd MMM yyyy').format(date.toLocal());
}

String _friendly(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
