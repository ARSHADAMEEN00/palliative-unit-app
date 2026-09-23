import 'package:flutter/animation.dart';

class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const page = Duration(milliseconds: 280);

  static const easeOut = Curves.easeOut;
  static const easeOutCubic = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOut;
  static const spring = Curves.easeOutBack;
}
