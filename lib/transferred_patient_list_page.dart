import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/theme/app_design_system.dart';
import 'models/patient_transfer.dart';
import 'services/patient_transfer_service.dart';
import 'shared/widgets/app_widgets.dart';
import 'transferred_patient_details_page.dart';

class TransferredPatientListPage extends StatefulWidget {
  const TransferredPatientListPage({super.key});

  @override
  State<TransferredPatientListPage> createState() =>
      _TransferredPatientListPageState();
}

class _TransferredPatientListPageState
    extends State<TransferredPatientListPage> {
  final _search = TextEditingController();
  List<TransferredPatientSummary> _patients = const [];
  List<TransferUnitSummary> _units = const [];
  String? _destinationUnitId;
  DateTimeRange? _range;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await PatientTransferService.destinations();
      if (mounted) setState(() => _units = units);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await PatientTransferService.transferredPatients(
        search: _search.text,
        destinationUnitId: _destinationUnitId,
        from: _range?.start,
        to: _range?.end,
      );
      if (!mounted) return;
      setState(() {
        _patients = page.patients;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Filter by transfer date',
    );
    if (range == null || !mounted) return;
    setState(() => _range = range);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transferred Patients'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search patient, register ID, or reason',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              _load();
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _destinationUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Destination',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All units'),
                          ),
                          ..._units.map(
                            (unit) => DropdownMenuItem<String?>(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _destinationUnitId = value);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          _range == null
                              ? 'Any date'
                              : '${DateFormat('dd MMM').format(_range!.start)} – '
                                    '${DateFormat('dd MMM').format(_range!.end)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_range != null)
                      IconButton(
                        tooltip: 'Clear date filter',
                        onPressed: () {
                          setState(() => _range = null);
                          _load();
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const AppListSkeleton(itemCount: 6);
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load transferred patients',
        message: _error!,
        action: AppPrimaryButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: _load,
        ),
      );
    }
    if (_patients.isEmpty) {
      return const AppEmptyState(
        icon: Icons.archive_outlined,
        title: 'No transferred patients',
        message:
            'Accepted outbound transfers will be retained here as read-only records.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: _patients.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final patient = _patients[index];
          return AppCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TransferredPatientDetailsPage(snapshotId: patient.id),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.archive_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.patientName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Transferred to ${patient.destinationUnitName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(patient.transferredAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _friendly(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
