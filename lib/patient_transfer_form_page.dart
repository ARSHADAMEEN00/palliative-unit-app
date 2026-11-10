import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/theme/app_design_system.dart';
import 'models/patient.dart';
import 'models/patient_transfer.dart';
import 'services/patient_transfer_service.dart';
import 'shared/widgets/app_widgets.dart';

class PatientTransferFormPage extends StatefulWidget {
  const PatientTransferFormPage({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientTransferFormPage> createState() =>
      _PatientTransferFormPageState();
}

class _PatientTransferFormPageState extends State<PatientTransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _address = TextEditingController();
  final _handover = TextEditingController();
  final _careStatus = TextEditingController();
  final _remarks = TextEditingController();

  List<TransferUnitSummary> _destinations = const [];
  String? _destinationId;
  DateTime _transferDate = DateTime.now();
  int _step = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _address.text = widget.patient.address;
    _loadDestinations();
  }

  @override
  void dispose() {
    _reason.dispose();
    _address.dispose();
    _handover.dispose();
    _careStatus.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await PatientTransferService.destinations();
      if (!mounted) return;
      setState(() {
        _destinations = destinations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select transfer date',
    );
    if (selected != null && mounted) setState(() => _transferDate = selected);
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    final destinationId = _destinationId;
    if (destinationId == null || _submitting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit transfer request?'),
        content: const Text(
          'The patient record will be locked against clinical changes until '
          'the destination accepts, rejects, or the source cancels this request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await PatientTransferService.create(
        patientId: widget.patient.id!,
        destinationUnitId: destinationId,
        reason: _reason.text,
        transferDate: _transferDate,
        handoverSummary: _handover.text,
        newAddress: _address.text,
        currentCareStatus: _careStatus.text,
        remarks: _remarks.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer request submitted'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_message(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transfer Patient'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppEmptyState(
              icon: Icons.sync_problem_outlined,
              title: 'Destinations unavailable',
              message: _error!,
              action: AppPrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _loadDestinations,
              ),
            )
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: Stepper(
                    currentStep: _step,
                    onStepTapped: (step) {
                      if (step == 0 ||
                          (_formKey.currentState?.validate() ?? false)) {
                        setState(() => _step = step);
                      }
                    },
                    controlsBuilder: (context, details) => Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppPrimaryButton(
                              label: _step == 0
                                  ? 'Review transfer'
                                  : 'Submit request',
                              icon: _step == 0
                                  ? Icons.arrow_forward
                                  : Icons.send_outlined,
                              onPressed: _step == 0 ? _continue : _submit,
                            ),
                          ),
                          if (_step == 1) ...[
                            const SizedBox(width: AppSpacing.sm),
                            AppSecondaryButton(
                              label: 'Back',
                              onPressed: () => setState(() => _step = 0),
                            ),
                          ],
                        ],
                      ),
                    ),
                    steps: [
                      Step(
                        title: const Text('Handover details'),
                        isActive: _step == 0,
                        state: _step > 0
                            ? StepState.complete
                            : StepState.indexed,
                        content: _buildForm(),
                      ),
                      Step(
                        title: const Text('Review and submit'),
                        isActive: _step == 1,
                        content: _buildReview(),
                      ),
                    ],
                  ),
                ),
                if (_submitting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildForm() {
    final dropdownStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.text,
        );
    return Column(
      children: [
        _patientHeader(),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _destinationId,
          style: dropdownStyle,
          decoration: const InputDecoration(
            labelText: 'Destination unit *',
            prefixIcon: Icon(Icons.local_hospital_outlined),
          ),
          items: _destinations
              .map(
                (unit) => DropdownMenuItem(
                  value: unit.id,
                  child: Text(
                    unit.code == null
                        ? unit.name
                        : '${unit.name} (${unit.code})',
                    style: dropdownStyle,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _destinationId = value),
          validator: (value) =>
              value == null ? 'Select a destination unit' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _reason,
          maxLines: 2,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Transfer reason *',
            alignLabelWithHint: true,
          ),
          validator: _required,
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Transfer date *',
              prefixIcon: Icon(Icons.event_outlined),
            ),
            child: Text(DateFormat('dd MMM yyyy').format(_transferDate)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'New address / place',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _handover,
          minLines: 4,
          maxLines: 8,
          maxLength: 12000,
          decoration: const InputDecoration(
            labelText: 'Clinical handover summary *',
            hintText:
                'Current condition, risks, treatment, and follow-up needs',
            alignLabelWithHint: true,
          ),
          validator: _required,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _careStatus,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Current care status',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _remarks,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Initiator remarks',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final destination = _destinations
        .where((unit) => unit.id == _destinationId)
        .firstOrNull;
    return Column(
      children: [
        _patientHeader(),
        const SizedBox(height: AppSpacing.md),
        _reviewRow('Destination', destination?.name ?? '—'),
        _reviewRow(
          'Transfer date',
          DateFormat('dd MMM yyyy').format(_transferDate),
        ),
        _reviewRow('Reason', _reason.text),
        if (_address.text.trim().isNotEmpty)
          _reviewRow('New address', _address.text),
        _reviewRow('Clinical handover', _handover.text),
        if (_careStatus.text.trim().isNotEmpty)
          _reviewRow('Care status', _careStatus.text),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.09),
            borderRadius: AppRadius.card,
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_clock_outlined, color: AppColors.warning),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Submitting locks this patient against changes while the '
                  'destination completes its review. You can cancel while pending.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _patientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.patient.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              if (widget.patient.registerId?.isNotEmpty == true)
                'REG ${widget.patient.registerId}',
              '${widget.patient.age} years',
              widget.patient.place,
            ].where((item) => item.isNotEmpty).join(' • '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value?.trim().isEmpty ?? true ? 'This field is required' : null;
  }
}

String _message(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
