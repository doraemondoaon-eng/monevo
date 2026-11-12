import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';

typedef TokenPair = ({String accessToken, String refreshToken});
typedef RefreshTokenExecutor = Future<TokenPair> Function(String refreshToken);

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorageService secureStorage,
    required Dio retryDio,
    required RefreshTokenExecutor refreshExecutor,
    this.onSessionExpired,
  }) : _secureStorage = secureStorage,
       _retryDio = retryDio,
       _refreshExecutor = refreshExecutor;

  final SecureStorageService _secureStorage;
  final Dio _retryDio;
  final RefreshTokenExecutor _refreshExecutor;
  final void Function()? onSessionExpired;

  Completer<String?>? _refreshCompleter;

  static const Set<String> _publicPaths = <String>{
    '/health',
    '/auth/status',
    '/auth/register',
    '/auth/login',
    '/auth/refresh',
  };

  bool _isPublicPath(String path) {
    for (final String p in _publicPaths) {
      if (path == p || path.endsWith(p)) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicPath(options.path) &&
        !options.headers.containsKey('Authorization')) {
      final String? token = await _secureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions requestOptions = err.requestOptions;
    final int? statusCode = err.response?.statusCode;
    final bool alreadyRetried = requestOptions.extra['retried'] == true;

    if (statusCode != 401 ||
        alreadyRetried ||
        _isPublicPath(requestOptions.path)) {
      handler.next(err);
      return;
    }

    final String? errorCode = _extractErrorCode(err.response?.data);
    if (errorCode != 'TOKEN_EXPIRED') {
      if (errorCode == 'INVALID_TOKEN' || errorCode == 'UNAUTHORIZED') {
        await _secureStorage.clearTokens();
        onSessionExpired?.call();
      }
      handler.next(err);
      return;
    }

    try {
      final String? newAccessToken = await _performSingleFlightRefresh();
      if (newAccessToken == null || newAccessToken.isEmpty) {
        handler.next(err);
        return;
      }

      final Options retryOptions = Options(
        method: requestOptions.method,
        headers: Map<String, dynamic>.from(requestOptions.headers)
          ..['Authorization'] = 'Bearer $newAccessToken',
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        extra: Map<String, dynamic>.from(requestOptions.extra)
          ..['retried'] = true,
      );

      final Response<dynamic> clonedResponse = await _retryDio.request<dynamic>(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: retryOptions,
        cancelToken: requestOptions.cancelToken,
      );
      handler.resolve(clonedResponse);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _performSingleFlightRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final Completer<String?> completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final String? currentRefreshToken =
          await _secureStorage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        await _secureStorage.clearTokens();
        onSessionExpired?.call();
        completer.complete(null);
        return null;
      }

      final TokenPair rotated = await _refreshExecutor(currentRefreshToken);
      await _secureStorage.saveTokens(
        accessToken: rotated.accessToken,
        refreshToken: rotated.refreshToken,
      );
      completer.complete(rotated.accessToken);
      return rotated.accessToken;
    } catch (_) {
      await _secureStorage.clearTokens();
      onSessionExpired?.call();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  String? _extractErrorCode(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final dynamic errorObj = responseData['error'];
      if (errorObj is Map<String, dynamic>) {
        final dynamic code = errorObj['code'];
        if (code is String) {
          return code;
        }
      }
    }
    return null;
  }
}
