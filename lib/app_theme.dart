import 'package:flutter/material.dart';

/// Palette : nuit ardoise + ambre Bitcoin utilise avec parcimonie.
class AppColors {
  static const night = Color(0xFF0B0E17);
  static const panel = Color(0xFF141A28);
  static const panelHigh = Color(0xFF1B2334);
  static const line = Color(0xFF243046);
  static const amber = Color(0xFFF7931A);
  static const mint = Color(0xFF4ADE9B);
  static const coral = Color(0xFFFF6B6B);
  static const ink = Color(0xFFEAF0FA);
  static const muted = Color(0xFF7E8AA3);
}

/// Les chiffres sont toujours en chasse fixe : c'est l'identite visuelle de
/// l'application, un poste de pilotage plutot qu'un tableau de bord generique.
const String monoFamily = 'monospace';

TextStyle mono({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double spacing = 0,
}) {
  return TextStyle(
    fontFamily: monoFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: 1.2,
  );
}

TextStyle label() => const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 1.4,
    );

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.night,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.amber,
      secondary: AppColors.mint,
      surface: AppColors.panel,
      error: AppColors.coral,
      onPrimary: Colors.black,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    dividerColor: AppColors.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panelHigh,
      labelStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.6),
      ),
    ),
  );
}
