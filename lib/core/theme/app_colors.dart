import 'package:flutter/material.dart';

enum AppSurfaceLevel { surface, surface1, surface2, elevated, floating, modal }

class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFDBEAFE);
  static const primarySoft = Color(0xFFF2F6FF);

  static const background = Color(0xFFFAFAFB);
  static const surface = Color(0xFFFFFFFF);
  static const surface1 = Color(0xFFF8FAFC);
  static const surface2 = Color(0xFFF1F5F9);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceFloating = Color(0xF7FFFFFF);
  static const surfaceModal = Color(0xFFFFFFFF);

  static const border = Color(0xFFE8EDF2);
  static const borderSoft = Color(0xFFF1F5F9);
  static const borderStrong = Color(0xFFD7DEE8);

  static const text = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const textInverse = Color(0xFFFFFFFF);

  static const info = Color(0xFF0A84FF);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static const pending = Color(0xFF2563EB);
  static const scheduled = Color(0xFF7C3AED);
  static const completed = success;
  static const cancelled = danger;
  static const overdue = warning;
  static const offline = Color(0xFF64748B);
  static const online = success;

  static const focus = Color(0x332563EB);
  static const scrim = Color(0x660F172A);

  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111827);
  static const darkSurface1 = Color(0xFF172033);
  static const darkSurface2 = Color(0xFF1F2937);
  static const darkBorder = Color(0xFF273244);
  static const darkText = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFCBD5E1);

  static Color surfaceFor(AppSurfaceLevel level, {bool dark = false}) {
    if (dark) {
      return switch (level) {
        AppSurfaceLevel.surface => darkSurface,
        AppSurfaceLevel.surface1 => darkSurface1,
        AppSurfaceLevel.surface2 => darkSurface2,
        AppSurfaceLevel.elevated => darkSurface1,
        AppSurfaceLevel.floating => darkSurface1,
        AppSurfaceLevel.modal => darkSurface,
      };
    }

    return switch (level) {
      AppSurfaceLevel.surface => surface,
      AppSurfaceLevel.surface1 => surface1,
      AppSurfaceLevel.surface2 => surface2,
      AppSurfaceLevel.elevated => surfaceElevated,
      AppSurfaceLevel.floating => surfaceFloating,
      AppSurfaceLevel.modal => surfaceModal,
    };
  }
}
