import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_motion.dart';

/// Builds the smooth horizontal slide + parallax + fade transition.
/// Called by both [SlidePageRoute] and the global [PageTransitionsTheme].
Widget buildSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Incoming page slides from right → center
  final slideIn = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: AppMotion.easeOutCubic));

  // Outgoing page slides center → slightly left (parallax depth effect)
  final slideOut =
      Tween<Offset>(begin: Offset.zero, end: const Offset(-0.25, 0.0)).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.easeInOut),
      );

  // Fade in the incoming page slightly for a polished feel
  final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ),
  );

  return SlideTransition(
    position: slideOut,
    child: SlideTransition(
      position: slideIn,
      child: FadeTransition(opacity: fadeIn, child: child),
    ),
  );
}

/// A custom [PageRoute] that slides the incoming page in from the right
/// (forward) and out to the right (backward), giving a smooth horizontal
/// navigation feel matching iOS-style transitions.
///
/// Usage – drop-in replacement for [MaterialPageRoute]:
/// ```dart
/// Navigator.push(context, SlidePageRoute(builder: (_) => MyPage()));
/// ```
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SlidePageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: AppMotion.slow,
         reverseTransitionDuration: AppMotion.page,
         transitionsBuilder: buildSlideTransition,
       );
}
