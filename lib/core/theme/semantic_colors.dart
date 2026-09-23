import 'package:flutter/material.dart';

import 'app_colors.dart';

enum AppSemanticStatus {
  info,
  success,
  warning,
  danger,
  pending,
  scheduled,
  completed,
  cancelled,
  overdue,
  offline,
  online,
}

class AppSemanticColors {
  AppSemanticColors._();

  static Color foreground(AppSemanticStatus status) {
    return switch (status) {
      AppSemanticStatus.info => AppColors.info,
      AppSemanticStatus.success => AppColors.success,
      AppSemanticStatus.warning => AppColors.warning,
      AppSemanticStatus.danger => AppColors.danger,
      AppSemanticStatus.pending => AppColors.pending,
      AppSemanticStatus.scheduled => AppColors.scheduled,
      AppSemanticStatus.completed => AppColors.completed,
      AppSemanticStatus.cancelled => AppColors.cancelled,
      AppSemanticStatus.overdue => AppColors.overdue,
      AppSemanticStatus.offline => AppColors.offline,
      AppSemanticStatus.online => AppColors.online,
    };
  }

  static Color background(AppSemanticStatus status) {
    return foreground(status).withValues(alpha: 0.1);
  }

  static Color border(AppSemanticStatus status) {
    return foreground(status).withValues(alpha: 0.18);
  }
}
