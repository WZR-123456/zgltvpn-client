/// Central app configuration.
///
/// Single source of truth for the API base URL (architecture §4.1).
/// The base URL is never hard-coded anywhere else: every API call goes
/// through [ApiConfig.baseUrl]. Switching to cn.521com.xyz after the custom
/// domain activates is a one-line change here (later: remote config or a
/// settings-page switch).
class ApiConfig {
  ApiConfig._();

  /// Default API base URL. Currently workers.dev; switch to
  /// https://cn.521com.xyz once the custom domain is active.
  static const String baseUrl = 'https://vpn.zgltvpn.workers.dev';

  /// Network timeout for a single request (architecture §4.1: 15 s).
  static const Duration timeout = Duration(seconds: 15);

  /// Headers sent with every request (architecture §4.1).
  static const String clientPlatform = 'android';

  /// App version sent as X-Client-Version (keep in sync with pubspec.yaml).
  static const String clientVersion = '0.1.0';
}
