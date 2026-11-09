import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_design_system.dart';
import 'models/patient_transfer.dart';
import 'services/auth_service.dart';
import 'services/patient_transfer_service.dart';
import 'shared/widgets/app_widgets.dart';

class PatientTransferReviewPage extends StatefulWidget {
  const PatientTransferReviewPage({
    super.key,
    required this.requestId,
    required this.incoming,
  });

  final String requestId;
  final bool incoming;

  @override
  State<PatientTransferReviewPage> createState() =>
      _PatientTransferReviewPageState();
}

class _PatientTransferReviewPageState extends State<PatientTransferReviewPage> {
  PatientTransferDetails? _details;
  final Set<String> _checked = {};
  final _verifier = TextEditingController();
  final _duplicateReason = TextEditingController();
  bool _duplicateConfirmed = false;
  bool _loading = true;
  bool _mutating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifier.text = context.read<AuthService>().userDisplayName ?? '';
    });
    _load();
  }

  @override
  void dispose() {
    _verifier.dispose();
    _duplicateReason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final details = await PatientTransferService.details(widget.requestId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _checked
          ..clear()
          ..addAll(
            details.request.verificationChecklist
                .where((item) => item.checked)
                .map((item) => item.key),
          );
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

  Future<void> _accept() async {
    final request = _details?.request;
    if (request == null || _mutating) return;
    final missing = request.verificationChecklist.any(
      (item) => item.required && !_checked.contains(item.key),
    );
    if (missing) {
      _showError('Complete every required verification check.');
      return;
    }
    if (_verifier.text.trim().isEmpty) {
      _showError('Enter the verifier name.');
      return;
    }
    if (request.hasPossibleDuplicate &&
        (!_duplicateConfirmed || _duplicateReason.text.trim().isEmpty)) {
      _showError(
        'Review the possible duplicate and record why it is not the same patient.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept patient transfer?'),
        content: const Text(
          'This atomically moves the live patient and full history to this '
          'unit. The source will retain a permanent read-only snapshot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutating = true);
    try {
      await PatientTransferService.accept(
        request: request,
        checkedKeys: _checked,
        verifierName: _verifier.text,
        duplicateResolutionReason: request.hasPossibleDuplicate
            ? _duplicateReason.text
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient transfer accepted'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _mutating = false);
      _showError(_friendly(error));
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject transfer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 5000,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'Explain what the source unit needs to address',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _runMutation(
      () => PatientTransferService.reject(widget.requestId, reason),
      'Transfer request rejected',
    );
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel transfer request?'),
        content: const Text(
          'The patient will be unlocked and remain in this unit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => PatientTransferService.cancel(widget.requestId),
      'Transfer request cancelled',
    );
  }

  Future<void> _runMutation(
    Future<PatientTransferRequest> Function() operation,
    String success,
  ) async {
    setState(() => _mutating = true);
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _mutating = false);
      _showError(_friendly(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final request = _details?.request;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transfer Review'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load request',
              message: _error!,
              action: AppPrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            )
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    120,
                  ),
                  children: [
                    _statusBanner(request!),
                    const SizedBox(height: AppSpacing.md),
                    _section(
                      'Patient preview',
                      Icons.person_outline,
                      _patientPreview(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _section('Handover', Icons.handshake_outlined, _handover()),
                    const SizedBox(height: AppSpacing.md),
                    _section(
                      'Records included',
                      Icons.inventory_2_outlined,
                      _recordCounts(),
                    ),
                    if (request.hasPossibleDuplicate) ...[
                      const SizedBox(height: AppSpacing.md),
                      _duplicateReview(request),
                    ],
                    if (widget.incoming &&
                        request.isPending &&
                        auth.canReviewPatientTransfer) ...[
                      const SizedBox(height: AppSpacing.md),
                      _verification(request),
                    ],
                  ],
                ),
                if (_mutating)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.surface.withValues(alpha: 0.78),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: request?.isPending == true
          ? SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: widget.incoming && auth.canReviewPatientTransfer
                  ? Row(
                      children: [
                        Expanded(
                          child: AppDangerButton(
                            label: 'Reject',
                            icon: Icons.close,
                            onPressed: _mutating ? null : _reject,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppPrimaryButton(
                            label: 'Accept',
                            icon: Icons.check,
                            onPressed: _mutating ? null : _accept,
                          ),
                        ),
                      ],
                    )
                  : !widget.incoming && auth.canInitiatePatientTransfer
                  ? AppDangerButton(
                      label: 'Cancel request',
                      icon: Icons.cancel_outlined,
                      onPressed: _mutating ? null : _cancel,
                    )
                  : const SizedBox.shrink(),
            )
          : null,
    );
  }

  Widget _statusBanner(PatientTransferRequest request) {
    final color = _statusColor(request.status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.status,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${request.sourceUnit?.name ?? 'Source unit'} → '
                  '${request.destinationUnit?.name ?? 'Destination unit'}',
                ),
              ],
            ),
          ),
          if (request.expiresAt != null && request.isPending)
            Text(
              'Expires\n${DateFormat('dd MMM').format(request.expiresAt!)}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }

  Widget _patientPreview() {
    final patient = _details?.preview?.patient;
    if (patient == null) return const Text('Preview is no longer available.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(patient.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        _line('Register ID', patient.registerId ?? '—'),
        _line('Age / gender', '${patient.age} / ${patient.gender}'),
        _line('Phone', patient.phone),
        _line(
          'Place',
          [
            patient.place,
            patient.village,
          ].where((v) => v.isNotEmpty).join(', '),
        ),
        _line('Diagnosis', patient.disease.join(', ')),
      ],
    );
  }

  Widget _handover() {
    final request = _details!.request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('Reason', request.reason),
        _line(
          'Transfer date',
          DateFormat('dd MMM yyyy').format(request.transferDate),
        ),
        if (request.newAddress?.isNotEmpty == true)
          _line('New address', request.newAddress!),
        _line('Clinical summary', request.handoverSummary),
        if (request.currentCareStatus?.isNotEmpty == true)
          _line('Care status', request.currentCareStatus!),
        if (request.remarks?.isNotEmpty == true)
          _line('Remarks', request.remarks!),
      ],
    );
  }

  Widget _recordCounts() {
    final request = _details!.request;
    final details = _details!.preview;
    final counts = <String, int>{
      'Home visits': details?.homeVisits.length ?? 0,
      'Assessments': details?.visitAssessments.length ?? 0,
      'Equipment records': details?.equipmentSupplies.length ?? 0,
      'Medicine supplies': details?.medicineSupplies.length ?? 0,
      'Social support': details?.socialSupports.length ?? 0,
      'Issued equipment': request.equipmentCurrentlyIssued.length,
      'Pending tasks': request.pendingVisitsAndTasks.length,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: counts.entries
          .map(
            (entry) => Chip(
              avatar: CircleAvatar(child: Text('${entry.value}')),
              label: Text(entry.key),
            ),
          )
          .toList(),
    );
  }

  Widget _duplicateReview(PatientTransferRequest request) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Possible duplicate found',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...request.duplicateCandidates.map(
            (candidate) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_search_outlined),
              title: Text(candidate.name),
              subtitle: Text(
                [
                  if (candidate.registerId != null)
                    'REG ${candidate.registerId}',
                  if (candidate.phoneMatch) 'Phone match',
                  if (candidate.nameAgeMatch) 'Name and age match',
                ].join(' • '),
              ),
            ),
          ),
          if (widget.incoming && request.isPending) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _duplicateConfirmed,
              onChanged: (value) =>
                  setState(() => _duplicateConfirmed = value == true),
              title: const Text('I verified this is not the same patient'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextField(
              controller: _duplicateReason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Duplicate review notes *',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _verification(PatientTransferRequest request) {
    return _section(
      'Destination verification',
      Icons.verified_user_outlined,
      Column(
        children: [
          ...request.verificationChecklist.map(
            (item) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _checked.contains(item.key),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _checked.add(item.key);
                } else {
                  _checked.remove(item.key);
                }
              }),
              title: Text(item.label),
              subtitle: item.required ? const Text('Required') : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          TextField(
            controller: _verifier,
            decoration: const InputDecoration(
              labelText: 'Verifier name *',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Widget child) {
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
          child,
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(value),
        ],
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'ACCEPTED' => AppColors.success,
  'REJECTED' => AppColors.danger,
  'CANCELLED' || 'EXPIRED' => AppColors.textMuted,
  _ => AppColors.warning,
};

String _friendly(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
