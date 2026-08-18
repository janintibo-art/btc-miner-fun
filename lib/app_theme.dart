import 'package:flutter/material.dart';

/// Identite visuelle "Bitcoin reactor" : noir profond, ambre Bitcoin,
/// cyan electrique et violet plasma. Les couleurs secondaires servent surtout
/// aux halos et aux informations d'etat afin de conserver une bonne lisibilite.
class AppColors {
  static const abyss = Color(0xFF02040A);
  static const night = Color(0xFF060913);
  static const nightHigh = Color(0xFF0B1020);
  static const panel = Color(0xFF0E1422);
  static const panelHigh = Color(0xFF151D2E);
  static const panelLift = Color(0xFF1C263B);
  static const line = Color(0xFF293854);
  static const lineBright = Color(0xFF3A4C6C);

  static const amber = Color(0xFFF7931A);
  static const amberHot = Color(0xFFFFB23F);
  static const cyan = Color(0xFF36D9FF);
  static const violet = Color(0xFF8A6CFF);
  static const mint = Color(0xFF4ADE9B);
  static const coral = Color(0xFFFF6878);

  static const ink = Color(0xFFF2F7FF);
  static const muted = Color(0xFF8492AD);
  static const dim = Color(0xFF53617A);
}

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
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      color: AppColors.muted,
      letterSpacing: 1.65,
    );

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.night,
    canvasColor: AppColors.night,
    splashColor: AppColors.amber.withOpacity(0.08),
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.amber,
      secondary: AppColors.cyan,
      tertiary: AppColors.violet,
      surface: AppColors.panel,
      error: AppColors.coral,
      onPrimary: Color(0xFF171008),
      onSecondary: AppColors.abyss,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    dividerColor: AppColors.line,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.panelLift,
      contentTextStyle: const TextStyle(color: AppColors.ink),
      shape: rounded,
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panelHigh.withOpacity(0.86),
      labelStyle: const TextStyle(color: AppColors.muted),
      helperStyle: const TextStyle(color: AppColors.dim, height: 1.35),
      prefixIconColor: AppColors.cyan,
      suffixIconColor: AppColors.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.line.withOpacity(0.55)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 50),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 50),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.lineBright),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyan,
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.amber : AppColors.muted),
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
          ? AppColors.amber.withOpacity(0.28)
          : AppColors.panelLift),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.amber,
      thumbColor: AppColors.amberHot,
      inactiveTrackColor: AppColors.panelLift,
      overlayColor: AppColors.amber.withOpacity(0.12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.amber,
      linearTrackColor: AppColors.panelLift,
    ),
  );
}
