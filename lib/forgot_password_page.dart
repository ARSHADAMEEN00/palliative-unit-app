import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/public_user_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _step = 0;
  bool _loading = false;
  bool _showPassword = false;
  String? _resetToken;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_step == 0) {
        await PublicUserService.requestPasswordReset(_email.text);
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        final token = await PublicUserService.verifyPasswordReset(
          email: _email.text,
          otp: _otp.text,
        );
        if (mounted) {
          setState(() {
            _resetToken = token;
            _step = 2;
          });
        }
      } else {
        await PublicUserService.completePasswordReset(
          resetToken: _resetToken!,
          newPassword: _password.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated. You can now sign in.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Find your account',
      'Verify your email',
      'Choose a new password',
    ];
    final descriptions = [
      'Enter the email used for your account.',
      'Enter the 6-digit code sent to ${_email.text.trim()}.',
      'Your email is verified. Set a new password to continue.',
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Forgot password'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.md,
                        ),
                        child: Icon(
                          _step == 0
                              ? Icons.mail_outline_rounded
                              : _step == 1
                              ? Icons.verified_user_outlined
                              : Icons.lock_reset_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        titles[_step],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        descriptions[_step],
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
                      if (_step == 0)
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofocus: true,
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
                        )
                      else if (_step == 1) ...[
                        TextFormField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            hintText: '000000',
                            prefixIcon: Icon(Icons.password_rounded),
                          ),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter the 6-digit code',
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () async {
                                    setState(() {
                                      _loading = true;
                                      _error = null;
                                    });
                                    try {
                                      await PublicUserService.requestPasswordReset(
                                        _email.text,
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'A new code has been sent.',
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      if (mounted) {
                                        setState(
                                          () => _error = error
                                              .toString()
                                              .replaceFirst('Exception: ', ''),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _loading = false);
                                      }
                                    }
                                  },
                            child: const Text('Resend code'),
                          ),
                        ),
                      ] else ...[
                        _passwordField(_password, 'New password'),
                        const SizedBox(height: AppSpacing.md),
                        _passwordField(
                          _confirmPassword,
                          'Confirm new password',
                          confirm: true,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        label: _step == 0
                            ? 'Send verification code'
                            : _step == 1
                            ? 'Verify email'
                            : 'Update password',
                        icon: Icons.arrow_forward_rounded,
                        fullWidth: true,
                        loading: _loading,
                        onPressed: _loading ? null : _continue,
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
