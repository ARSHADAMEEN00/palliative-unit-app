class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 1024;

  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}
