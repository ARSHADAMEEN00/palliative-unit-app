import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_radius.dart';

class ModulePalette {
  final Color cardBackground;
  final Color iconBackground;
  final Color primary;

  const ModulePalette({
    required this.cardBackground,
    required this.iconBackground,
    required this.primary,
  });
}

class ModulePalettes {
  ModulePalettes._();

  static const patients = ModulePalette(
    cardBackground: Color(0xFFF2F7FF),
    iconBackground: Color(0xFFDBEAFE),
    primary: Color(0xFF2563EB),
  );

  static const homeVisits = ModulePalette(
    cardBackground: Color(0xFFF0FDF4),
    iconBackground: Color(0xFFDCFCE7),
    primary: Color(0xFF16A34A),
  );

  static const equipmentSupply = ModulePalette(
    cardBackground: Color(0xFFFFFBEB),
    iconBackground: Color(0xFFFEF3C7),
    primary: Color(0xFFF59E0B),
  );

  static const medicineSupply = ModulePalette(
    cardBackground: Color(0xFFF0FDFA),
    iconBackground: Color(0xFFCCFBF1),
    primary: Color(0xFF0F766E),
  );

  static const socialSupport = ModulePalette(
    cardBackground: Color(0xFFFDF2F8),
    iconBackground: Color(0xFFFCE7F3),
    primary: Color(0xFFBE185D),
  );

  static const volunteers = ModulePalette(
    cardBackground: Color(0xFFF0FDFA),
    iconBackground: Color(0xFFCCFBF1),
    primary: Color(0xFF0F766E),
  );
}

class ModuleTheme extends StatelessWidget {
  final ModulePalette palette;
  final Widget child;

  const ModuleTheme({super.key, required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: palette.primary,
          secondary: palette.primary,
          surface: AppColors.surface,
          onSurface: AppColors.text,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: palette.primary,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.fab),
        ),
      ),
      child: child,
    );
  }
}
