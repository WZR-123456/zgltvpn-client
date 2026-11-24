import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_storage.dart';

/// Theme choice persisted in SharedPreferences (phase 3 §5.11).
enum AppThemeMode {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const AppThemeMode(this.label);

  /// Row label shown in the settings page.
  final String label;

  /// The MaterialApp theme mode this choice applies.
  ThemeMode get materialThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// Parses a stored value. Unknown or missing values fall back to
  /// follow-system — never crash on a stale preference.
  static AppThemeMode fromStored(String? value) => switch (value) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };

  /// Value written to SharedPreferences.
  String get storedValue => switch (this) {
    AppThemeMode.system => 'system',
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
  };
}

/// Local settings state. Everything here is a local preference in
/// SharedPreferences; nothing is synced to the server.
class SettingsState {
  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.autoConnect = false,
    this.autoRefreshSubscription = false,
    this.notificationsEnabled = true,
  });

  final AppThemeMode themeMode;

  /// Auto-connect on app start. Local only: the VPN tunnel is not wired
  /// yet, so nothing reads this value today.
  final bool autoConnect;

  /// Auto-refresh the subscription. Local only: no background refresh
  /// exists yet.
  final bool autoRefreshSubscription;

  /// Notifications. Local only: no notification channel exists yet.
  final bool notificationsEnabled;

  SettingsState copyWith({
    AppThemeMode? themeMode,
    bool? autoConnect,
    bool? autoRefreshSubscription,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoConnect: autoConnect ?? this.autoConnect,
      autoRefreshSubscription:
          autoRefreshSubscription ?? this.autoRefreshSubscription,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._storage) : super(const SettingsState());

  final SettingsStorage _storage;
  bool _loaded = false;

  /// Loads the persisted settings once. A storage failure keeps the
  /// defaults — settings must never break the app.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final theme = await _storage.readThemeMode();
      final autoConnect = await _storage.readAutoConnect();
      final autoRefresh = await _storage.readAutoRefreshSubscription();
      final notifications = await _storage.readNotifications();
      state = SettingsState(
        themeMode: AppThemeMode.fromStored(theme),
        autoConnect: autoConnect ?? false,
        autoRefreshSubscription: autoRefresh ?? false,
        notificationsEnabled: notifications ?? true,
      );
    } catch (_) {
      // Keep defaults.
    }
  }

  /// Persists the theme choice and applies it immediately (app.dart
  /// watches [SettingsState.themeMode]).
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (mode == state.themeMode) return;
    state = state.copyWith(themeMode: mode);
    await _storage.saveThemeMode(mode.storedValue);
  }

  Future<void> setAutoConnect(bool value) async {
    if (value == state.autoConnect) return;
    state = state.copyWith(autoConnect: value);
    await _storage.saveAutoConnect(value);
  }

  Future<void> setAutoRefreshSubscription(bool value) async {
    if (value == state.autoRefreshSubscription) return;
    state = state.copyWith(autoRefreshSubscription: value);
    await _storage.saveAutoRefreshSubscription(value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (value == state.notificationsEnabled) return;
    state = state.copyWith(notificationsEnabled: value);
    await _storage.saveNotifications(value);
  }
}
