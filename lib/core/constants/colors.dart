import 'package:flutter/material.dart';

class AppColors {
  // Medical Green & Teal (Primary Branding matching screenshot)
  static const Color primary = Color(0xFF10B981); // Modern Emerald Green
  static const Color primaryLight = Color(0xFF34D399); // Light Emerald
  static const Color primaryDark = Color(0xFF047857); // Dark Emerald Green
  static const Color accent = Color(0xFF0D9488); // Teal contrast

  // Background and Surfaces (Clean Off-White & Pure White Card Panels)
  static const Color background = Color(0xFFF3F4F6); // Soft Light Gray (#F3F4F6)
  static const Color surface = Color(0xFFFFFFFF); // Pure White Sidebar & Headers
  static const Color cardBg = Color(0xFFFFFFFF); // Pure White Cards
  static const Color border = Color(0xFFE5E7EB); // Soft light gray border

  // Alert & Info Feedback
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral Typography Color Hierarchy
  static const Color textPrimary = Color(0xFF111827); // Dark gray for headers & text
  static const Color textSecondary = Color(0xFF4B5563); // Cool gray for sub-elements
  static const Color textMuted = Color(0xFF9CA3AF); // Muted gray for captions

  // Sidebar Specific Highlight color
  static const Color selectedNavBg = Color(0xFFE6F4EA); // Very soft medical green background
  static const Color selectedNavText = Color(0xFF1E8E3E); // Standard material green text

  // Vibrant Modern Gradients
  static const Gradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient darkEmeraldGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient blueGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient purpleGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient amberGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient roseGradient = LinearGradient(
    colors: [Color(0xFFBE123C), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
