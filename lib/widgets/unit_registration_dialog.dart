import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:provider/provider.dart';

class UnitRegistrationDialog extends StatefulWidget {
  const UnitRegistrationDialog({super.key});

  @override
  State<UnitRegistrationDialog> createState() => _UnitRegistrationDialogState();
}

class _UnitRegistrationDialogState extends State<UnitRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _unitNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();
  final _villageController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _unitNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _villageController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.submitUnitRegistrationEnquiry(
      unitName: _unitNameController.text.trim(),
      contactPerson: _contactPersonController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      district: _districtController.text.trim(),
      village: _villageController.text.trim(),
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result['error']?.toString() ?? 'Failed to submit enquiry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 480;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSpacing.md : AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppCard(
          surfaceLevel: AppSurfaceLevel.elevated,
          padding: EdgeInsets.all(isCompact ? AppSpacing.lg : AppSpacing.xl),
          child: _isSubmitted ? _buildSuccessView(context) : _buildFormView(context),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF86EFAC), width: 2),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 44,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Enquiry Submitted!',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Thank you, ${_contactPersonController.text.trim()}! We have received your registration enquiry for "${_unitNameController.text.trim()}".',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Our platform administration will review your enquiry in the superadmin dashboard. Once approved, you will receive your unit activation details at ${_emailController.text.trim()}.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: 'Back to Sign In',
          icon: Icons.login_rounded,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildFormView(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.domain_add_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register Unit Enquiry',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enquire to set up a new palliative care unit.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: AppRadius.md,
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Submitting this enquiry does not activate a unit directly. A superadmin will verify and approve your registration.',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _unitNameController,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Unit / Organization Name *',
                hintText: 'e.g. Karuna Palliative Care Society',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter the unit name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contactPersonController,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Contact Person / Admin Name *',
                hintText: 'e.g. Dr. John Doe',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter contact person name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email *',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter contact email';
                      }
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(val.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: '+91 9876543210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter phone number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _districtController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'District',
                      hintText: 'e.g. Kozhikode',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _villageController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Village / Town',
                      hintText: 'e.g. Feroke',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _addressController,
              enabled: !_isSubmitting,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address (Optional)',
                hintText: 'Full physical address or landmark',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notesController,
              enabled: !_isSubmitting,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes / Questions (Optional)',
                hintText: 'Any requirements, estimated patients, or notes',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Cancel',
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: AppPrimaryButton(
                    label: 'Submit Enquiry',
                    icon: Icons.send_rounded,
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _handleSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
