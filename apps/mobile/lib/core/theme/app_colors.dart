import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF16A085);
  static const Color primaryDark = Color(0xFF087F68);
  static const Color primaryLight = Color(0xFFE3F7F1);

  // Light theme
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF172B2A);
  static const Color lightSecondaryText = Color(0xFF667085);
  static const Color lightBorder = Color(0xFFE4E7EC);

  // Dark theme
  static const Color darkBackground = Color(0xFF101918);
  static const Color darkSurface = Color(0xFF192421);
  static const Color darkText = Color(0xFFF2F7F5);
  static const Color darkSecondaryText = Color(0xFFADBDB7);
  static const Color darkBorder = Color(0xFF34433E);

  // Status colors
  static const Color success = Color(0xFF16865C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC4545);
}
