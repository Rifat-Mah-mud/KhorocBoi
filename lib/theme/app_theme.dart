import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lush Systematic design tokens from Stitch mockups.
class AppColors {
  static const primary = Color(0xFF0050CB);
  static const primaryContainer = Color(0xFF0066FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFF8F7FF);

  static const secondary = Color(0xFF3B6566);
  static const secondaryContainer = Color(0xFFBEEBEB);
  static const onSecondaryContainer = Color(0xFF426B6C);

  static const background = Color(0xFFF7F9FB);
  static const surface = Color(0xFFF7F9FB);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF424656);
  static const outline = Color(0xFF727687);
  static const outlineVariant = Color(0xFFC2C6D8);

  // Soft green accents used in analytics mock
  static const lushGreen = Color(0xFF0D631B);
  static const lushGreenContainer = Color(0xFF2E7D32);
  static const lushGreenSoft = Color(0xFFCBFFC2);
  static const lushDrawerBg = Color(0xFFF2F9F2);
  static const lushBorder = Color(0xFFC8E6C9);

  static const error = Color(0xFFBA1A1A);

  // Dark mode
  static const darkBackground = Color(0xFF111416);
  static const darkSurface = Color(0xFF1A1D1F);
  static const darkSurfaceLowest = Color(0xFF232629);
  static const darkOnSurface = Color(0xFFEFF1F3);
  static const darkOnSurfaceVariant = Color(0xFFC2C6D8);
  static const darkOutline = Color(0xFF8C90A0);
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final onSurface = brightness == Brightness.light
        ? AppColors.onSurface
        : AppColors.darkOnSurface;
    final onVariant = brightness == Brightness.light
        ? AppColors.onSurfaceVariant
        : AppColors.darkOnSurfaceVariant;

    // Inter + Noto Sans Bengali for Bangla Unicode in raw text.
    final body = GoogleFonts.interTextTheme().apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );
    final bengaliFallback = GoogleFonts.notoSansBengali();

    return body.copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 48 / 40,
        letterSpacing: -0.02 * 40,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
        letterSpacing: -0.01 * 32,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: onSurface,
      ).copyWith(fontFamilyFallback: [bengaliFallback.fontFamily!]),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: onVariant,
      ).copyWith(fontFamilyFallback: [bengaliFallback.fontFamily!]),
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        color: onVariant,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: onVariant,
      ),
    );
  }

  static ThemeData light() {
    final text = _textTheme(Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.headlineMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        elevation: 6,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lushDrawerBg,
      ),
      dividerColor: AppColors.outlineVariant,
    );
  }

  static ThemeData dark() {
    final text = _textTheme(Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondaryContainer,
        secondaryContainer: AppColors.secondary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: const Color(0xFF3A3E48),
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: const Color(0xFFB3C5FF),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.headlineMedium?.copyWith(
          color: const Color(0xFFB3C5FF),
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3A3E48)),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF152018),
      ),
    );
  }
}
