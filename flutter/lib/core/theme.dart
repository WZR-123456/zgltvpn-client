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

/// Dark palette (phase 3 §2, site dark mode). Only the five site dark
/// values are new here (bg, surface, text, border, accent); every other
/// token reuses a site value or a light-token hue at an opacity, so no
/// unrelated colour is invented.
class ZgltColorsDark {
  ZgltColorsDark._();

  /// Page background (site dark bg).
  static const Color bg = Color(0xFF161718);

  /// Card / dialog background (site dark surface).
  static const Color surface = Color(0xFF222325);

  /// Secondary background, input background (site dark border value).
  static const Color surfaceMuted = Color(0xFF2E2F33);

  /// Primary text (site dark text).
  static const Color text = Color(0xFFF2F2F3);

  /// Secondary text: dark text at 75% opacity.
  static const Color text2 = Color(0xBFF2F2F3);

  /// Helper text: dark text at 60% opacity.
  static const Color text3 = Color(0x99F2F2F3);

  /// Accent (site dark accent).
  static const Color accent = Color(0xFF12805F);

  /// Accent, one level deeper: the light accent, reused.
  static const Color accent2 = ZgltColors.accent;

  /// Accent light background: dark accent at 20% opacity.
  static const Color accentSoft = Color(0x3312805F);

  /// Regular borders / dividers (site dark border).
  static const Color border = Color(0xFF2E2F33);

  /// Accent borders (selected cards): dark accent at 25% opacity.
  static const Color borderAccent = Color(0x4012805F);

  /// Warning / danger keep the light-token hues (functional colours).
  static const Color warning = ZgltColors.warning;
  static const Color danger = ZgltColors.danger;
  static const Color dangerSoft = ZgltColors.dangerSoft;
  static const Color warningSoft = ZgltColors.warningSoft;
}

/// Extra design tokens with no `ColorScheme` / `TextTheme` slot:
/// secondary and helper text, the soft accent fill, and the functional
/// warning / danger colours (same hue in both themes). Light values are
/// the [ZgltColors] literals exactly; dark values are the
/// [ZgltColorsDark] matches, so pages reading these through
/// `Theme.of(context).extension<ZgltExtraColors>()` follow the active
/// theme while light mode stays pixel-identical.
@immutable
class ZgltExtraColors extends ThemeExtension<ZgltExtraColors> {
  const ZgltExtraColors({
    required this.text2,
    required this.text3,
    required this.accentSoft,
    required this.warning,
    required this.danger,
    required this.warningSoft,
    required this.dangerSoft,
  });

  final Color text2;
  final Color text3;
  final Color accentSoft;
  final Color warning;
  final Color danger;
  final Color warningSoft;
  final Color dangerSoft;

  static const light = ZgltExtraColors(
    text2: ZgltColors.text2,
    text3: ZgltColors.text3,
    accentSoft: ZgltColors.accentSoft,
    warning: ZgltColors.warning,
    danger: ZgltColors.danger,
    warningSoft: ZgltColors.warningSoft,
    dangerSoft: ZgltColors.dangerSoft,
  );

  static const dark = ZgltExtraColors(
    text2: ZgltColorsDark.text2,
    text3: ZgltColorsDark.text3,
    accentSoft: ZgltColorsDark.accentSoft,
    warning: ZgltColorsDark.warning,
    danger: ZgltColorsDark.danger,
    warningSoft: ZgltColorsDark.warningSoft,
    dangerSoft: ZgltColorsDark.dangerSoft,
  );

  @override
  ZgltExtraColors copyWith({
    Color? text2,
    Color? text3,
    Color? accentSoft,
    Color? warning,
    Color? danger,
    Color? warningSoft,
    Color? dangerSoft,
  }) {
    return ZgltExtraColors(
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      accentSoft: accentSoft ?? this.accentSoft,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      warningSoft: warningSoft ?? this.warningSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
    );
  }

  @override
  ZgltExtraColors lerp(ThemeExtension<ZgltExtraColors>? other, double t) {
    if (other is! ZgltExtraColors) return this;
    return ZgltExtraColors(
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
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
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: ZgltColors.text,
          height: 1.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ZgltColors.text,
          height: 1.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ZgltColors.text,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ZgltColors.text,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ZgltColors.text,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: ZgltColors.text3,
          height: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: ZgltColors.text3,
          height: 1.5,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[ZgltExtraColors.light],
    );
  }

  /// Dark theme from the site dark palette. Same sizes, weights and
  /// radii as [light]; only colours change. All pages read their
  /// colours from the theme (`Theme.of(context)`), so dark mode
  /// applies app-wide.
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: ZgltColorsDark.accent,
      onPrimary: Colors.white,
      secondary: ZgltColorsDark.accent2,
      surface: ZgltColorsDark.surface,
      onSurface: ZgltColorsDark.text,
      surfaceContainerHighest: ZgltColorsDark.surfaceMuted,
      outline: ZgltColorsDark.border,
      error: ZgltColorsDark.danger,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ZgltColorsDark.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: ZgltColorsDark.bg,
        foregroundColor: ZgltColorsDark.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZgltColorsDark.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColorsDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColorsDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColorsDark.borderAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColorsDark.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZgltColorsDark.danger),
        ),
        hintStyle: const TextStyle(color: ZgltColorsDark.text3, fontSize: 14),
        labelStyle: const TextStyle(color: ZgltColorsDark.text2, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZgltColorsDark.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ZgltColorsDark.surfaceMuted,
          disabledForegroundColor: ZgltColorsDark.text3,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZgltColorsDark.text,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: ZgltColorsDark.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZgltColorsDark.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ZgltColorsDark.surface,
        selectedItemColor: ZgltColorsDark.accent,
        unselectedItemColor: ZgltColorsDark.text3,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        elevation: 0,
      ),
      dividerColor: ZgltColorsDark.border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ZgltColorsDark.text,
        contentTextStyle: TextStyle(color: Colors.black, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: ZgltColorsDark.text,
          height: 1.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ZgltColorsDark.text,
          height: 1.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ZgltColorsDark.text,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ZgltColorsDark.text,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ZgltColorsDark.text,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: ZgltColorsDark.text3,
          height: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: ZgltColorsDark.text3,
          height: 1.5,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[ZgltExtraColors.dark],
    );
  }
}
