import 'api_client.dart';
import 'api_exception.dart';
import '../models/user.dart';

/// Thrown when the backend asks for a TOTP code (`{"need_totp": true}`).
/// The login page then shows the 6-digit code field and resubmits.
class NeedTotpException implements Exception {
  const NeedTotpException();
}

/// Auth API: POST /api/login, GET /api/me (contract: SUBSCRIPTION.md §1).
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// Logs in with email + password, plus an optional TOTP code.
  ///
  /// Success returns the 30-day session token and the user record
  /// (including `sub_token`). Failures surface as [ApiException] with the
  /// backend message verbatim (401 wrong password, 429 too many attempts,
  /// 403 banned). A TOTP challenge surfaces as [NeedTotpException].
  Future<LoginResult> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (totp != null && totp.isNotEmpty) body['totp'] = totp;
    try {
      final response = await _client.post('/api/login', data: body);
      final data = ApiClient.asMap(response.data);
      if (data['need_totp'] == true) throw const NeedTotpException();
      return _parseLoginResult(data);
    } on ApiException catch (e) {
      // The backend may also report the TOTP challenge inside an error body.
      if (e.body?['need_totp'] == true) throw const NeedTotpException();
      rethrow;
    }
  }

  /// Fetches the current user (pubUser + check-in/invite state).
  /// Callers refresh this on startup, on foreground, and after any write.
  Future<User> me() async {
    final response = await _client.get('/api/me');
    final data = ApiClient.asMap(response.data);
    final userJson = data['user'];
    if (userJson is Map<String, dynamic>) {
      return User.fromJson(userJson);
    }
    // Defensive: some responses carry the user fields at the top level.
    if (data.containsKey('email')) return User.fromJson(data);
    throw const ApiException('用户信息加载失败');
  }

  LoginResult _parseLoginResult(Map<String, dynamic> data) {
    final token = data['token'] as String?;
    final userJson = data['user'];
    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw const ApiException('登录失败，请重试');
    }
    return LoginResult(token: token, user: User.fromJson(userJson));
  }
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  /// 30-day session token. Stored in secure storage only.
  final String token;

  final User user;
}
