import 'package:flutter/material.dart';
import 'dart:ui';

class TxaTheme {
  // Brand Colors from CSS
  static const Color primaryBg = Color(0xFF0A0E17);
  static const Color secondaryBg = Color(0xFF111827);
  static const Color cardBg = Color(0xFF1A1F2E);
  static const Color accent = Color(0xFF737DFD);
  static const Color purple = Color(0xFFA855F7);
  static const Color pink = Color(0xFFEC4899);
  
  static const Gradient brandGradient = LinearGradient(
    colors: [accent, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Glass Effect Config
  static const Color glassBg = Color(0x990F172A); // rgba(15, 23, 42, 0.6)
  static const double glassBlur = 24.0;
  static const Color glassBorder = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryBg,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: purple,
        surface: cardBg,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  // Helper Widget for Liquid Glass Effect
  static Widget glassConnector({
    required Widget child,
    double radius = 32.0,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: glassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: glassBorder, width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }
}
