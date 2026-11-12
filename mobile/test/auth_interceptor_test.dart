import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/network/auth_interceptor.dart';
import 'package:monevo/core/storage/secure_storage_service.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  group('AuthInterceptor single-flight token refresh', () {
    test('refreshes once on 401 TOKEN_EXPIRED and retries concurrent requests', () async {
      final InMemorySecureStorageService storage =
          InMemorySecureStorageService();
      await storage.saveTokens(
        accessToken: 'expired-access-token',
        refreshToken: 'initial-refresh-token',
      );

      int refreshCallCount = 0;
      int protectedCallCount = 0;

      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
      dio.httpClientAdapter = _MockAdapter((RequestOptions options) async {
        protectedCallCount += 1;
        final String? authHeader = options.headers['Authorization']?.toString();
        if (authHeader == 'Bearer expired-access-token') {
          return _jsonResponse(401, <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'TOKEN_EXPIRED',
              'message': 'Access token expired',
            },
          });
        }
        if (authHeader == 'Bearer fresh-access-token') {
          return _jsonResponse(200, <String, dynamic>{
            'data': <String, dynamic>{'ok': true, 'path': options.path},
          });
        }
        return _jsonResponse(401, <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'UNAUTHORIZED',
            'message': 'Missing token',
          },
        });
      });

      dio.interceptors.add(
        AuthInterceptor(
          secureStorage: storage,
          retryDio: dio,
          refreshExecutor: (String currentRefreshToken) async {
            refreshCallCount += 1;
            expect(currentRefreshToken, 'initial-refresh-token');
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return (
              accessToken: 'fresh-access-token',
              refreshToken: 'rotated-refresh-token',
            );
          },
        ),
      );

      final List<Response<Map<String, dynamic>>> responses =
          await Future.wait(<Future<Response<Map<String, dynamic>>>>[
            dio.get<Map<String, dynamic>>('/accounts'),
            dio.get<Map<String, dynamic>>('/dashboard/summary'),
          ]);

      expect(refreshCallCount, 1);
      expect(protectedCallCount, 4); // 2 initial 401s + 2 successful retries
      expect(responses[0].statusCode, 200);
      expect(responses[1].statusCode, 200);
      expect(await storage.getAccessToken(), 'fresh-access-token');
      expect(await storage.getRefreshToken(), 'rotated-refresh-token');
    });

    test('clears tokens and invokes onSessionExpired when refresh fails', () async {
      final InMemorySecureStorageService storage =
          InMemorySecureStorageService();
      await storage.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'revoked-refresh',
      );

      bool sessionExpiredCalled = false;

      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
      dio.httpClientAdapter = _MockAdapter((RequestOptions options) async {
        return _jsonResponse(401, <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'TOKEN_EXPIRED',
            'message': 'Access token expired',
          },
        });
      });

      dio.interceptors.add(
        AuthInterceptor(
          secureStorage: storage,
          retryDio: dio,
          onSessionExpired: () {
            sessionExpiredCalled = true;
          },
          refreshExecutor: (String _) async {
            throw StateError('Refresh token revoked');
          },
        ),
      );

      await expectLater(
        () => dio.get<Map<String, dynamic>>('/accounts'),
        throwsA(isA<DioException>()),
      );

      expect(sessionExpiredCalled, isTrue);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
