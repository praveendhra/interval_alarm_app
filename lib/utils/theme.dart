import 'package:flutter/material.dart';

class AppTheme {
  // ── Color Palette ──────────────────────────────────────────────
  static const Color midnight = Color(0xFF0A0E1A);
  static const Color deepNavy = Color(0xFF111827);
  static const Color cardDark = Color(0xFF1A2035);
  static const Color cardBorder = Color(0xFF2A3150);
  static const Color surfaceGlow = Color(0xFF1E2A4A);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentAmber = Color(0xFFFFAA33);
  static const Color accentTeal = Color(0xFF00D4AA);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentRose = Color(0xFFFF4D6A);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── Gradients ──────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentOrange, accentAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [cardDark, Color(0xFF151D30)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [accentTeal, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Typography — uses only bundled system fonts (no network required) ──
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.8,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // Monospace — for labels/time counters, uses 'monospace' alias (Roboto Mono on Android)
  // iOS has no 'monospace' family, so fall back to Menlo there.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier'],
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 1.2,
  );

  // Tabular figures keep the ticking clock from shifting width each second.
  static const TextStyle timeLarge = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -2,
  );

  static const TextStyle timeMedium = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -1,
  );

  // ── Theme Data ─────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: midnight,
        primaryColor: accentOrange,
        colorScheme: const ColorScheme.dark(
          primary: accentOrange,
          secondary: accentTeal,
          surface: cardDark,
          error: error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: displayMedium,
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: cardBorder, width: 1),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentTeal;
            return textMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentTeal.withOpacity(0.3);
            }
            return cardBorder;
          }),
        ),
        dividerColor: cardBorder,
        textTheme: const TextTheme(
          displayLarge: displayLarge,
          displayMedium: displayMedium,
          headlineLarge: headlineLarge,
          headlineMedium: headlineMedium,
          bodyLarge: bodyLarge,
          bodyMedium: bodyMedium,
          labelLarge: labelLarge,
        ),
      );

  // ── Decorations ────────────────────────────────────────────────
  static BoxDecoration get glassCard => BoxDecoration(
        color: cardDark.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration glowCard(Color glowColor) => BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glowColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ── Accent colors list ─────────────────────────────────────────
  static const List<Color> _accentColors = [
    accentOrange, accentTeal, accentBlue, accentPurple, accentRose, accentAmber,
  ];

  static Color getColor(int index) => _accentColors[index % _accentColors.length];
}
