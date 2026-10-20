import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/localization/volunteer_request_messages.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/models/volunteer_assignment.dart';
import 'package:oruma_app/services/volunteer_assignment_service.dart';
import 'package:url_launcher/url_launcher.dart';

class VolunteerAssignmentDetailPage extends StatefulWidget {
  final String assignmentId;
  final VolunteerAssignment? initialAssignment;

  const VolunteerAssignmentDetailPage({
    super.key,
    required this.assignmentId,
    this.initialAssignment,
  });

  @override
  State<VolunteerAssignmentDetailPage> createState() =>
      _VolunteerAssignmentDetailPageState();
}

class _VolunteerAssignmentDetailPageState
    extends State<VolunteerAssignmentDetailPage> {
  VolunteerAssignment? _assignment;
  bool _loading = true;
  bool _submitting = false;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _assignment = widget.initialAssignment;
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    try {
      final doc = await VolunteerAssignmentService.getAssignment(
        widget.assignmentId,
      );
      if (mounted) {
        setState(() {
          _assignment = doc;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap(String address, String? link) async {
    if (link != null && link.trim().isNotEmpty) {
      final uri = Uri.tryParse(link.trim());
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final encoded = Uri.encodeComponent(address.trim());
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _acceptAssignment() async {
    setState(() => _submitting = true);
    try {
      final res = await VolunteerAssignmentService.updateStatus(
        widget.assignmentId,
        'accepted',
      );
      if (mounted) {
        setState(() {
          _assignment = res['assignment'] as VolunteerAssignment;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment accepted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showCancelDialog() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          title: const Text('Cancel Assignment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_assignment?.typeLabel ?? "Assignment"} • ${_assignment?.patient.name ?? ""}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to cancel this accepted request? A canceled request is final and cannot be reopened.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Reason for cancellation (optional)',
                  hintText: 'e.g. Schedule conflict or emergency',
                  prefixIcon: const Icon(Icons.comment_outlined),
                  filled: true,
                  fillColor: AppColors.surface1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Assignment'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textSecondary,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _submitting = true);
      try {
        final updated = await VolunteerAssignmentService.cancelAssignment(
          widget.assignmentId,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : null,
        );
        if (mounted) {
          setState(() {
            _assignment = updated;
            _submitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment has been canceled.'),
              backgroundColor: AppColors.text,
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCompleteDialog() async {
    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceFloating,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Complete Assignment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Mark this assignment as completed. Points are awarded when eligible tasks are assigned, not when they are completed.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add an optional visit note or observation...',
                  filled: true,
                  fillColor: AppColors.surface1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Mark Completed',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _submitting = true);
      try {
        final res = await VolunteerAssignmentService.updateStatus(
          widget.assignmentId,
          'completed',
          notes: noteController.text.trim().isNotEmpty
              ? noteController.text.trim()
              : null,
        );

        if (mounted) {
          final updated = res['assignment'] as VolunteerAssignment;
          setState(() {
            _assignment = updated;
            _submitting = false;
            _wasCompleted = true;
          });

          // Show Celebration Dialog
          _showCelebrationDialog();
        }
      } catch (err) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.toString()), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🎉', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Great Work!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Assignment successfully marked as completed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _taskColor(String type) {
    switch (type) {
      case 'home_visit':
        return const Color(0xFF0D9488); // Teal
      case 'visit_assessment':
        return const Color(0xFFD97706); // Amber
      case 'social_support':
        return const Color(0xFFBE185D); // Pink
      default:
        return AppColors.primary;
    }
  }

  IconData _taskIcon(String type) {
    switch (type) {
      case 'home_visit':
        return Icons.home_work_rounded;
      case 'visit_assessment':
        return Icons.assignment_rounded;
      case 'social_support':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Color _statusColor(String status) {
    return VolunteerRequestMessages.getStatusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    final assignment = _assignment;

    if (_loading && assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Assignment')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Assignment')),
        body: const Center(child: Text('Assignment not found')),
      );
    }

    final color = _taskColor(assignment.taskType);
    final icon = _taskIcon(assignment.taskType);
    final statusColor = _statusColor(assignment.status);

    DateTime? scheduledDate;
    try {
      scheduledDate = DateTime.tryParse(assignment.scheduledDate);
    } catch (_) {}

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _wasCompleted);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(assignment.typeLabel),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: BackButton(
            onPressed: () => Navigator.pop(context, _wasCompleted),
          ),
          actions: [
            if (assignment.isAccepted)
              IconButton(
                tooltip: 'Cancel Assignment',
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: _submitting ? null : _showCancelDialog,
              ),
          ],
        ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surfaceFloating,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (assignment.patient.phone != null &&
                  assignment.patient.phone!.isNotEmpty) ...[
                IconButton.filledTonal(
                  onPressed: () => _callPhone(assignment.patient.phone!),
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Call Patient',
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (assignment.patient.address.isNotEmpty ||
                  assignment.patient.locationLink != null) ...[
                IconButton.filledTonal(
                  onPressed: () => _openMap(
                    assignment.patient.address,
                    assignment.patient.locationLink,
                  ),
                  icon: const Icon(Icons.directions_rounded),
                  tooltip: 'Open in Maps',
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: assignment.status == 'assigned'
                    ? ElevatedButton.icon(
                        onPressed: _submitting ? null : _acceptAssignment,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Accept Assignment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : assignment.isAccepted
                        ? Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _submitting ? null : _showCancelDialog,
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                ),
                                label: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: const BorderSide(
                                    color: AppColors.borderStrong,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _submitting ? null : _showCompleteDialog,
                                  icon: const Icon(Icons.task_alt_rounded),
                                  label: const Text('Mark Completed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : assignment.canComplete
                            ? ElevatedButton.icon(
                                onPressed:
                                    _submitting ? null : _showCompleteDialog,
                                icon: const Icon(Icons.task_alt_rounded),
                                label: const Text('Mark as Completed'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                            : Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      assignment.isCancelled
                                          ? Icons.info_outline_rounded
                                          : Icons.verified_rounded,
                                      size: 18,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      assignment.statusLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignment,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignment.typeLabel,
                                style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                              const SizedBox(height: 2),
                              Text(
                                scheduledDate != null
                                    ? DateFormat('EEEE, dd MMMM yyyy')
                                        .format(scheduledDate)
                                    : assignment.scheduledDate,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (assignment.isCancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              '0 pts',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else if (assignment.pointsAwarded > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                            ),
                            child: Text(
                              assignment.pointsLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            assignment.statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (assignment.isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (assignment.isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (assignment.isCancelled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFloating,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              VolunteerRequestMessages.getPositiveMessage(
                                taskType: assignment.taskType,
                                status: assignment.status,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.text,
                                height: 1.4,
                              ),
                            ),
                            if (assignment.cancelReason != null &&
                                assignment.cancelReason!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: ${assignment.cancelReason!}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Patient Card
              _sectionCard(
                title: 'Patient Details',
                icon: Icons.person_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.patient.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (assignment.patient.age != null ||
                        assignment.patient.gender != null)
                      Text(
                        [
                          if (assignment.patient.age != null)
                            '${assignment.patient.age} Yrs',
                          if (assignment.patient.gender != null)
                            assignment.patient.gender!,
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const Divider(height: 24, color: AppColors.border),
                    InkWell(
                      onTap: () => _openMap(
                        assignment.patient.address,
                        assignment.patient.locationLink,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              assignment.patient.address.isNotEmpty
                                  ? assignment.patient.address
                                  : 'Address not available',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    if (assignment.patient.phone != null &&
                        assignment.patient.phone!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _callPhone(assignment.patient.phone!),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 18,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              assignment.patient.phone!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.call_made_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Task Details Card
              _sectionCard(
                title: 'Task Details',
                icon: Icons.notes_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (assignment.taskDetails.team != null &&
                        assignment.taskDetails.team!.isNotEmpty) ...[
                      _detailRow(
                        'Care Team',
                        assignment.taskDetails.team!,
                        Icons.groups_outlined,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (assignment.taskDetails.nurseName != null &&
                        assignment.taskDetails.nurseName!.isNotEmpty) ...[
                      _detailRow(
                        'Assigned Nurse',
                        assignment.taskDetails.nurseName!,
                        Icons.badge_outlined,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (assignment.taskDetails.supportTypes.isNotEmpty) ...[
                      const Text(
                        'Support Types',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: assignment.taskDetails.supportTypes.map((type) {
                          return Chip(
                            label: Text(type.replaceAll('_', ' ')),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (assignment.taskDetails.notes != null &&
                        assignment.taskDetails.notes!.isNotEmpty) ...[
                      const Text(
                        'Instructions / Notes',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          assignment.taskDetails.notes!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                    if (assignment.notes != null &&
                        assignment.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Volunteer Note',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          assignment.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Co-volunteers Card
              if (assignment.coVolunteers.isNotEmpty)
                _sectionCard(
                  title: 'Co-Volunteers (${assignment.coVolunteers.length})',
                  icon: Icons.people_outline_rounded,
                  child: Column(
                    children: assignment.coVolunteers.map((v) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            v.name.isNotEmpty ? v.name[0].toUpperCase() : 'V',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          v.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (v.phone.isNotEmpty) v.phone,
                            if (v.place != null && v.place!.isNotEmpty) v.place!,
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: v.phone.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.call_outlined, color: AppColors.primary),
                                onPressed: () => _callPhone(v.phone),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceFloating,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
