import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage wrapper (architecture §3.5 / §4.3).
///
/// Android side is EncryptedSharedPreferences backed by the Keystore.
/// Stores ONLY session credentials: `token`, `sub_token`, `device_id`.
/// Passwords are never stored, never logged, never included in diagnostics.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyToken = 'zgltvpn.token';
  static const String _keySubToken = 'zgltvpn.sub_token';
  static const String _keyDeviceId = 'zgltvpn.device_id';

  final FlutterSecureStorage _storage;

  /// Persists a login session (token + sub_token) after a successful login.
  Future<void> saveSession({
    required String token,
    required String subToken,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keySubToken, value: subToken);
  }

  Future<String?> readToken() => _storage.read(key: _keyToken);

  Future<String?> readSubToken() => _storage.read(key: _keySubToken);

  /// Deletes the local session (logout). Callers also clear the in-memory
  /// token on the [ApiClient].
  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keySubToken);
  }

  /// Stable per-device id (used for the future device-management API).
  /// Generated once and persisted; never derived from hardware identifiers.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _newDeviceId();
    await _storage.write(key: _keyDeviceId, value: id);
    return id;
  }

  static String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // UUID v4 layout: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
