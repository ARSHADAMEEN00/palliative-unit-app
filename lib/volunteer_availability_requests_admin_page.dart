import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/services/volunteer_availability_request_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

class VolunteerAvailabilityRequestsAdminPage extends StatefulWidget {
  const VolunteerAvailabilityRequestsAdminPage({super.key});

  @override
  State<VolunteerAvailabilityRequestsAdminPage> createState() =>
      _VolunteerAvailabilityRequestsAdminPageState();
}

class _VolunteerAvailabilityRequestsAdminPageState
    extends State<VolunteerAvailabilityRequestsAdminPage> {
  List<VolunteerAvailabilityRequest> _requests = const [];
  final Set<String> _busyIds = {};
  bool _loading = true;
  bool _showHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await VolunteerAvailabilityRequestService.getRequests(
        status: _showHistory ? null : 'pending',
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _review(
    VolunteerAvailabilityRequest request,
    String status,
  ) async {
    final approving = status == 'approved';
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => VolunteerAvailabilityReviewDialog(
        request: request,
        approving: approving,
        dateLabel: _dateLabel(request.requestedDate),
      ),
    );
    if (note == null || !mounted) return;

    // Allow the dialog and its focused form field to finish deactivating before
    // this page updates the request card that launched it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    setState(() => _busyIds.add(request.id));
    try {
      final updated = await VolunteerAvailabilityRequestService.review(
        request.id,
        status,
        decisionNote: note,
      );
      if (!mounted) return;
      setState(() {
        if (_showHistory) {
          final index = _requests.indexWhere((item) => item.id == request.id);
          if (index != -1) _requests[index] = updated;
        } else {
          _requests = _requests.where((item) => item.id != request.id).toList();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approving
                ? 'Availability approved and note sent.'
                : 'Availability request declined.',
          ),
          backgroundColor: approving ? AppColors.success : AppColors.text,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('EEEE, d MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Volunteer Requests'),
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppInsets.screenHorizontal(context),
              AppSpacing.xs,
              AppInsets.screenHorizontal(context),
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showHistory
                        ? 'All availability requests'
                        : '${_requests.length} waiting for review',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                FilterChip(
                  selected: _showHistory,
                  label: const Text('Show history'),
                  onSelected: (value) {
                    setState(() => _showHistory = value);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AppListSkeleton(itemCount: 5)
                : _error != null
                ? AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Unable to load requests',
                    message: _error!,
                    action: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  )
                : _requests.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: const [
                        SizedBox(height: 120),
                        AppEmptyState(
                          icon: Icons.how_to_reg_outlined,
                          title: 'No volunteer requests',
                          message:
                              'New availability requests will appear here.',
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: AppInsets.screen(
                        context,
                        top: 0,
                        bottom: AppSpacing.xxl,
                      ),
                      itemCount: _requests.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) =>
                          _buildRequestCard(_requests[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(VolunteerAvailabilityRequest request) {
    final busy = _busyIds.contains(request.id);
    final pending = request.status == 'pending';
    final statusColor = request.status == 'approved'
        ? AppColors.success
        : request.status == 'declined'
        ? AppColors.danger
        : AppColors.warning;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.volunteer_activism_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.contactName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateLabel(request.requestedDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (request.timeSlot != null &&
                        request.timeSlot!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.timeSlot!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.status[0].toUpperCase() + request.status.substring(1),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _detailLine(Icons.phone_outlined, request.phone),
          const SizedBox(height: AppSpacing.xs),
          _detailLine(Icons.location_on_outlined, request.address),
          if (request.decisionNote?.trim().isNotEmpty == true) ...[
            const Divider(height: AppSpacing.lg),
            _detailLine(Icons.sticky_note_2_outlined, request.decisionNote!),
          ],
          if (pending) ...[
            const Divider(height: AppSpacing.lg),
            if (busy)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _review(request, 'declined'),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _review(request, 'approved'),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

@visibleForTesting
class VolunteerAvailabilityReviewDialog extends StatefulWidget {
  const VolunteerAvailabilityReviewDialog({
    required this.request,
    required this.approving,
    required this.dateLabel,
  });

  final VolunteerAvailabilityRequest request;
  final bool approving;
  final String dateLabel;

  @override
  State<VolunteerAvailabilityReviewDialog> createState() =>
      _AvailabilityReviewDialogState();
}

class _AvailabilityReviewDialogState
    extends State<VolunteerAvailabilityReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  bool _closing = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_closing || _formKey.currentState?.validate() != true) return;
    final note = _noteController.text.trim();
    setState(() => _closing = true);
    FocusManager.instance.primaryFocus?.unfocus();

    // Give EditableText one frame to detach its focus dependency before the
    // dialog route is removed.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      title: Text(
        widget.approving ? 'Approve availability?' : 'Decline availability?',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.request.contactName} • ${widget.dateLabel}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (widget.request.timeSlot != null &&
                widget.request.timeSlot!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Time: ${widget.request.timeSlot!}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.approving
                  ? 'The volunteer will be notified, but will not be assigned to a home visit.'
                  : 'The volunteer will receive this update in notifications.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              autofocus: widget.approving,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.approving
                    ? 'Note to volunteer'
                    : 'Note (optional)',
                hintText: widget.approving
                    ? 'Example: Please visit the unit on the day.'
                    : 'Reason or next step',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                alignLabelWithHint: true,
              ),
              validator: widget.approving
                  ? (value) => value == null || value.trim().isEmpty
                        ? 'Add a note before approving'
                        : null
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.approving
                ? AppColors.success
                : AppColors.danger,
          ),
          onPressed: _closing ? null : _confirm,
          child: Text(
            widget.approving ? 'Confirm approval' : 'Confirm decline',
          ),
        ),
      ],
    );
  }
}
