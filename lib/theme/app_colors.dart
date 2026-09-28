import 'package:flutter/material.dart';

/// PennyTrack's black-and-orange palette.
class AppColors {
  AppColors._();

  // Surfaces, from the page background up to raised elements.
  static const background = Color(0xFF0B0B0B);
  static const surface = Color(0xFF161616);
  static const surfaceHigh = Color(0xFF1F1F1F);
  static const border = Color(0xFF2A2A2A);

  // Brand orange.
  static const orange = Color(0xFFFF8A00);
  static const orangeDeep = Color(0xFFFF5E00);
  static const orangeLight = Color(0xFFFFB347);

  // Text.
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9A9A9A);
  static const textMuted = Color(0xFF5E5E5E);

  // Status.
  static const income = Color(0xFF3DDC84);
  static const warning = Color(0xFFFFC23D);
  static const danger = Color(0xFFFF4D4F);

  /// Main brand gradient, used on the balance card, the add button and
  /// primary buttons.
  static const orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orangeLight, orange, orangeDeep],
    stops: [0.0, 0.45, 1.0],
  );

  /// Accent colour for each expense category, used for icons and charts.
  static Color category(String category) {
    switch (category) {
      case 'Food':
        return const Color(0xFFFF8A00);
      case 'Transport':
        return const Color(0xFF4DA3FF);
      case 'Bills':
        return const Color(0xFFB57BFF);
      case 'Shopping':
        return const Color(0xFFFF5C8A);
      case 'Income':
        return income;
      default:
        return const Color(0xFF8E8E93);
    }
  }
}
