import 'package:flutter/material.dart';

/// Centralized design tokens for the Ludo app.
///
/// All UI code should read colors / radii / motion constants from this file
/// so the look-and-feel can be tweaked from a single place. Game-logic
/// files (under `lib/logic/*`) MUST NOT import this file — they only ever
/// touch pure data and the constants in `lib/constants/board_constants.dart`.
class AppTheme {
  AppTheme._();

  // ── Brand colors ────────────────────────────────────────────────────────
  static const Color bgDeep = Color(0xFF0a0f1e);
  static const Color bgPanel = Color(0xFF111827);
  static const Color bgPanelAlt = Color(0xFF1e293b);
  static const Color border = Color(0xFF1f2937);
  static const Color borderStrong = Color(0xFF334155);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF94a3b8);
  static const Color textSubtle = Color(0xFF64748b);
  static const Color textFaint = Color(0xFF475569);

  static const Color accentBlue = Color(0xFF60a5fa);
  static const Color accentBlueDeep = Color(0xFF2563eb);
  static const Color accentGreen = Color(0xFF22c55e);
  static const Color accentRed = Color(0xFFef4444);
  static const Color accentYellow = Color(0xFFfacc15);
  static const Color accentAmber = Color(0xFFf59e0b);

  // ── Radii ───────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 22;
  static const double radiusPill = 999;

  // ── Spacing ─────────────────────────────────────────────────────────────
  static const double gap2 = 2;
  static const double gap4 = 4;
  static const double gap6 = 6;
  static const double gap8 = 8;
  static const double gap10 = 10;
  static const double gap12 = 12;
  static const double gap14 = 14;
  static const double gap16 = 16;
  static const double gap20 = 20;
  static const double gap24 = 24;
  static const double gap28 = 28;
  static const double gap32 = 32;
  static const double gap40 = 40;

  // ── Motion durations ────────────────────────────────────────────────────
  static const Duration durFast = Duration(milliseconds: 150);
  static const Duration durMed = Duration(milliseconds: 220);
  static const Duration durSlow = Duration(milliseconds: 350);
  static const Duration durXL = Duration(milliseconds: 600);

  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeInOutCubic;

  // ── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient titleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFef4444),
      Color(0xFFfacc15),
      Color(0xFF22c55e),
      Color(0xFF3b82f6),
    ],
  );

  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2563eb), Color(0xFF60a5fa)],
  );

  static const LinearGradient successButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF16a34a), Color(0xFF22c55e)],
  );

  static const LinearGradient dangerButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFdc2626), Color(0xFFef4444)],
  );

  static const LinearGradient trophyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFfacc15), Color(0xFFf59e0b)],
  );

  // ── ThemeData ───────────────────────────────────────────────────────────
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bgDeep,
      colorScheme: base.colorScheme.copyWith(
        primary: accentBlueDeep,
        secondary: accentGreen,
        surface: bgPanel,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgPanel,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.06),
      dialogTheme: const DialogThemeData(
        backgroundColor: bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        ),
      ),
    );
  }
}

/// Convenience extension — any widget can call `context.gap8` etc. for spacing.
extension SpacingX on num {
  SizedBox get gapBox => SizedBox(width: toDouble(), height: toDouble());
}
