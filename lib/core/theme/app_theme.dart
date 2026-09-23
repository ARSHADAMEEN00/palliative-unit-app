import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light({PageTransitionsTheme? pageTransitionsTheme}) {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textInverse,
      secondary: AppColors.info,
      onSecondary: AppColors.textInverse,
      error: AppColors.danger,
      onError: AppColors.textInverse,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      background: AppColors.background,
      surface: AppColors.surface,
      surface1: AppColors.surface1,
      surface2: AppColors.surface2,
      border: AppColors.border,
      text: AppColors.text,
      textSecondary: AppColors.textSecondary,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      pageTransitionsTheme: pageTransitionsTheme,
    );
  }

  static ThemeData dark({PageTransitionsTheme? pageTransitionsTheme}) {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.textInverse,
      secondary: AppColors.info,
      onSecondary: AppColors.textInverse,
      error: AppColors.danger,
      onError: AppColors.textInverse,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      surface1: AppColors.darkSurface1,
      surface2: AppColors.darkSurface2,
      border: AppColors.darkBorder,
      text: AppColors.darkText,
      textSecondary: AppColors.darkTextSecondary,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      pageTransitionsTheme: pageTransitionsTheme,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color background,
    required Color surface,
    required Color surface1,
    required Color surface2,
    required Color border,
    required Color text,
    required Color textSecondary,
    required SystemUiOverlayStyle systemOverlayStyle,
    PageTransitionsTheme? pageTransitionsTheme,
  }) {
    final textTheme = AppTypography.textTheme(text);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: pageTransitionsTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: const IconThemeData(size: 24),
        systemOverlayStyle: systemOverlayStyle,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: AppInsets.button,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: AppColors.surface2,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ).copyWith(animationDuration: AppMotion.fast),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: AppInsets.button,
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: AppColors.surface2,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ).copyWith(animationDuration: AppMotion.fast),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: AppInsets.button,
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: border),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ).copyWith(animationDuration: AppMotion.fast),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ).copyWith(animationDuration: AppMotion.fast),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface1,
        contentPadding: AppInsets.input,
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        helperStyle: textTheme.labelSmall?.copyWith(color: textSecondary),
        errorStyle: textTheme.labelSmall?.copyWith(color: AppColors.danger),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface1,
        selectedColor: AppColors.primaryLight,
        disabledColor: AppColors.surface2,
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
        ),
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: AppColors.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        clipBehavior: Clip.antiAlias,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fab),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textInverse,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: AppColors.primaryLight,
      ),
      iconTheme: IconThemeData(color: text, size: 20),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: text,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: textTheme.bodyMedium,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSurfaceTokens(
          background: background,
          surface: surface,
          surface1: surface1,
          surface2: surface2,
          border: border,
        ),
      ],
    );
  }
}

class AppSurfaceTokens extends ThemeExtension<AppSurfaceTokens> {
  const AppSurfaceTokens({
    required this.background,
    required this.surface,
    required this.surface1,
    required this.surface2,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color surface1;
  final Color surface2;
  final Color border;

  @override
  AppSurfaceTokens copyWith({
    Color? background,
    Color? surface,
    Color? surface1,
    Color? surface2,
    Color? border,
  }) {
    return AppSurfaceTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
    );
  }

  @override
  AppSurfaceTokens lerp(ThemeExtension<AppSurfaceTokens>? other, double t) {
    if (other is! AppSurfaceTokens) return this;

    return AppSurfaceTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surface1: Color.lerp(surface1, other.surface1, t) ?? surface1,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      border: Color.lerp(border, other.border, t) ?? border,
    );
  }
}
