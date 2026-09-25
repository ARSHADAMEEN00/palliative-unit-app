import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_icons.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isCompact = height != null && height! <= 44;
    final child = _ButtonContent(
      label: label,
      icon: icon,
      loading: loading,
      isCompact: isCompact,
    );
    final button = FilledButton(
      style: height != null
          ? FilledButton.styleFrom(
              minimumSize: Size(0, height!),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
              ),
            )
          : null,
      onPressed: loading ? null : onPressed,
      child: child,
    );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isCompact = height != null && height! <= 44;
    final child = _ButtonContent(
      label: label,
      icon: icon,
      loading: loading,
      isCompact: isCompact,
    );
    final button = OutlinedButton(
      style: height != null
          ? OutlinedButton.styleFrom(
              minimumSize: Size(0, height!),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
              ),
            )
          : null,
      onPressed: loading ? null : onPressed,
      child: child,
    );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppDangerButton extends StatelessWidget {
  const AppDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isCompact = height != null && height! <= 44;
    final child = _ButtonContent(
      label: label,
      icon: icon,
      loading: loading,
      isCompact: isCompact,
    );
    final button = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
        minimumSize: height != null ? Size(0, height!) : null,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
        ),
      ),
      onPressed: loading ? null : onPressed,
      child: child,
    );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.loading,
    this.isCompact = false,
  });

  final String label;
  final IconData? icon;
  final bool loading;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox.square(
        dimension: isCompact ? 16 : AppIcons.normal,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final textStyle = isCompact
        ? const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)
        : null;

    if (icon == null) {
      return Text(
        label,
        style: textStyle,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: isCompact ? 16 : AppIcons.normal),
        SizedBox(width: isCompact ? 6 : AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
