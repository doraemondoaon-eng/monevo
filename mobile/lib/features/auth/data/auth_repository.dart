import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/auth_models.dart';
import 'auth_api.dart';

class AuthRepository {
  const AuthRepository({
    required AuthApi api,
    required SecureStorageService secureStorage,
    LocalCacheService? localCache,
  }) : _api = api,
       _secureStorage = secureStorage,
       _localCache = localCache;

  final AuthApi _api;
  final SecureStorageService _secureStorage;
  final LocalCacheService? _localCache;

  Future<HealthStatus> checkHealth() => _api.checkHealth();

  Future<AuthStatus> getStatus() => _api.getStatus();

  Future<User> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final AuthSession session = await _api.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _secureStorage.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );
    return session.user;
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _api.login(
      email: email,
      password: password,
    );
    await _secureStorage.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );
    return session.user;
  }

  Future<User?> restoreSession() async {
    final String? accessToken = await _secureStorage.getAccessToken();
    final String? refreshToken = await _secureStorage.getRefreshToken();
    if ((accessToken == null || accessToken.isEmpty) &&
        (refreshToken == null || refreshToken.isEmpty)) {
      return null;
    }
    try {
      return await _api.getMe();
    } catch (_) {
      await _secureStorage.clearTokens();
      return null;
    }
  }

  Future<User> updateProfile({
    String? displayName,
    String? timezone,
  }) {
    return _api.updateMe(displayName: displayName, timezone: timezone);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    final String? refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _api.logout(refreshToken);
      } catch (_) {
        // Ignore network errors on logout; always clear local tokens.
      }
    }
    await _secureStorage.clearTokens();
    await _localCache?.clearAll();
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return AuthRepository(
        api: ref.watch(authApiProvider),
        secureStorage: ref.watch(secureStorageProvider),
        localCache: ref.watch(localCacheServiceProvider),
      );
    });
