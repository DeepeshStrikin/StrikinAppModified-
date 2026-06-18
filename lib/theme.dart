import 'package:flutter/material.dart';

/// Strikin design tokens — extracted from the Figma CX files.
/// Dark theme with a lime-green primary accent.
class AppColors {
  static const background = Color(0xFF191919);
  static const surface = Color(0xFF262626);
  static const surfaceAlt = Color(0xFF252525);
  static const surfaceElevated = Color(0xFF353535);
  static const border = Color(0xFF333333);
  static const borderSubtle = Color(0xFF2A2A2A);

  static const text = Color(0xFFE5E8EA);
  static const textOnAccent = Color(0xFF161611);
  static const textMuted = Color(0xFF9A9A9A);
  static const textFaint = Color(0xFF646464);

  // Brand accent (lime).
  static Color primary = const Color(0xFFD6FD31);
  static const primaryDim = Color(0xFFA9C927);
  static const success = Color(0xFF36985A);
  static const successBg = Color(0xFF15301F);
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A623);

  static const white = Color(0xFFFFFFFF);
}

class AppSpacing {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48;
}

class AppRadius {
  static const double sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.surface,
      onPrimary: AppColors.textOnAccent,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: 'Poppins',
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
}

// Convenience text styles.
class T {
  static const display = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.15);
  static const h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text);
  static const h3 = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text);
  static const body = TextStyle(fontSize: 15, color: AppColors.text);
  static const bodyStrong = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text);
  static const caption = TextStyle(fontSize: 13, color: AppColors.textMuted);
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5);
}
