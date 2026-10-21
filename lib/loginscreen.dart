import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:oruma_app/privacy_policy_screen.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/loading_screen.dart';
import 'package:oruma_app/widgets/unit_registration_dialog.dart';
import 'package:oruma_app/volunteer_registration_page.dart';
import 'package:oruma_app/public_user_registration_page.dart';
import 'package:oruma_app/forgot_password_page.dart';
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
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email or username and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final success = await authService.login(identifier, password);

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
            authService.loginErrorMessage ??
            'Invalid email, username, or password.';
      });
    }
  }

  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F8FF), Color(0xFFF6FBF8), Color(0xFFFAF7FC)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -120,
              right: -80,
              child: _AmbientOrb(size: 300, color: Color(0x332563EB)),
            ),
            const Positioned(
              bottom: -140,
              left: -90,
              child: _AmbientOrb(size: 320, color: Color(0x3320B486)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 40 : AppSpacing.md,
                    vertical: isWide ? 32 : AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(child: _WelcomePanel()),
                              const SizedBox(width: AppSpacing.xl),
                              SizedBox(
                                width: 420,
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
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _BrandLockup(),
                              const SizedBox(height: AppSpacing.lg),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
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
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome back',
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign in to your care workspace, volunteer portal, or user account.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Email or username',
                hintText: 'name@example.com or username',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: passwordController,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
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
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppPrimaryButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              fullWidth: true,
              loading: isLoading,
              onPressed: isLoading ? null : onSubmit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'NEW TO PALLIATIVE APP?',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _RegistrationAction(
              icon: Icons.people_alt_outlined,
              title: 'User',
              subtitle: 'View our story and send a patient enquiry',
              onTap: isLoading
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PublicUserRegistrationPage(),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _RegistrationAction(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Volunteer',
                    subtitle: 'Join a care unit',
                    onTap: isLoading
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VolunteerRegistrationPage(),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RegistrationAction(
                    icon: Icons.domain_add_outlined,
                    title: 'New unit',
                    subtitle: 'Register a centre',
                    onTap: isLoading
                        ? null
                        : () => showDialog(
                            context: context,
                            builder: (_) => const UnitRegistrationDialog(),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                label: const Text(
                  'Privacy & data use',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: AppRadius.md,
          child: Image.asset(
            'assets/logo/app_icon.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Palliative App',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Compassion. Comfort. Dignity.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 650,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/logo/app_icon.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2209182B),
                    Color(0x3309182B),
                    Color(0xE60B1F38),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/logo/app_icon.png',
                            width: 18,
                            height: 18,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Text(
                          'PALLIATIVE APP',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Care that stays\nconnected.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'One secure workspace for care teams, volunteers, patients and daily support.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _WelcomePill(
                        icon: Icons.shield_outlined,
                        label: 'Secure',
                      ),
                      _WelcomePill(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Role based',
                      ),
                      _WelcomePill(
                        icon: Icons.hub_outlined,
                        label: 'Unit connected',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePill extends StatelessWidget {
  const _WelcomePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationAction extends StatelessWidget {
  const _RegistrationAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
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
            size: 18,
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

