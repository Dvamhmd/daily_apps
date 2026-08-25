import 'package:flutter/material.dart';

/// Utility class to ensure text sizes scale gracefully and safely across
/// various Android screen densities and system font scaling settings.
class ResponsiveText {
  ResponsiveText._();

  /// Baseline screen width for mobile design (390dp is standard for modern devices)
  static const double baseScreenWidth = 390.0;

  /// Calculate safe effective text scaler based on device screen width
  /// and Android system text scaling factor.
  static TextScaler getEffectiveTextScaler(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return calculateEffectiveTextScaler(
      screenWidth: mediaQuery.size.width,
      systemTextScaler: mediaQuery.textScaler,
    );
  }

  /// Pure calculation method for testability and flexibility.
  static TextScaler calculateEffectiveTextScaler({
    required double screenWidth,
    required TextScaler systemTextScaler,
    double minScale = 0.85,
    double maxScale = 1.10,
  }) {
    // Proportional ratio based on screen width
    // E.g., 360dp -> 0.92, 390dp -> 1.0, 412dp -> 1.05
    final screenFactor = (screenWidth / baseScreenWidth).clamp(0.88, 1.15);

    // Extract Android OS system text scale factor
    final systemScale = systemTextScaler.scale(1.0);

    // Calculate effective combined scale factor and clamp strictly within safe bounds
    // to prevent layout breaking (on Android B with large fonts)
    // and illegibility (on Android C with tiny fonts).
    final effectiveScale = (systemScale * screenFactor).clamp(minScale, maxScale);

    return TextScaler.linear(effectiveScale);
  }

  /// Calculates a responsive font size relative to screen width.
  static double sp(BuildContext context, double fontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / baseScreenWidth).clamp(0.88, 1.15);
    return fontSize * scale;
  }
}
