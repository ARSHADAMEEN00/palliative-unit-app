import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';

class AppMenuActionLabel extends StatelessWidget {
  const AppMenuActionLabel({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.color,
  }) : assert(icon != null || leading != null, 'Either icon or leading must be provided');

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          leading!
        else if (icon != null)
          Icon(icon, size: 18, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
