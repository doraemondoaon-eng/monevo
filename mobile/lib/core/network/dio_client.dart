import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

class SessionExpirationNotifier extends StateNotifier<int> {
  SessionExpirationNotifier() : super(0);

  void notifyExpired() {
    state = state + 1;
  }
}

final StateNotifierProvider<SessionExpirationNotifier, int>
sessionExpirationProvider =
    StateNotifierProvider<SessionExpirationNotifier, int>((Ref ref) {
      return SessionExpirationNotifier();
    });

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final SecureStorageService secureStorage = ref.watch(secureStorageProvider);
  final SessionExpirationNotifier expirationNotifier =
      ref.read(sessionExpirationProvider.notifier);

  final BaseOptions baseOptions = BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: const <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );

  final Dio primaryDio = Dio(baseOptions);
  final Dio refreshDio = Dio(baseOptions);

  primaryDio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (options.data == null &&
            (options.method == 'DELETE' ||
                options.method == 'GET' ||
                options.method == 'HEAD')) {
          options.headers.remove('Content-Type');
          options.headers.remove('content-type');
        }
        return handler.next(options);
      },
    ),
  );

  primaryDio.interceptors.add(
    AuthInterceptor(
      secureStorage: secureStorage,
      retryDio: primaryDio,
      onSessionExpired: expirationNotifier.notifyExpired,
      refreshExecutor: (String refreshToken) async {
        final Response<Map<String, dynamic>> response =
            await refreshDio.post<Map<String, dynamic>>(
              '/auth/refresh',
              data: <String, dynamic>{'refreshToken': refreshToken},
            );
        final Map<String, dynamic>? body = response.data;
        final Map<String, dynamic> data =
            (body?['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final Map<String, dynamic> tokens =
            (data['tokens'] as Map<String, dynamic>?) ?? data;
        final String newAccess = (tokens['accessToken'] ?? '').toString();
        final String newRefresh = (tokens['refreshToken'] ?? '').toString();
        if (newAccess.isEmpty || newRefresh.isEmpty) {
          throw StateError('Invalid token payload from /auth/refresh');
        }
        return (accessToken: newAccess, refreshToken: newRefresh);
      },
    ),
  );

  return primaryDio;
});
