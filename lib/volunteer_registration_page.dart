import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

class VolunteerRegistrationPage extends StatefulWidget {
  const VolunteerRegistrationPage({super.key});

  @override
  State<VolunteerRegistrationPage> createState() =>
      _VolunteerRegistrationPageState();
}

class _VolunteerRegistrationPageState extends State<VolunteerRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _phone = TextEditingController();
  final _phone2 = TextEditingController();
  final _village = TextEditingController();
  final _ward = TextEditingController();
  final _place = TextEditingController();
  final _address = TextEditingController();

  List<PublicUnit> _units = const [];
  String? _selectedUnitId;
  bool _loadingUnits = true;
  bool _submitting = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirmPassword,
      _phone,
      _phone2,
      _village,
      _ward,
      _place,
      _address,
    ]) {
      controller.dispose();
    }
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
            ? 'No palliative care units are accepting applications.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingUnits = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedUnitId == null) {
      setState(() => _error = 'Select the unit you want to volunteer with.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await VolunteerApplicationService.submit(
        unitId: _selectedUnitId!,
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        phone2: _phone2.text,
        village: _village.text,
        ward: _ward.text,
        place: _place.text,
        address: _address.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 48,
          ),
          title: const Text('Application submitted'),
          content: const Text(
            'You can sign in now. Your home screen will show the application status until the unit approves your registration.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue to sign in'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register as Volunteer'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppInsets.screen(
            context,
            top: AppSpacing.md,
            bottom: AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: AppCard(
                surfaceLevel: AppSurfaceLevel.elevated,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: AppRadius.md,
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Join a care unit',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  'Create your account and send an application to the unit.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: AppRadius.sm,
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (_loadingUnits)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUnitId,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          iconEnabledColor: AppColors.textSecondary,
                          style: AppTypography.dropdownTextStyle(context),
                          decoration: const InputDecoration(
                            labelText: 'Palliative care unit',
                            prefixIcon: Icon(Icons.apartment_rounded),
                          ),
                          items: _units
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit.id,
                                  child: Text(
                                    unit.locationLabel.isEmpty
                                        ? '${unit.name} (${unit.code})'
                                        : '${unit.name} • ${unit.locationLabel}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (value) =>
                                    setState(() => _selectedUnitId = value),
                          validator: (_) => _selectedUnitId == null
                              ? 'Please select a unit'
                              : null,
                        ),
                      const SizedBox(height: AppSpacing.md),
                      _field(_name, 'Full name', Icons.person_outline_rounded),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        _email,
                        'Email address',
                        Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final required = _required(value, 'Email');
                          if (required != null) return required;
                          if (!RegExp(
                            r'^\S+@\S+\.\S+$',
                          ).hasMatch(value!.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        _phone,
                        'Phone number',
                        Icons.call_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ ()-]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        _phone2,
                        'Second phone (optional)',
                        Icons.phone_iphone_outlined,
                        required: false,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(
                              _village,
                              'Village',
                              Icons.location_city_outlined,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _field(_ward, 'Ward', Icons.map_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(_place, 'Place', Icons.place_outlined),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        _address,
                        'Address (optional)',
                        Icons.home_outlined,
                        required: false,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _passwordField(_password, 'Password'),
                      const SizedBox(height: AppSpacing.md),
                      _passwordField(
                        _confirmPassword,
                        'Confirm password',
                        confirm: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        label: 'Submit volunteer application',
                        icon: Icons.send_rounded,
                        fullWidth: true,
                        loading: _submitting,
                        onPressed: _submitting || _loadingUnits
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your account remains limited to the approval-status screen until this unit accepts your application.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textCapitalization: keyboardType == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ?? (required ? (value) => _required(value, label) : null),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    bool confirm = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      obscureText: !_passwordVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.length < 8) {
          return 'Use at least 8 characters';
        }
        if (confirm && value != _password.text) return 'Passwords do not match';
        return null;
      },
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
