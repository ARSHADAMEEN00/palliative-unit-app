import 'package:flutter/widgets.dart';

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
  static const double huge = 64;
}

class AppInsets {
  AppInsets._();

  static const none = EdgeInsets.zero;
  static const xxs = EdgeInsets.all(AppSpacing.xxs);
  static const xs = EdgeInsets.all(AppSpacing.xs);
  static const sm = EdgeInsets.all(AppSpacing.sm);
  static const md = EdgeInsets.all(AppSpacing.md);
  static const lg = EdgeInsets.all(AppSpacing.lg);
  static const xl = EdgeInsets.all(AppSpacing.xl);

  static const page = EdgeInsets.all(AppSpacing.md);
  static const pageWide = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.lg,
  );
  static const card = EdgeInsets.all(AppSpacing.md);
  static const cardLarge = EdgeInsets.all(AppSpacing.lg);
  static const input = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: 15,
  );
  static const button = EdgeInsets.symmetric(horizontal: AppSpacing.md);

  static double screenHorizontal(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600
        ? AppSpacing.md
        : AppSpacing.lg;
  }

  static EdgeInsets screen(
    BuildContext context, {
    double top = AppSpacing.sm,
    double bottom = AppSpacing.xl,
  }) {
    final h = screenHorizontal(context);
    return EdgeInsets.fromLTRB(h, top, h, bottom);
  }
}
