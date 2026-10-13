import 'package:flutter/material.dart';

const kRed = Color(0xFFD62828);
const kGold = Color(0xFFE9B44C);
const kBg = Color(0xFF0E0E10);
const kSurface = Color(0xFF1A1A1E);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kRed,
    brightness: Brightness.dark,
  ).copyWith(primary: kRed, secondary: kGold, surface: kSurface);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
