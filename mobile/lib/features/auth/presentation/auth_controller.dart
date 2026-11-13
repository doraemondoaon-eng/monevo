import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

enum AuthStage {
  wakingServer,
  needsSetup,
  unauthenticated,
  authenticated,
}

class AuthState {
  const AuthState({
    this.stage = AuthStage.wakingServer,
    this.user,
    this.isSubmitting = false,
    this.wakeupAttempt = 1,
    this.wakeupElapsedSeconds = 0,
    this.error,
  });

  final AuthStage stage;
  final User? user;
  final bool isSubmitting;
  final int wakeupAttempt;
  final int wakeupElapsedSeconds;
  final ApiException? error;

  bool get isAuthenticated =>
      stage == AuthStage.authenticated && user != null;

  AuthState copyWith({
    AuthStage? stage,
    User? user,
    bool clearUser = false,
    bool? isSubmitting,
    int? wakeupAttempt,
    int? wakeupElapsedSeconds,
    ApiException? error,
    bool clearError = false,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      wakeupAttempt: wakeupAttempt ?? this.wakeupAttempt,
      wakeupElapsedSeconds: wakeupElapsedSeconds ?? this.wakeupElapsedSeconds,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._repository, {
    bool autoBootstrap = true,
    this.minSplashDuration = const Duration(milliseconds: 1450),
  }) : super(const AuthState()) {
    if (autoBootstrap) {
      bootstrap();
    }
  }

  final AuthRepository _repository;
  final Duration minSplashDuration;
  Timer? _elapsedTimer;
  bool _bootstrapping = false;
  bool _completedInitialSplash = false;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> bootstrap() async {
    if (_bootstrapping) {
      return;
    }
    _bootstrapping = true;
    _elapsedTimer?.cancel();

    final Future<void>? minSplashFuture =
        !_completedInitialSplash && minSplashDuration > Duration.zero
            ? Future<void>.delayed(minSplashDuration)
            : null;

    state = state.copyWith(
      stage: AuthStage.wakingServer,
      wakeupAttempt: 1,
      wakeupElapsedSeconds: 0,
      clearError: true,
    );

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && state.stage == AuthStage.wakingServer) {
        state = state.copyWith(
          wakeupElapsedSeconds: state.wakeupElapsedSeconds + 1,
        );
      }
    });

    int attempt = 1;
    while (mounted && state.stage == AuthStage.wakingServer) {
      try {
        await _repository.checkHealth();
        final AuthStatus status = await _repository.getStatus();

        if (status.registrationOpen) {
          if (minSplashFuture != null) {
            await minSplashFuture;
          }
          _completedInitialSplash = true;
          _elapsedTimer?.cancel();
          if (!mounted) {
            break;
          }
          state = state.copyWith(
            stage: AuthStage.needsSetup,
            clearUser: true,
            clearError: true,
          );
          _bootstrapping = false;
          return;
        }

        final User? restoredUser = await _repository.restoreSession();
        if (minSplashFuture != null) {
          await minSplashFuture;
        }
        _completedInitialSplash = true;
        _elapsedTimer?.cancel();
        if (!mounted) {
          break;
        }
        if (restoredUser != null) {
          state = state.copyWith(
            stage: AuthStage.authenticated,
            user: restoredUser,
            clearError: true,
          );
        } else {
          state = state.copyWith(
            stage: AuthStage.unauthenticated,
            clearUser: true,
            clearError: true,
          );
        }
        _bootstrapping = false;
        return;
      } on ApiException catch (e) {
        _completedInitialSplash = true;
        attempt += 1;
        if (!mounted) {
          break;
        }
        state = state.copyWith(
          wakeupAttempt: attempt,
          error: e,
        );
        await Future<void>.delayed(const Duration(seconds: 3));
      } catch (_) {
        _completedInitialSplash = true;
        attempt += 1;
        if (!mounted) {
          break;
        }
        state = state.copyWith(wakeupAttempt: attempt);
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
    _bootstrapping = false;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final User user = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = state.copyWith(
        stage: AuthStage.authenticated,
        user: user,
        isSubmitting: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      if (e.isRegistrationClosed) {
        state = state.copyWith(
          stage: AuthStage.unauthenticated,
          isSubmitting: false,
          error: e,
        );
      } else {
        state = state.copyWith(isSubmitting: false, error: e);
      }
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final User user = await _repository.login(
        email: email,
        password: password,
      );
      state = state.copyWith(
        stage: AuthStage.authenticated,
        user: user,
        isSubmitting: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return false;
    }
  }

  Future<User?> updateProfile({
    String? displayName,
    String? timezone,
  }) async {
    final User updated = await _repository.updateProfile(
      displayName: displayName,
      timezone: timezone,
    );
    state = state.copyWith(user: updated);
    return updated;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    // API contract: POST /auth/change-password revokes all refresh tokens.
    await logout();
  }

  Future<void> logout() async {
    await _repository.logout();
    state = state.copyWith(
      stage: AuthStage.unauthenticated,
      clearUser: true,
      clearError: true,
    );
  }

  void handleSessionExpired() {
    if (state.stage == AuthStage.authenticated) {
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        clearUser: true,
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((Ref ref) {
      final AuthController controller = AuthController(
        ref.watch(authRepositoryProvider),
      );
      ref.listen<int>(sessionExpirationProvider, (int? prev, int next) {
        if (next > 0) {
          controller.handleSessionExpired();
        }
      });
      return controller;
    });
