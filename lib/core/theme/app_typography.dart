import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const _fallbackFonts = <String>['NotoSansMalayalam'];

  static TextStyle? dropdownTextStyle(BuildContext context, {Color? color}) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return style?.copyWith(
      color: color ?? style.color,
      fontWeight: FontWeight.normal,
    );
  }

  static TextTheme textTheme(Color color) {
    const base = TextStyle(
      fontFamilyFallback: _fallbackFonts,
      letterSpacing: 0,
      height: 1.25,
    );

    return TextTheme(
      displayLarge: base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      labelLarge: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelMedium: base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      labelSmall: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}
