import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/unit_brand_avatar.dart';
import 'package:provider/provider.dart';

class TrialEndedScreen extends StatelessWidget {
  const TrialEndedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final support = auth.accessBlockedSupport ?? const {};
    final supportName = _clean(support['name']);
    final supportPhone = _clean(support['phone']);
    final supportEmail = _clean(support['email']);
    final supportItems = [
      if (supportName != null)
        _SupportLine(icon: Icons.person_outline_rounded, text: supportName),
      if (supportPhone != null)
        _SupportLine(icon: Icons.phone_outlined, text: supportPhone),
      if (supportEmail != null)
        _SupportLine(icon: Icons.mail_outline_rounded, text: supportEmail),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppInsets.page,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const UnitBrandAvatar(
                    size: 72,
                    preferAppIcon: true,
                    backgroundColor: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    fallbackIcon: Icons.local_hospital_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    surfaceLevel: AppSurfaceLevel.modal,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppSemanticColors.background(
                              AppSemanticStatus.warning,
                            ),
                            borderRadius: AppRadius.card,
                            border: Border.all(
                              color: AppSemanticColors.border(
                                AppSemanticStatus.warning,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_clock_rounded,
                            color: AppColors.warning,
                            size: AppIcons.feature,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Access needs renewal',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          auth.accessBlockedMessage ??
                              'Your trial period has ended. Please contact support to renew your plan and continue using Palliative App.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                        if (supportItems.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: const BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: AppRadius.md,
                              border: Border.fromBorderSide(
                                BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Support team',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                ...supportItems,
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppPrimaryButton(
                          label: 'Check access again',
                          icon: Icons.refresh_rounded,
                          fullWidth: true,
                          onPressed: () =>
                              context.read<AuthService>().fetchUserProfile(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                context.read<AuthService>().logout(),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Your data remains safe. Access will resume after renewal.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _SupportLine extends StatelessWidget {
  const _SupportLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: AppIcons.normal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
