import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/auth_models.dart';

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  /// Calls `GET /health` at the root server URL (without `/api/v1`).
  Future<HealthStatus> checkHealth() async {
    try {
      final String healthUrl = AppConfig.deriveHealthUrl(_dio.options.baseUrl);
      final Response<Map<String, dynamic>> response =
          await _dio.getUri<Map<String, dynamic>>(
            Uri.parse(healthUrl),
            options: Options(
              sendTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );
      return HealthStatus.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AuthStatus> getStatus() async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>('/auth/status');
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AuthStatus.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>(
            '/auth/register',
            data: <String, dynamic>{
              'email': email.trim(),
              'password': password,
              'displayName': displayName.trim(),
            },
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AuthSession.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>(
            '/auth/login',
            data: <String, dynamic>{
              'email': email.trim(),
              'password': password,
            },
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return AuthSession.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<User> getMe() async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>('/auth/me');
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return User.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<User> updateMe({
    String? displayName,
    String? timezone,
  }) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{};
      if (displayName != null) {
        body['displayName'] = displayName.trim();
      }
      if (timezone != null) {
        body['timezone'] = timezone.trim();
      }
      final Response<Map<String, dynamic>> response =
          await _dio.patch<Map<String, dynamic>>(
            '/auth/me',
            data: body,
          );
      final Map<String, dynamic> data =
          (response.data?['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      return User.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/auth/change-password',
        data: <String, dynamic>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<AuthApi> authApiProvider = Provider<AuthApi>((Ref ref) {
  return AuthApi(ref.watch(dioProvider));
});
