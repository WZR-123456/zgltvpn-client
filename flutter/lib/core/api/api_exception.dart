/// Typed API errors.
///
/// The backend's own error text is surfaced verbatim whenever the backend
/// provides one (phase-3 design rule: show the backend's own words, and
/// always say what the user can do next).
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.unknown,
    this.body,
  });

  /// Builds an exception from an HTTP error status + optional backend body.
  factory ApiException.fromStatus(
    int statusCode,
    String? backendMessage, {
    Map<String, dynamic>? body,
  }) {
    switch (statusCode) {
      case 401:
        return ApiException(
          backendMessage != null && backendMessage.isNotEmpty
              ? backendMessage
              : '账号或密码错误',
          statusCode: statusCode,
          kind: ApiErrorKind.unauthorized,
          body: body,
        );
      case 403:
        return ApiException(
          backendMessage != null && backendMessage.isNotEmpty
              ? backendMessage
              : '账号已被封禁',
          statusCode: statusCode,
          kind: ApiErrorKind.forbidden,
          body: body,
        );
      case 429:
        return ApiException(
          backendMessage != null && backendMessage.isNotEmpty
              ? backendMessage
              : '尝试过多，15 分钟后再试',
          statusCode: statusCode,
          kind: ApiErrorKind.rateLimited,
          body: body,
        );
      default:
        return ApiException(
          backendMessage != null && backendMessage.isNotEmpty
              ? backendMessage
              : '请求失败（$statusCode）',
          statusCode: statusCode,
          kind: ApiErrorKind.server,
          body: body,
        );
    }
  }

  factory ApiException.network([String? detail]) =>
      ApiException(detail ?? '网络异常，请检查网络后重试', kind: ApiErrorKind.network);

  /// Human-readable message (backend text when available).
  final String message;

  /// HTTP status code, when the failure came from a response.
  final int? statusCode;

  final ApiErrorKind kind;

  /// Raw backend response body, when the failure came from a response.
  /// Callers use it to detect flow signals such as `need_totp`.
  final Map<String, dynamic>? body;

  @override
  String toString() => message;
}

enum ApiErrorKind {
  unknown,
  network,
  unauthorized,
  forbidden,
  rateLimited,
  server,
}
