import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/loginscreen.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

class VolunteerRemovedUnitRequestCard extends StatefulWidget {
  const VolunteerRemovedUnitRequestCard({
    super.key,
    required this.onSubmitted,
  });

  final Future<void> Function() onSubmitted;

  @override
  State<VolunteerRemovedUnitRequestCard> createState() =>
      _VolunteerRemovedUnitRequestCardState();
}

class _VolunteerRemovedUnitRequestCardState
    extends State<VolunteerRemovedUnitRequestCard> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _phoneController;
  late final TextEditingController _phone2Controller;
  late final TextEditingController _villageController;
  late final TextEditingController _wardController;
  late final TextEditingController _placeController;
  late final TextEditingController _addressController;

  List<PublicUnit> _units = const [];
  String? _selectedUnitId;
  bool _loadingUnits = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _phoneController = TextEditingController(text: auth.userPhone ?? '');
    _phone2Controller = TextEditingController(text: auth.userPhone2 ?? '');
    _villageController = TextEditingController(text: auth.userVillage ?? '');
    _wardController = TextEditingController(text: auth.userWard ?? '');
    _placeController = TextEditingController(text: auth.userPlace ?? '');
    _addressController = TextEditingController(text: auth.userAddress ?? '');
    _loadUnits();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phone2Controller.dispose();
    _villageController.dispose();
    _wardController.dispose();
    _placeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await VolunteerApplicationService.getUnits();
      if (!mounted) return;
      setState(() {
        _units = units;
        _selectedUnitId = units.length == 1 ? units.first.id : null;
        _loadingUnits = false;
        _error = units.isEmpty
            ? 'No palliative care units are currently accepting applications.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUnits = false;
        _error = 'Failed to load palliative care units. Please pull down to refresh.';
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedUnitId == null || _selectedUnitId!.isEmpty) {
      setState(() => _error = 'Please select a unit to request membership.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await VolunteerApplicationService.requestUnit(
        unitId: _selectedUnitId!,
        phone: _phoneController.text,
        phone2: _phone2Controller.text,
        village: _villageController.text,
        ward: _wardController.text,
        place: _placeController.text,
        address: _addressController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted to unit! Awaiting approval.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = raw;
        _submitting = false;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthService>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: AppCard(
          surfaceLevel: AppSurfaceLevel.elevated,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top status badge
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_remove_rounded,
                      color: AppColors.warning,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Main headline
                Text(
                  'You are removed from the unit',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Explanatory message
                Text(
                  'You have been removed from your previous palliative care unit. '
                  'Please select a unit from the dropdown below to create a new volunteer request.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Error alert banner if any
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: AppRadius.md,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Unit selection dropdown section
                Text(
                  'Select Palliative Care Unit',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _loadingUnits
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.md,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Text('Loading available care units...'),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedUnitId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Choose a care unit',
                          prefixIcon: const Icon(
                            Icons.apartment_rounded,
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.md,
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.md,
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.md,
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: _units.map((unit) {
                          final loc = unit.locationLabel;
                          return DropdownMenuItem<String>(
                            value: unit.id,
                            child: Text(
                              loc.isNotEmpty ? '${unit.name} ($loc)' : unit.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _submitting
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedUnitId = val;
                                  _error = null;
                                });
                              },
                        validator: (val) => val == null || val.isEmpty
                            ? 'Please select a unit'
                            : null,
                      ),
                const SizedBox(height: AppSpacing.lg),

                // Contact & Location fields
                Text(
                  'Your Details',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: const Icon(Icons.call_outlined),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Phone number is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _villageController,
                        decoration: InputDecoration(
                          labelText: 'Village *',
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.md,
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Village is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _wardController,
                        decoration: InputDecoration(
                          labelText: 'Ward *',
                          prefixIcon: const Icon(Icons.map_outlined),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.md,
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Ward is required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    labelText: 'Place *',
                    prefixIcon: const Icon(Icons.place_outlined),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Place is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Address (optional)',
                    prefixIcon: const Icon(Icons.home_outlined),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Submit button
                AppPrimaryButton(
                  label: 'Submit Request to Unit',
                  icon: Icons.send_rounded,
                  fullWidth: true,
                  loading: _submitting,
                  onPressed: _submitting || _loadingUnits ? null : _submitRequest,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bottom actions (Logout)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        auth.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const Loginscreen(),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
