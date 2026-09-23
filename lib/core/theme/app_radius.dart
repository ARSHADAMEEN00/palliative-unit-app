import 'package:flutter/widgets.dart';

class AppRadius {
  AppRadius._();

  static const double xsValue = 8;
  static const double smValue = 12;
  static const double mdValue = 16;
  static const double buttonValue = 18;
  static const double cardValue = 20;
  static const double fabValue = 22;
  static const double dialogValue = 24;
  static const double sheetValue = 28;

  static const xs = BorderRadius.all(Radius.circular(xsValue));
  static const sm = BorderRadius.all(Radius.circular(smValue));
  static const md = BorderRadius.all(Radius.circular(mdValue));
  static const input = BorderRadius.all(Radius.circular(mdValue));
  static const button = BorderRadius.all(Radius.circular(buttonValue));
  static const card = BorderRadius.all(Radius.circular(cardValue));
  static const fab = BorderRadius.all(Radius.circular(fabValue));
  static const dialog = BorderRadius.all(Radius.circular(dialogValue));
  static const sheet = BorderRadius.vertical(top: Radius.circular(sheetValue));
}
