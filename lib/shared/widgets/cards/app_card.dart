import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_motion.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_shadow.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppInsets.card,
    this.margin = EdgeInsets.zero,
    this.surfaceLevel = AppSurfaceLevel.elevated,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final AppSurfaceLevel surfaceLevel;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = surfaceLevel == AppSurfaceLevel.modal
        ? AppRadius.dialog
        : AppRadius.card;

    final card = AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.easeOutCubic,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(surfaceLevel, dark: dark),
        borderRadius: radius,
        border: Border.all(
          color:
              borderColor ?? (dark ? AppColors.darkBorder : AppColors.border),
        ),
        boxShadow: AppShadow.forSurface(surfaceLevel),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: card),
    );
  }
}
