import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Base Background Colors
  static const Color bgBase = Color(0xFFFAFAFA);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color off = Color(0xFFF3F4F8);

  // Core Theme Colors
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color secondary = Color(0xFF64748B);
  static const Color accent = Color(0xFF4F8EF7);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color text = Color(0xFF1A202C);
  static const Color muted = Color(0xFF8492A6);

  // Accents & Interactive
  static const Color accentPrimary = Color(0xFF111827);
  static const Color accentLight = Color(0xFFF3F4F6);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE6E9F0);

  // Specialty Palette
  static const Color navy = Color(0xFF0B1829);
  static const Color navy2 = Color(0xFF0F2040);
  static const Color gold = Color(0xFFF0B429);
  static const Color white = Color(0xFFFFFFFF);
  static const Color green = Color(0xFF10B981);
  static const Color pink = Color(0xFFE83E8C);
  static const Color teal = Color(0xFF20C997);

  // Glassmorphism effects
  static const Color glassBg = Color(0xD9FFFFFF); // rgba(255, 255, 255, 0.85)
  static const Color glassBorder = Color(0x99FFFFFF); // rgba(255, 255, 255, 0.6)
}

class AppShadows {
  // --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05)
  static const BoxShadow sm = BoxShadow(
    color: Color(0x0D000000),
    offset: Offset(0, 1),
    blurRadius: 2,
    spreadRadius: 0,
  );

  // --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
    BoxShadow(color: Color(0x08000000), offset: Offset(0, 2), blurRadius: 4, spreadRadius: -1),
  ];

  // --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.025)
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 10), blurRadius: 15, spreadRadius: -3),
    BoxShadow(color: Color(0x06000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -2),
  ];

  // --shadow-card: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)
  static const List<BoxShadow> card = md;
}

class AppRadii {
  // --radius-md: 12px
  static final BorderRadius md = BorderRadius.circular(12);
  
  // --radius-lg: 16px
  static final BorderRadius lg = BorderRadius.circular(16);
  
  // --radius-xl: 24px
  static final BorderRadius xl = BorderRadius.circular(24);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.bgColor,
        error: AppColors.pink,
      ),
      scaffoldBackgroundColor: AppColors.bgBase,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        bodyLarge: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.lg),
          elevation: 0,
        ),
      ),
    );
  }
}
