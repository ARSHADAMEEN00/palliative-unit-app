import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:oruma_app/privacy_policy_screen.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/loading_screen.dart';
import 'package:provider/provider.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email and password to continue.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final success = await authService.login(email, password);

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (success && mounted) {
      if (authService.isFirstLogin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoadingScreen(nextScreen: Homescreen()),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Homescreen()),
        );
      }
    } else if (!success && mounted) {
      if (authService.isAccessBlocked) return;
      setState(() {
        _errorMessage =
            authService.loginErrorMessage ?? 'Invalid email or password.';
      });
    }
  }

  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.tablet;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/logo/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? AppSpacing.xl : AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _LoginCard(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    isPasswordVisible: _isPasswordVisible,
                    onSubmit: _handleLogin,
                    onTogglePassword: _togglePasswordVisibility,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.isPasswordVisible,
    required this.onSubmit,
    required this.onTogglePassword,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
  final bool isPasswordVisible;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      surfaceLevel: AppSurfaceLevel.elevated,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in',
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Continue to your care dashboard.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Email address',
                hintText: 'name@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: !isPasswordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !isLoading,
              onSubmitted: (_) {
                if (!isLoading) onSubmit();
              },
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: isPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
                  onPressed: isLoading ? null : onTogglePassword,
                  icon: Icon(
                    isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Sign in securely',
              icon: Icons.arrow_forward_rounded,
              fullWidth: true,
              loading: isLoading,
              onPressed: isLoading ? null : onSubmit,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SupportStrip(),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.privacy_tip_outlined, size: 18),
              label: const Text('Privacy & data use'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppSemanticColors.background(AppSemanticStatus.danger),
        borderRadius: AppRadius.md,
        border: Border.all(
          color: AppSemanticColors.border(AppSemanticStatus.danger),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: AppIcons.normal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportStrip extends StatelessWidget {
  const _SupportStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.support_agent_rounded,
            size: AppIcons.normal,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Need access? Contact your unit administrator.',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
