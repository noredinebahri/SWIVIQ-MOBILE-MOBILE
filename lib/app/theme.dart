import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette copiée du front Angular (tailwind.config.js) pour garder la même
/// identité visuelle entre le web et le mobile.
class AppColors {
  AppColors._();

  static const primary50 = Color(0xFFEFF6FF);
  static const primary100 = Color(0xFFDBEAFE);
  static const primary200 = Color(0xFFBFDBFE);
  static const primary300 = Color(0xFF93C5FD);
  static const primary400 = Color(0xFF60A5FA);
  static const primary500 = Color(0xFF3B82F6);
  static const primary600 = Color(0xFF2563EB);
  static const primary700 = Color(0xFF1D4ED8);
  static const primary800 = Color(0xFF1E40AF);
  static const primary900 = Color(0xFF1E3A8A);

  static const secondary50 = Color(0xFFF8FAFC);
  static const secondary100 = Color(0xFFF1F5F9);
  static const secondary200 = Color(0xFFE2E8F0);
  static const secondary300 = Color(0xFFCBD5E1);
  static const secondary400 = Color(0xFF94A3B8);
  static const secondary500 = Color(0xFF64748B);
  static const secondary600 = Color(0xFF475569);
  static const secondary700 = Color(0xFF334155);
  static const secondary800 = Color(0xFF1E293B);
  static const secondary900 = Color(0xFF0F172A);

  static const success500 = Color(0xFF22C55E);
  static const success600 = Color(0xFF16A34A);
  static const success100 = Color(0xFFDCFCE7);
  static const warning500 = Color(0xFFF59E0B);
  static const warning100 = Color(0xFFFEF3C7);
  static const danger500 = Color(0xFFEF4444);
  static const danger600 = Color(0xFFDC2626);
  static const danger100 = Color(0xFFFEE2E2);
}

/// [seed] : couleur de marque du centre adopté (marque blanche). Sans elle,
/// la palette historique bleue reste le visage par défaut de l'application.
ThemeData buildTheme(Brightness brightness, {Color? seed}) {
  final isDark = brightness == Brightness.dark;
  final scheme = seed != null
      ? ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
      : ColorScheme.fromSeed(
          seedColor: AppColors.primary500,
          brightness: brightness,
          primary: isDark ? AppColors.primary400 : AppColors.primary600,
          secondary: AppColors.secondary500,
          error: AppColors.danger500,
          surface: isDark ? AppColors.secondary900 : Colors.white,
        );

  final textTheme = GoogleFonts.interTextTheme(
    isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );
  final displayFont = GoogleFonts.poppins();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.secondary900 : AppColors.secondary50,
    textTheme: textTheme.copyWith(
      headlineLarge:
          textTheme.headlineLarge?.copyWith(fontFamily: displayFont.fontFamily),
      headlineMedium: textTheme.headlineMedium
          ?.copyWith(fontFamily: displayFont.fontFamily),
      headlineSmall: textTheme.headlineSmall
          ?.copyWith(fontFamily: displayFont.fontFamily, fontWeight: FontWeight.w600),
      titleLarge: textTheme.titleLarge
          ?.copyWith(fontFamily: displayFont.fontFamily, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: isDark ? AppColors.secondary900 : Colors.white,
      foregroundColor: isDark ? Colors.white : AppColors.secondary800,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.secondary800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.secondary800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.secondary800 : Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark ? AppColors.secondary700 : AppColors.secondary200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark ? AppColors.secondary700 : AppColors.secondary200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary500, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? AppColors.secondary800 : Colors.white,
      indicatorColor:
          isDark ? AppColors.primary900 : AppColors.primary100,
      elevation: 2,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? AppColors.secondary700 : AppColors.secondary200,
    ),
  );
}
