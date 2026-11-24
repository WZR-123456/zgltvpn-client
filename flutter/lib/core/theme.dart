import 'package:flutter/material.dart';

/// Design tokens from phase 3 (§2): paper-white + ink-black + one deep-green
/// accent, system fonts, no external resources.
class ZgltColors {
  ZgltColors._();

  /// Page background.
  static const Color bg = Color(0xFFFBFBFD);

  /// Card / dialog background.
  static const Color surface = Color(0xFFFFFFFF);

  /// Secondary background, input background.
  static const Color surfaceMuted = Color(0xFFF5F5F7);

  /// Primary text.
  static const Color text = Color(0xFF161718);

  /// Secondary text.
  static const Color text2 = Color(0xFF2E2F33);

  /// Helper text (time, units, explanations).
  static const Color text3 = Color(0xFF6E7278);

  /// Accent: primary buttons, connected state, selection.
  static const Color accent = Color(0xFF0A5C46);

  /// Accent, one level deeper (hover, connected background).
  static const Color accent2 = Color(0xFF084C3B);

  /// Accent light background (badges, selected rows).
  static const Color accentSoft = Color(0xFFE7F1ED);

  /// Regular borders / dividers: rgba(22,23,24,.12).
  static const Color border = Color(0x1F161718);

  /// Accent borders (selected cards): rgba(10,92,70,.25).
  static const Color borderAccent = Color(0x400A5C46);

  /// Warning (low-saturation amber).
  static const Color warning = Color(0xFF8A6D00);

  /// Danger / error / expired.
  static const Color danger = Color(0xFFB3261E);

  /// Danger at 8% opacity (error block background).
  static const Color dangerSoft = Color(0x14B3261E);

  /// Warning at 8% opacity (offline banner background).
  static const Color warningSoft = Color(0x148A6D00);
}

/// Text styles (phase 3 §2.2). Numbers use the monospace styles so digits
/// never jump while updating.
class ZgltText {
  ZgltText._();

  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: ZgltColors.text,
    height: 1.5,
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: ZgltColors.text,
    height: 1.5,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ZgltColors.text,
    height: 1.5,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ZgltColors.text,
    height: 1.5,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: ZgltColors.text,
    height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: ZgltColors.text3,
    height: 1.5,
  );
  static const TextStyle tiny = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: ZgltColors.text3,
    height: 1.5,
  );

  /// Monospace numbers (latency, traffic, IP, logs).
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    color: ZgltColors.text,
    height: 1.5,
  );
  static const TextStyle monoLarge = TextStyle(
    fontFamily: 'monospace',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: ZgltColors.text,
    height: 1.5,
  );
}

class ZgltTheme {
  ZgltTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: ZgltColors.accent,
      onPrimary: Colors.white,
      secondary: ZgltColors.accent2,
      surface: ZgltColors.surface,
      onSurface: ZgltColors.text,
      surfaceContainerHighest: ZgltColors.surfaceMuted,
      outline: ZgltColors.border,
      error: ZgltColors.danger,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ZgltColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: ZgltColors.bg,
        foregroundColor: ZgltColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZgltColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColors.borderAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColors.danger),
        ),
        hintStyle: const TextStyle(color: ZgltColors.text3, fontSize: 14),
        labelStyle: const TextStyle(color: ZgltColors.text2, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZgltColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ZgltColors.surfaceMuted,
          disabledForegroundColor: ZgltColors.text3,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZgltColors.text,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: ZgltColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZgltColors.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ZgltColors.surface,
        selectedItemColor: ZgltColors.accent,
        unselectedItemColor: ZgltColors.text3,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        elevation: 0,
      ),
      dividerColor: ZgltColors.border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ZgltColors.text,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
