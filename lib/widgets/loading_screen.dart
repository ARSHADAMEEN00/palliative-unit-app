import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/unit_brand_avatar.dart';
import 'package:provider/provider.dart';

class LoadingScreen extends StatefulWidget {
  final Duration duration;
  final Widget? nextScreen;

  const LoadingScreen({
    super.key,
    this.duration = const Duration(seconds: 2),
    this.nextScreen,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    Future.delayed(widget.duration, () {
      if (!mounted) return;
      if (widget.nextScreen != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen!),
        );
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = _maybeAuth(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppInsets.page,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.72, end: 1).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: AppMotion.easeInOut,
                      ),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: AppMotion.easeInOut,
                        ),
                      ),
                      child: Container(
                        width: 108,
                        height: 108,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.dialog,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.border),
                          ),
                          boxShadow: AppShadow.medium,
                        ),
                        child: const UnitBrandAvatar(
                          size: 76,
                          preferAppIcon: true,
                          backgroundColor: AppColors.primaryLight,
                          iconColor: AppColors.primary,
                          fallbackIcon: Icons.local_hospital_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    auth?.unitName ?? 'Palliative App',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Preparing your care workspace',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ClipRRect(
                    borderRadius: AppRadius.sm,
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Syncing permissions and today\'s modules',
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AuthService? _maybeAuth(BuildContext context) {
    try {
      return context.watch<AuthService>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
