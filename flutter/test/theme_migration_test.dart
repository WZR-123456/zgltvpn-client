import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/theme.dart';

/// Slice-3 completion: the pages migrated from the hardcoded [ZgltColors] /
/// [ZgltText] tokens to `Theme.of(context)` colours. These tests pin the
/// light theme to the old literals value by value, so light mode cannot
/// drift, and pin the dark theme to the site dark palette.
/// The design-token fields a migrated page actually renders: size,
/// weight, colour and line height. (Font family is the theme default;
/// only the mono styles set one.)
void expectStyle(TextStyle? actual, TextStyle expected) {
  expect(actual?.fontSize, expected.fontSize);
  // An unset weight renders as w400 (ZgltText.mono sets none).
  expect(
    actual?.fontWeight ?? FontWeight.w400,
    expected.fontWeight ?? FontWeight.w400,
  );
  expect(actual?.color, expected.color);
  expect(actual?.height, expected.height);
  // Font family comes from the theme default (Roboto) unless the token
  // sets one (the mono styles); only pin it then.
  if (expected.fontFamily != null) {
    expect(actual?.fontFamily, expected.fontFamily);
  }
}

void main() {
  group('theme migration: light values equal the old hardcoded tokens', () {
    test('textTheme slots equal the ZgltText styles', () {
      // ThemeData merges the passed TextTheme with the default
      // typography (font family, decoration, debug labels), so whole
      // TextStyle equality cannot hold; pin every field instead.
      final light = ZgltTheme.light.textTheme;
      expectStyle(light.titleLarge, ZgltText.title);
      expectStyle(light.titleMedium, ZgltText.heading);
      expectStyle(light.titleSmall, ZgltText.bodyStrong);
      expectStyle(light.bodyMedium, ZgltText.body);
      expectStyle(light.bodySmall, ZgltText.caption);
      expectStyle(light.labelSmall, ZgltText.tiny);
      expectStyle(
        light.headlineSmall,
        const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: ZgltColors.text,
          height: 1.5,
        ),
      );
      // mono / monoLarge are the theme slots plus the monospace family.
      expectStyle(
        light.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ZgltText.mono,
      );
      expectStyle(
        light.headlineSmall?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
        ZgltText.monoLarge,
      );
    });

    test('colorScheme and scaffold slots equal ZgltColors', () {
      final scheme = ZgltTheme.light.colorScheme;
      expect(scheme.primary, ZgltColors.accent);
      expect(scheme.secondary, ZgltColors.accent2);
      expect(scheme.surface, ZgltColors.surface);
      expect(scheme.surfaceContainerHighest, ZgltColors.surfaceMuted);
      expect(scheme.outline, ZgltColors.border);
      expect(scheme.onSurface, ZgltColors.text);
      expect(scheme.error, ZgltColors.danger);
      expect(scheme.onPrimary, Colors.white);
      expect(ZgltTheme.light.scaffoldBackgroundColor, ZgltColors.bg);
      expect(ZgltTheme.light.dividerColor, ZgltColors.border);
    });

    test('extra colours equal ZgltColors in light, ZgltColorsDark in dark', () {
      final lightExtra = ZgltTheme.light.extension<ZgltExtraColors>()!;
      expect(lightExtra.text2, ZgltColors.text2);
      expect(lightExtra.text3, ZgltColors.text3);
      expect(lightExtra.accentSoft, ZgltColors.accentSoft);
      expect(lightExtra.warning, ZgltColors.warning);
      expect(lightExtra.danger, ZgltColors.danger);
      expect(lightExtra.warningSoft, ZgltColors.warningSoft);
      expect(lightExtra.dangerSoft, ZgltColors.dangerSoft);

      final darkExtra = ZgltTheme.dark.extension<ZgltExtraColors>()!;
      expect(darkExtra.text2, ZgltColorsDark.text2);
      expect(darkExtra.text3, ZgltColorsDark.text3);
      expect(darkExtra.accentSoft, ZgltColorsDark.accentSoft);
      expect(darkExtra.warning, ZgltColorsDark.warning);
      expect(darkExtra.danger, ZgltColorsDark.danger);
      expect(darkExtra.warningSoft, ZgltColorsDark.warningSoft);
      expect(darkExtra.dangerSoft, ZgltColorsDark.dangerSoft);
    });

    test('dark theme slots use the site dark palette', () {
      final dark = ZgltTheme.dark.textTheme;
      expect(dark.titleLarge?.color, ZgltColorsDark.text);
      expect(dark.titleMedium?.color, ZgltColorsDark.text);
      expect(dark.titleSmall?.color, ZgltColorsDark.text);
      expect(dark.bodyMedium?.color, ZgltColorsDark.text);
      expect(dark.bodySmall?.color, ZgltColorsDark.text3);
      expect(dark.labelSmall?.color, ZgltColorsDark.text3);
      expect(dark.headlineSmall?.color, ZgltColorsDark.text);
      expect(ZgltTheme.dark.colorScheme.primary, ZgltColorsDark.accent);
      expect(ZgltTheme.dark.colorScheme.surface, ZgltColorsDark.surface);
      expect(
        ZgltTheme.dark.colorScheme.surfaceContainerHighest,
        ZgltColorsDark.surfaceMuted,
      );
      expect(ZgltTheme.dark.colorScheme.outline, ZgltColorsDark.border);
      expect(ZgltTheme.dark.scaffoldBackgroundColor, ZgltColorsDark.bg);
    });
  });
}
