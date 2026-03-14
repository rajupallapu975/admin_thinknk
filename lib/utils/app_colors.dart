import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors (Strict from Logo)
  static const Color primaryBlue = Color(0xFF007BFF);  // From "INK"
  static const Color primaryBlack = Color(0xFF1A1A1A); // From "THINK"
  
  // Neutral Colors
  static const Color background = Color(0xFFFBFBFB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E7EB);

  // Grey Aliases
  static const Color greyLight = Color(0xFFE5E7EB);
  static const Color greyDark = Color(0xFF6B7280);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Shadows & Overlays
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];
}
