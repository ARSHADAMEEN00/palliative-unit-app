import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.expiresInMinutes = 10,
    this.initialResendAfterSeconds = 60,
  });

  final String email;
  final int expiresInMinutes;
  final int initialResendAfterSeconds;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _resendTimer;
  late int _resendSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resendSeconds = widget.initialResendAfterSeconds;
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    if (_resendSeconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await VolunteerApplicationService.verifyEmail(
        email: widget.email,
        otp: _otpController.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email address verified successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final resendAfterSeconds =
          await VolunteerApplicationService.resendEmailVerification(
            email: widget.email,
          );
      if (!mounted) return;
      _otpController.clear();
      setState(() => _resendSeconds = resendAfterSeconds);
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been sent.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete your verification'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppInsets.screen(
            context,
            top: AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppCard(
                surfaceLevel: AppSurfaceLevel.elevated,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mark_email_read_outlined,
                              color: AppColors.primary,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Check your email',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'We sent a 6-digit verification code to',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        SelectableText(
                          widget.email,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _otpController,
                          autofocus: true,
                          enabled: !_verifying,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 10,
                              ),
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            hintText: '000000',
                            prefixIcon: Icon(Icons.password_rounded),
                          ),
                          onFieldSubmitted: (_) => _verify(),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter the 6-digit code',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'The code expires in ${widget.expiresInMinutes} minutes.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
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
                        AppPrimaryButton(
                          label: 'Verify email',
                          icon: Icons.verified_rounded,
                          fullWidth: true,
                          loading: _verifying,
                          onPressed: _verifying ? null : _verify,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton.icon(
                            onPressed:
                                _resendSeconds == 0 &&
                                    !_resending &&
                                    !_verifying
                                ? _resend
                                : null,
                            icon: _resending
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: Text(
                              _resendSeconds > 0
                                  ? 'Resend code in ${_resendSeconds}s'
                                  : 'Resend verification code',
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
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
