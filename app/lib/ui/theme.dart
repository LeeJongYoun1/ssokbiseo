import 'package:flutter/material.dart';

abstract final class SsokColors {
  static const cream = Color(0xFFFFFBEA);
  static const lemon = Color(0xFFFFD43B);
  static const lemonLight = Color(0xFFFFE58A);
  static const selected = Color(0xFFFFF1B8);
  static const ink = Color(0xFF3B3220);
  static const inkSub = Color(0xFF7A6A2E);
  static const border = Color(0xFFF0DC8A);
  static const card = Color(0xFFFFFFFF);
}

ThemeData ssokTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: SsokColors.lemon).copyWith(
      primary: SsokColors.lemon,
      onPrimary: SsokColors.ink,
      surface: SsokColors.cream,
      onSurface: SsokColors.ink,
    ),
    scaffoldBackgroundColor: SsokColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: SsokColors.cream,
      foregroundColor: SsokColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SsokColors.lemon,
      foregroundColor: SsokColors.ink,
    ),
    cardTheme: CardThemeData(
      color: SsokColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: shape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SsokColors.lemon,
        foregroundColor: SsokColors.ink,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SsokColors.ink,
        side: const BorderSide(color: SsokColors.border),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SsokColors.ink,
        shape: shape,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SsokColors.ink,
      selectionColor: SsokColors.lemonLight,
      selectionHandleColor: SsokColors.ink,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: SsokColors.ink, width: 2),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: SsokColors.cream),
  );
}
