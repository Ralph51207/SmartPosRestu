import 'package:flutter/material.dart';

/// App-wide constants for colors, sizes, and styling
class AppConstants {
  // ========== COLORS ==========
  
  /// Primary dark background color
  static const Color darkBackground = Color(0xFF1A1A1A);
  
  /// Secondary dark background color
  static const Color darkSecondary = Color(0xFF2D2D2D);
  
  /// Card background color
  static const Color cardBackground = Color(0xFF252525);
  
  /// Primary accent color (orange/warm)
  static const Color primaryOrange = Color(0xFFFF7A00);
  
  /// Secondary accent color (light orange)
  static const Color accentOrange = Color(0xFFFFA040);
  
  /// Success color (green)
  static const Color successGreen = Color(0xFF4CAF50);
  
  /// Warning color (yellow)
  static const Color warningYellow = Color(0xFFFFC107);
  
  /// Error color (red)
  static const Color errorRed = Color(0xFFF44336);
  
  /// Text primary color
  static const Color textPrimary = Color(0xFFFFFFFF);
  
  /// Text secondary color
  static const Color textSecondary = Color(0xFFB0B0B0);
  
  /// Divider color
  static const Color dividerColor = Color(0xFF3A3A3A);

  // Logo / Brand assets
  /// Path to the primary logo asset (optional)
  static const String logoAssetPath = 'assets/images/LOGO.png';

  /// Gradient to match the logo warm orange shading
  static const Color logoGradientStart = Color(0xFFFF7A00);
  static const Color logoGradientEnd = Color(0xFFFFA040);

  // ========== TYPOGRAPHY ==========
  /// Primary app font family. Install and include this font in `pubspec.yaml`
  /// or change to a system font if preferred.
  static const String fontFamily = 'Fredoka';

  // ========== SIZING ==========
  
  /// Standard padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;
  
  /// Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  
  /// Icon sizes
  static const double iconSmall = 20.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // ========== TEXT STYLES ==========
  
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );

  // ========== APP INFO ==========
  
  static const String appName = 'NOMI';
  static const String appVersion = '1.0.0';
  /// Longer formal name
  static const String appFormalName = 'NOM Intelligence';
}
