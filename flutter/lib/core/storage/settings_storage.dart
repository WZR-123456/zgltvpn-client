import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local settings (phase 3 §5.11).
///
/// Plain SharedPreferences — settings only. Tokens, passwords and any
/// credential live in [SecureStorage] and must never be stored here.
class SettingsStorage {
  SettingsStorage({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String _keyThemeMode = 'zgltvpn.settings.theme_mode';
  static const String _keyAutoConnect = 'zgltvpn.settings.auto_connect';
  static const String _keyAutoRefreshSub =
      'zgltvpn.settings.auto_refresh_subscription';
  static const String _keyNotifications = 'zgltvpn.settings.notifications';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async =>
      _prefsOverride ?? (_prefs ??= await SharedPreferences.getInstance());

  /// Stored theme choice: 'system' | 'light' | 'dark'. Null when never set.
  Future<String?> readThemeMode() async =>
      (await _instance()).getString(_keyThemeMode);

  Future<void> saveThemeMode(String value) async =>
      (await _instance()).setString(_keyThemeMode, value);

  /// Auto-connect on app start. Local preference only: the VPN tunnel
  /// is not wired yet, so nothing reads this value today.
  Future<bool?> readAutoConnect() async =>
      (await _instance()).getBool(_keyAutoConnect);

  Future<void> saveAutoConnect(bool value) async =>
      (await _instance()).setBool(_keyAutoConnect, value);

  /// Auto-refresh the subscription. Local preference only: no
  /// background refresh exists yet.
  Future<bool?> readAutoRefreshSubscription() async =>
      (await _instance()).getBool(_keyAutoRefreshSub);

  Future<void> saveAutoRefreshSubscription(bool value) async =>
      (await _instance()).setBool(_keyAutoRefreshSub, value);

  /// Notifications. Local preference only: no notification channel
  /// exists yet.
  Future<bool?> readNotifications() async =>
      (await _instance()).getBool(_keyNotifications);

  Future<void> saveNotifications(bool value) async =>
      (await _instance()).setBool(_keyNotifications, value);
}
