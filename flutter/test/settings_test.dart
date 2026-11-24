import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zgltvpn/core/config.dart';
import 'package:zgltvpn/core/providers.dart';
import 'package:zgltvpn/core/storage/settings_storage.dart';
import 'package:zgltvpn/core/theme.dart';
import 'package:zgltvpn/features/settings/settings_controller.dart';
import 'package:zgltvpn/features/settings/settings_page.dart';

/// In-memory fake storage: no platform channel involved.
class FakeSettingsStorage extends SettingsStorage {
  final Map<String, Object> values = {};

  @override
  Future<String?> readThemeMode() async => values['theme'] as String?;

  @override
  Future<void> saveThemeMode(String value) async {
    values['theme'] = value;
  }

  @override
  Future<bool?> readAutoConnect() async => values['autoConnect'] as bool?;

  @override
  Future<void> saveAutoConnect(bool value) async {
    values['autoConnect'] = value;
  }

  @override
  Future<bool?> readAutoRefreshSubscription() async =>
      values['autoRefresh'] as bool?;

  @override
  Future<void> saveAutoRefreshSubscription(bool value) async {
    values['autoRefresh'] = value;
  }

  @override
  Future<bool?> readNotifications() async => values['notifications'] as bool?;

  @override
  Future<void> saveNotifications(bool value) async {
    values['notifications'] = value;
  }
}

Future<SettingsController> makeController({
  Map<String, Object> initial = const {},
}) async {
  final storage = FakeSettingsStorage()..values.addAll(initial);
  final controller = SettingsController(storage);
  await controller.load();
  return controller;
}

Future<void> pumpSettings(
  WidgetTester tester,
  SettingsController controller,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppThemeMode', () {
    test('maps to the MaterialApp theme mode', () {
      expect(AppThemeMode.system.materialThemeMode, ThemeMode.system);
      expect(AppThemeMode.light.materialThemeMode, ThemeMode.light);
      expect(AppThemeMode.dark.materialThemeMode, ThemeMode.dark);
    });

    test('parses stored values, unknown falls back to system', () {
      expect(AppThemeMode.fromStored('light'), AppThemeMode.light);
      expect(AppThemeMode.fromStored('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromStored('system'), AppThemeMode.system);
      expect(AppThemeMode.fromStored(null), AppThemeMode.system);
      expect(AppThemeMode.fromStored('bogus'), AppThemeMode.system);
    });

    test('stored values round-trip', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStored(mode.storedValue), mode);
      }
    });

    test('dark theme uses the site dark palette', () {
      expect(ZgltTheme.dark.scaffoldBackgroundColor, ZgltColorsDark.bg);
      expect(ZgltTheme.dark.colorScheme.primary, ZgltColorsDark.accent);
      expect(ZgltTheme.dark.colorScheme.surface, ZgltColorsDark.surface);
      expect(ZgltTheme.light.scaffoldBackgroundColor, ZgltColors.bg);
      expect(ZgltTheme.light.colorScheme.primary, ZgltColors.accent);
    });
  });

  group('SettingsController', () {
    test('defaults are system theme, toggles off, notifications on', () async {
      final controller = await makeController();
      expect(controller.state.themeMode, AppThemeMode.system);
      expect(controller.state.autoConnect, isFalse);
      expect(controller.state.autoRefreshSubscription, isFalse);
      expect(controller.state.notificationsEnabled, isTrue);
    });

    test('load restores persisted values', () async {
      final controller = await makeController(
        initial: {
          'theme': 'dark',
          'autoConnect': true,
          'autoRefresh': true,
          'notifications': false,
        },
      );
      expect(controller.state.themeMode, AppThemeMode.dark);
      expect(controller.state.autoConnect, isTrue);
      expect(controller.state.autoRefreshSubscription, isTrue);
      expect(controller.state.notificationsEnabled, isFalse);
    });

    test('setters update state and persist', () async {
      final storage = FakeSettingsStorage();
      final controller = SettingsController(storage);
      await controller.load();

      await controller.setThemeMode(AppThemeMode.light);
      await controller.setAutoConnect(true);
      await controller.setAutoRefreshSubscription(true);
      await controller.setNotificationsEnabled(false);

      expect(controller.state.themeMode, AppThemeMode.light);
      expect(storage.values['theme'], 'light');
      expect(storage.values['autoConnect'], isTrue);
      expect(storage.values['autoRefresh'], isTrue);
      expect(storage.values['notifications'], isFalse);
    });

    test(
      'persists across controller instances (real SharedPreferences)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = SettingsController(SettingsStorage());
        await first.load();
        await first.setThemeMode(AppThemeMode.dark);
        await first.setAutoConnect(true);

        final second = SettingsController(SettingsStorage());
        await second.load();
        expect(second.state.themeMode, AppThemeMode.dark);
        expect(second.state.autoConnect, isTrue);
        // Untouched settings keep their defaults.
        expect(second.state.autoRefreshSubscription, isFalse);
        expect(second.state.notificationsEnabled, isTrue);
      },
    );
  });

  group('SettingsPage', () {
    testWidgets('shows honest labels and the real version', (tester) async {
      final controller = await makeController();
      await pumpSettings(tester, controller);

      expect(find.text('外观'), findsOneWidget);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);
      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('更多语言即将上线'), findsNothing);
      // The toggles persist for real; the subtitles say the preference
      // is saved and takes effect once the feature lands.
      expect(find.text('偏好已保存，连接功能上线后自动连接'), findsOneWidget);
      expect(find.text('偏好已保存，上线后自动刷新订阅'), findsOneWidget);
      expect(find.text('偏好已保存，通知功能上线后生效'), findsOneWidget);
      expect(find.text('ZGLTVPN'), findsOneWidget);
      expect(find.text(ApiConfig.clientVersion), findsOneWidget);
      // No fabricated "already latest" result: update check is tappable
      // and opens an honest coming-soon page instead.
      expect(find.text('检查更新'), findsOneWidget);
      expect(find.text('即将上线'), findsNothing);

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('检查更新即将上线'), findsOneWidget);
      expect(find.textContaining('已是最新'), findsNothing);
    });

    testWidgets('tapping a theme persists it and marks it selected', (
      tester,
    ) async {
      final storage = FakeSettingsStorage();
      final controller = SettingsController(storage);
      await controller.load();
      await pumpSettings(tester, controller);

      expect(controller.state.themeMode, AppThemeMode.system);
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();

      expect(controller.state.themeMode, AppThemeMode.dark);
      expect(storage.values['theme'], 'dark');
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('浅色'));
      await tester.pumpAndSettle();
      expect(controller.state.themeMode, AppThemeMode.light);
      expect(storage.values['theme'], 'light');
    });

    testWidgets('toggling auto-connect persists the local preference', (
      tester,
    ) async {
      final storage = FakeSettingsStorage();
      final controller = SettingsController(storage);
      await controller.load();
      await pumpSettings(tester, controller);

      final tile = find.widgetWithText(SwitchListTile, '自动连接');
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(controller.state.autoConnect, isTrue);
      expect(storage.values['autoConnect'], isTrue);
    });

    testWidgets('restored dark theme shows selected on open', (tester) async {
      final controller = await makeController(initial: {'theme': 'dark'});
      await pumpSettings(tester, controller);

      expect(controller.state.themeMode, AppThemeMode.dark);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
