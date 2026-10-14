import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import 'api_exception.dart';

/// Dio client dengan interceptor auth, logging, dan error mapping ke
/// [ApiException].
class ApiClient {
  ApiClient._();

  static final Dio _dio = _createDio();

  static Dio get instance => _dio;

  static Dio _createDio() {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll(<Interceptor>[
      _AuthInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);

    return dio;
  }

  /// Update token setelah login / refresh.
  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Hapus token saat logout.
  static void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Token sudah di-set via ApiClient.setToken().
    // Bila perlu refresh token di sini, tambahkan logic nanti.
    handler.next(options);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('➡️ ${options.method} ${options.uri}');
    debugPrint('Headers: ${options.headers}');
    if (options.data != null) debugPrint('Body: ${options.data}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('✅ ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final ApiException exception = _mapError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        message: exception.message,
      ),
    );
  }

  ApiException _mapError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.error is SocketException) {
      return const NetworkException();
    }

    final int? status = err.response?.statusCode;
    final dynamic data = err.response?.data;
    final String msg = _extractMessage(data) ?? err.message ?? 'Terjadi kesalahan.';

    switch (status) {
      case 401:
        return UnauthorizedException(msg);
      case 403:
        return ForbiddenException(msg);
      case 404:
        return NotFoundException(msg);
      case 409:
        return ConflictException(msg);
      case 422:
        return ValidationException(_extractValidationErrors(data), message: msg);
      default:
        return ServerException(msg);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ??
          (data['error'] as String?);
    }
    return null;
  }

  Map<String, List<String>>? _extractValidationErrors(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final dynamic errors = data['errors'];
    if (errors is! Map<String, dynamic>) return null;
    return errors.map((String key, dynamic value) {
      if (value is List) {
        return MapEntry<String, List<String>>(key, value.whereType<String>().toList());
      }
      return MapEntry<String, List<String>>(key, <String>['$value']);
    });
  }
}
