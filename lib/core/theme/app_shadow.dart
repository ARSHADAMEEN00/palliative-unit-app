import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadow {
  AppShadow._();

  static const none = <BoxShadow>[];

  static const small = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const medium = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const large = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 40, offset: Offset(0, 16)),
  ];

  static const focus = [
    BoxShadow(color: AppColors.focus, blurRadius: 18, offset: Offset(0, 8)),
  ];

  static List<BoxShadow> forSurface(AppSurfaceLevel level) {
    return switch (level) {
      AppSurfaceLevel.surface => none,
      AppSurfaceLevel.surface1 => none,
      AppSurfaceLevel.surface2 => none,
      AppSurfaceLevel.elevated => medium,
      AppSurfaceLevel.floating => medium,
      AppSurfaceLevel.modal => large,
    };
  }
}
