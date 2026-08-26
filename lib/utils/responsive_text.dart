import 'package:flutter/material.dart';

/// Utility class to ensure text sizes and layouts scale gracefully and safely across
/// various Android screen densities, aspect ratios, tablet/foldable form factors,
/// and system font scaling settings.
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
    // E.g., 340dp -> 0.88, 360dp -> 0.92, 390dp -> 1.0, 412dp -> 1.05, 600dp+ -> 1.15
    final screenFactor = (screenWidth / baseScreenWidth).clamp(0.88, 1.15);

    // Extract Android OS system text scale factor
    final systemScale = systemTextScaler.scale(1.0);

    // Calculate effective combined scale factor and clamp strictly within safe bounds
    // to prevent layout breaking (on Android with large fonts)
    // and illegibility (on Android with tiny fonts).
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

/// A widget that ensures content is centered and constrained to an optimal width
/// on wide screens (tablets, foldables, landscape mode) while utilizing full width on mobile devices.
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = 720.0,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

/// Responsive extensions on BuildContext for quick and clean access.
extension ResponsiveContextExtension on BuildContext {
  /// Screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Is compact screen (width < 360dp)
  bool get isCompactScreen => screenWidth < 360;

  /// Is standard phone screen (360dp <= width < 600dp)
  bool get isPhoneScreen => screenWidth >= 360 && screenWidth < 600;

  /// Is tablet, foldable, or landscape screen (width >= 600dp)
  bool get isTabletScreen => screenWidth >= 600;

  /// Responsive font size relative to screen
  double responsiveSp(double fontSize) => ResponsiveText.sp(this, fontSize);
}
