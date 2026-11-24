import 'package:dio/dio.dart';

import '../config.dart';
import 'api_exception.dart';

/// HTTP client for the ZGLTVPN backend (architecture §4.1).
///
/// - Single [ApiConfig.baseUrl]; never hard-coded anywhere else.
/// - Adds `Authorization: Bearer <token>` when [setToken] was called.
/// - Adds `X-Client-Platform` / `X-Client-Version` headers.
/// - 15 s timeout; GET retries once on transport failure, POST never
///   auto-retries (a retry could double-charge or double-order).
/// - 401/403/429 map to [ApiException] with the backend message verbatim.
class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.baseUrl,
              connectTimeout: ApiConfig.timeout,
              receiveTimeout: ApiConfig.timeout,
              sendTimeout: ApiConfig.timeout,
              headers: <String, dynamic>{
                'Content-Type': 'application/json',
                'X-Client-Platform': ApiConfig.clientPlatform,
                'X-Client-Version': ApiConfig.clientVersion,
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String? _token;

  void setToken(String? token) => _token = token;

  void clearToken() => _token = null;

  /// GET returning a decoded JSON body (Map or List — the backend returns
  /// both shapes depending on the endpoint; callers use [asMap]/[asList]).
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _request(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
      retry: true,
    );
  }

  /// POST with a JSON body. Never auto-retried.
  Future<Response<dynamic>> post(String path, {Object? data}) {
    return _request(() => _dio.post<dynamic>(path, data: data), retry: false);
  }

  /// Reads a response body as a Map; returns an empty Map for anything else.
  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// Reads a response body as a List; returns an empty List for anything else.
  static List<dynamic> asList(dynamic data) {
    if (data is List) return data;
    return const <dynamic>[];
  }

  Future<T> _request<T>(
    Future<T> Function() call, {
    required bool retry,
  }) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (retry && _isTransportError(e)) {
        try {
          return await call();
        } on DioException catch (retryError) {
          throw _mapDioError(retryError);
        }
      }
      throw _mapDioError(e);
    }
  }

  static bool _isTransportError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static ApiException _mapDioError(DioException e) {
    final response = e.response;
    if (response != null) {
      final body = asMap(response.data);
      final backendMessage = _extractMessage(body);
      return ApiException.fromStatus(
        response.statusCode ?? 0,
        backendMessage,
        body: body,
      );
    }
    return ApiException.network();
  }

  static String? _extractMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is String && error.isNotEmpty) return error;
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;
    return null;
  }
}
