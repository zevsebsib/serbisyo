import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFFFF8000); // Primary Orange #FF8000
  static const Color primaryDark = Color(0xFFE67300);
  static const Color secondary = Color(0xFF1A1A1A); // Secondary Black #1A1A1A
  static const Color background = Color(0xFFF6F6F6);
  static const Color surface = Colors.white;
  static const Color muted = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF00A86B);
  static const Color danger = Color(0xFFD32F2F);
  static const Color cardBg = Color(0xFFFFF5EB); // Light orange background from React activity cards
}

class AppTextStyles {
  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: AppColors.secondary,
    letterSpacing: -0.5,
  );

  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.secondary,
    letterSpacing: -0.5,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.secondary.withOpacity(0.7),
  );

  static TextStyle small = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.inter().fontFamily,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.secondary,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
    ),
  );
}
