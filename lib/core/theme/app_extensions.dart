import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

extension AppBuildContextTheme on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textStyles => Theme.of(this).textTheme;

  bool get isTabletWidth {
    return AppBreakpoints.isTablet(MediaQuery.sizeOf(this).width);
  }

  bool get isDesktopWidth {
    return AppBreakpoints.isDesktop(MediaQuery.sizeOf(this).width);
  }
}
