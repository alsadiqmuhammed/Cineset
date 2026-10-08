import 'package:flutter/material.dart';

/// ألوان الهوية. بدّلها بألوان ريڤال الرسمية إذا تختلف.
const kGold = Color(0xFFC9A96E);
const kBg = Color(0xFF111315);
const kSurface = Color(0xFF1B1E21);
const kSurfaceHigh = Color(0xFF24282C);
const kText = Color(0xFFF2EEE6);
const kMuted = Color(0xFF9A9A94);

const clinicName = 'عيادة ريڤال';

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: kGold,
        brightness: Brightness.dark,
      ).copyWith(
        primary: kGold,
        onPrimary: const Color(0xFF1A1408),
        secondary: kGold,
        surface: kSurface,
        onSurface: kText,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kText,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: kGold.withValues(alpha: 0.12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kGold.withValues(alpha: 0.2),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kGold,
      foregroundColor: Color(0xFF1A1408),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
