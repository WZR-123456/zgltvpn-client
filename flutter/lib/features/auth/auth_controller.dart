import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/models/user.dart';
import '../../core/storage/secure_storage.dart';

/// Auth state. A null [user] means "not logged in".
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.needsTotp = false,
  });

  final User? user;
  final bool isLoading;

  /// Last login error, shown verbatim (backend message when available).
  final String? error;

  /// True when the backend asked for a TOTP code.
  final bool needsTotp;

  bool get isLoggedIn => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authApi, this._storage, this._client)
    : super(const AuthState(isLoading: true));

  final AuthApi _authApi;
  final SecureStorage _storage;
  final ApiClient _client;

  /// Restores a saved session on startup: token -> GET /api/me.
  /// An expired/invalid token (401/403) drops the session and shows login.
  /// A network failure keeps the login page with the error shown.
  Future<void> restore() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthState();
      return;
    }
    _client.setToken(token);
    state = const AuthState(isLoading: true);
    try {
      final user = await _authApi.me();
      state = AuthState(user: user);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized ||
          e.kind == ApiErrorKind.forbidden) {
        await _storage.clearSession();
        _client.clearToken();
        state = const AuthState();
      } else {
        state = AuthState(error: e.message);
      }
    } catch (_) {
      state = const AuthState(error: '会话恢复失败，请重新登录');
    }
  }

  /// Logs in. On TOTP challenge the state flips to [AuthState.needsTotp]
  /// and the page shows the code field; the caller resubmits with [totp].
  Future<void> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    final wasTotp = state.needsTotp;
    state = AuthState(isLoading: true, needsTotp: wasTotp);
    try {
      final result = await _authApi.login(
        email: email,
        password: password,
        totp: totp,
      );
      await _storage.saveSession(
        token: result.token,
        subToken: result.user.subToken,
      );
      _client.setToken(result.token);
      state = AuthState(user: result.user);
    } on NeedTotpException {
      state = const AuthState(needsTotp: true);
    } on ApiException catch (e) {
      state = AuthState(error: e.message, needsTotp: wasTotp);
    } catch (_) {
      state = AuthState(error: '登录失败，请重试', needsTotp: wasTotp);
    }
  }

  /// Logs out: deletes the local session and clears the in-memory token.
  Future<void> logout() async {
    await _storage.clearSession();
    _client.clearToken();
    state = const AuthState();
  }
}
