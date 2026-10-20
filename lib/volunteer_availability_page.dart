import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/services/volunteer_availability_request_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:provider/provider.dart';

class VolunteerAvailabilityPage extends StatefulWidget {
  const VolunteerAvailabilityPage({super.key});

  @override
  State<VolunteerAvailabilityPage> createState() =>
      _VolunteerAvailabilityPageState();
}

class _VolunteerAvailabilityPageState extends State<VolunteerAvailabilityPage> {
  bool _loading = true;
  String? _error;
  List<int> _workingDays = const [];
  String _availabilityTime = '09:30 AM to 03:30 PM';
  List<VolunteerAvailabilityRequest> _requests = const [];
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ConfigService.getConfig(forceRefresh: true),
        VolunteerAvailabilityRequestService.getRequests(),
      ]);
      if (!mounted) return;
      final config = results[0] as Config;
      final requests = results[1] as List<VolunteerAvailabilityRequest>;
      setState(() {
        _workingDays = [...config.workingDays]..sort();
        _availabilityTime = config.volunteerAvailabilityTimeWindow;
        _requests = requests;
        _selectedDate = _firstAvailableDate(config.workingDays);
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

  DateTime? _firstAvailableDate(List<int> days) {
    if (days.isEmpty) return null;
    for (var offset = 0; offset <= 180; offset++) {
      final date = _today.add(Duration(days: offset));
      if (days.contains(date.weekday) && !_alreadyRequested(date)) return date;
    }
    return null;
  }

  bool _isAvailableDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(_today) && _workingDays.contains(date.weekday);
  }

  bool _alreadyRequested(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _requests.any(
      (request) =>
          request.requestedDate == key &&
          (request.status == 'pending' || request.status == 'approved'),
    );
  }

  String _weekdayLabel(int weekday) => const {
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  }[weekday]!;

  Future<void> _selectDate(DateTime date) async {
    setState(() => _selectedDate = date);
    if (_alreadyRequested(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a request for this date.'),
        ),
      );
      return;
    }
    await _showConfirmation(date);
  }

  Future<void> _showConfirmation(DateTime date) async {
    final latest = _requests.isEmpty ? null : _requests.first;
    final authName =
        context.read<AuthService>().user?['name']?.toString() ?? '';
    final nameController = TextEditingController(
      text: latest?.contactName.trim().isNotEmpty == true
          ? latest!.contactName
          : authName,
    );
    final phoneController = TextEditingController(
      text: latest?.phone ?? latest?.volunteer?.phone ?? '',
    );
    final addressController = TextEditingController(
      text: latest?.address.trim().isNotEmpty == true
          ? latest!.address
          : latest?.volunteer?.address ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          title: const Row(
            children: [
              Icon(Icons.event_available_rounded, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Confirm availability')),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(date),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Time: $_availabilityTime',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Mobile number is required';
                      }
                      if (value.replaceAll(RegExp(r'\D'), '').length < 10) {
                        return 'Enter a valid mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: addressController,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The admin will use these details to contact you. This does not assign you to a home visit.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setDialogState(() => submitting = true);
                      try {
                        final request =
                            await VolunteerAvailabilityRequestService.submit(
                              requestedDate: DateFormat(
                                'yyyy-MM-dd',
                              ).format(date),
                              contactName: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              address: addressController.text.trim(),
                              timeSlot: _availabilityTime,
                            );
                        if (!dialogContext.mounted) return;
                        setState(() {
                          _requests = [request, ..._requests];
                          _selectedDate = _firstAvailableDate(_workingDays);
                        });
                        Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => submitting = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(_friendlyError(error)),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability request sent to the admin.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required'
        : null;
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Availability'),
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const AppListSkeleton(itemCount: 4)
          : _error != null
          ? AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load availability',
              message: _error!,
              action: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: AppInsets.screen(
                  context,
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xxl,
                ),
                children: [
                  Text(
                    'Choose a day you can volunteer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Only the working days selected by your unit are available.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_workingDays.isEmpty)
                    const AppEmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No working days configured',
                      message:
                          'Ask your unit admin to select working days first.',
                    )
                  else ...[
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ..._workingDays.map(
                                (day) => Chip(
                                  avatar: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  label: Text(_weekdayLabel(day)),
                                  side: BorderSide.none,
                                  backgroundColor: AppColors.success
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                label: Text(_availabilityTime),
                                side: BorderSide.none,
                                backgroundColor: AppColors.primaryLight,
                              ),
                            ],
                          ),
                          const Divider(height: AppSpacing.lg),
                          CalendarDatePicker(
                            initialDate: _selectedDate,
                            firstDate: _today,
                            lastDate: _today.add(const Duration(days: 180)),
                            selectableDayPredicate: (date) =>
                                _isAvailableDate(date) &&
                                !_alreadyRequested(date),
                            onDateChanged: _selectDate,
                          ),
                          if (_selectedDate != null) ...[
                            const Divider(height: AppSpacing.lg),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: AppRadius.sm,
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.event_available_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE, d MMMM yyyy')
                                              .format(_selectedDate!),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppColors.primary,
                                          ),
                                        ),
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
                                              'Time: $_availabilityTime',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _selectDate(_selectedDate!),
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'My requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_requests.isEmpty)
                    const AppEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'No availability requests yet',
                      message: 'Select an enabled date above to send one.',
                    )
                  else
                    ..._requests.map(_buildRequestCard),
                ],
              ),
            ),
    );
  }

  Widget _buildRequestCard(VolunteerAvailabilityRequest request) {
    final approved = request.status == 'approved';
    final declined = request.status == 'declined';
    final color = approved
        ? AppColors.success
        : declined
        ? AppColors.danger
        : AppColors.warning;
    final date = DateTime.tryParse(request.requestedDate);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              approved
                  ? Icons.check_rounded
                  : declined
                  ? Icons.close_rounded
                  : Icons.schedule_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? request.requestedDate
                      : DateFormat('EEEE, d MMM yyyy').format(date),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (request.timeSlot != null &&
                    request.timeSlot!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.timeSlot!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  request.status[0].toUpperCase() + request.status.substring(1),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (request.decisionNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    request.decisionNote!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
