import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Harbor: quiet, structured, premium — flat surfaces separated by a 1px
/// border instead of elevation/shadow, small consistent corner radii.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppPalette.light, Brightness.light);
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      error: p.error,
      onError: p.onError,
      outline: p.border,
      outlineVariant: p.border,
    );

    final textTheme = AppTypography.textTheme().apply(
      bodyColor: p.ink,
      displayColor: p.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,
      dividerColor: p.border,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: p.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.border,
          disabledForegroundColor: p.muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        hintStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      extensions: [AppColorsExt.fromPalette(p)],
    );
  }
}
