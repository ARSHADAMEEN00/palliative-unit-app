import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/email_verification_page.dart';
import 'package:oruma_app/services/public_user_service.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

class PublicUserRegistrationPage extends StatefulWidget {
  const PublicUserRegistrationPage({super.key});

  @override
  State<PublicUserRegistrationPage> createState() =>
      _PublicUserRegistrationPageState();
}

class _PublicUserRegistrationPageState
    extends State<PublicUserRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  List<PublicUnit> _units = const [];
  String? _unitId;
  String? _error;
  bool _loadingUnits = true;
  bool _submitting = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await VolunteerApplicationService.getUnits();
      if (!mounted) return;
      setState(() {
        _units = units;
        _unitId = units.length == 1 ? units.first.id : null;
        _loadingUnits = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingUnits = false;
          _error = _friendly(error);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await PublicUserService.register(
        unitId: _unitId!,
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(
            email: result.email,
            expiresInMinutes: result.expiresInMinutes,
            initialResendAfterSeconds: result.resendAfterSeconds,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendly(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create user account'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: AppCard(
                surfaceLevel: AppSurfaceLevel.elevated,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Connect with a care unit',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'See the unit’s story and send a patient registration enquiry.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (_loadingUnits)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _unitId,
                          isExpanded: true,
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
                                        ? unit.name
                                        : '${unit.name} • ${unit.locationLabel}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _unitId = value),
                          validator: (value) =>
                              value == null ? 'Select a unit' : null,
                        ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => value?.trim().isEmpty ?? true
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) =>
                            RegExp(
                              r'^\S+@\S+\.\S+$',
                            ).hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter a valid email',
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
                        label: 'Create account',
                        icon: Icons.arrow_forward_rounded,
                        fullWidth: true,
                        loading: _submitting,
                        onPressed: _submitting || _loadingUnits
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Email verification is required before you can submit an enquiry.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(color: AppColors.textSecondary),
                              children: [
                                TextSpan(
                                  text: 'Sign in',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    bool confirm = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !_showPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _showPassword = !_showPassword),
          icon: Icon(
            _showPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: (value) {
        if ((value ?? '').length < 8) return 'Use at least 8 characters';
        if (confirm && value != _password.text) return 'Passwords do not match';
        return null;
      },
    );
  }
}
