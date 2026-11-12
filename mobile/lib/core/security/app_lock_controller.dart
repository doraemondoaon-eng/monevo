import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/preferences_service.dart';
import '../storage/secure_storage_service.dart';
import 'biometric_service.dart';
import 'pin_hasher.dart';

class AppLockState {
  const AppLockState({
    this.initialized = false,
    this.hasPin = false,
    this.isLocked = false,
    this.biometricSupported = false,
    this.biometricEnabled = false,
    this.autoLockSeconds = AppConfig.defaultAutoLockSeconds,
    this.failedAttempts = 0,
  });

  final bool initialized;
  final bool hasPin;
  final bool isLocked;
  final bool biometricSupported;
  final bool biometricEnabled;
  final int autoLockSeconds;
  final int failedAttempts;

  AppLockState copyWith({
    bool? initialized,
    bool? hasPin,
    bool? isLocked,
    bool? biometricSupported,
    bool? biometricEnabled,
    int? autoLockSeconds,
    int? failedAttempts,
  }) {
    return AppLockState(
      initialized: initialized ?? this.initialized,
      hasPin: hasPin ?? this.hasPin,
      isLocked: isLocked ?? this.isLocked,
      biometricSupported: biometricSupported ?? this.biometricSupported,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({
    required SecureStorageService secureStorage,
    required PreferencesService preferences,
    required BiometricService biometricService,
  }) : _secureStorage = secureStorage,
       _preferences = preferences,
       _biometricService = biometricService,
       super(const AppLockState()) {
    initialize();
  }

  final SecureStorageService _secureStorage;
  final PreferencesService _preferences;
  final BiometricService _biometricService;
  DateTime? _backgroundedAt;

  Future<void> initialize() async {
    final String? pinHash = await _secureStorage.getPinHash();
    final String? pinSalt = await _secureStorage.getPinSalt();
    final bool hasPin =
        pinHash != null &&
        pinHash.isNotEmpty &&
        pinSalt != null &&
        pinSalt.isNotEmpty;
    final bool bioSupported = await _biometricService.isAvailable();
    final bool bioEnabled = await _preferences.getBiometricEnabled();
    final int autoLockSeconds = await _preferences.getAutoLockSeconds();

    state = state.copyWith(
      initialized: true,
      hasPin: hasPin,
      isLocked: hasPin,
      biometricSupported: bioSupported,
      biometricEnabled: bioSupported && bioEnabled,
      autoLockSeconds: autoLockSeconds,
    );
  }

  void onAppBackgrounded() {
    if (state.hasPin) {
      _backgroundedAt = DateTime.now();
    }
  }

  void onAppResumed() {
    if (!state.hasPin || _backgroundedAt == null) {
      return;
    }
    final Duration elapsed = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (elapsed.inSeconds >= state.autoLockSeconds) {
      state = state.copyWith(isLocked: true);
    }
  }

  void lockNow() {
    if (state.hasPin) {
      state = state.copyWith(isLocked: true);
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final String? storedHash = await _secureStorage.getPinHash();
    final String? storedSalt = await _secureStorage.getPinSalt();
    if (storedHash == null || storedSalt == null) {
      state = state.copyWith(isLocked: false, hasPin: false, failedAttempts: 0);
      return true;
    }

    final bool valid = PinHasher.verifyPin(
      inputPin: pin,
      storedHash: storedHash,
      storedSalt: storedSalt,
    );

    if (valid) {
      state = state.copyWith(isLocked: false, failedAttempts: 0);
      return true;
    } else {
      state = state.copyWith(failedAttempts: state.failedAttempts + 1);
      return false;
    }
  }

  Future<bool> unlockWithBiometrics(String localizedReason) async {
    if (!state.biometricEnabled || !state.biometricSupported) {
      return false;
    }
    final bool authenticated = await _biometricService.authenticate(
      localizedReason: localizedReason,
    );
    if (authenticated) {
      state = state.copyWith(isLocked: false, failedAttempts: 0);
    }
    return authenticated;
  }

  Future<void> setPin(String pin) async {
    final String salt = PinHasher.generateSalt();
    final String hash = PinHasher.hashPin(pin, salt);
    await _secureStorage.savePinHash(hash: hash, salt: salt);
    state = state.copyWith(
      hasPin: true,
      isLocked: false,
      failedAttempts: 0,
    );
  }

  Future<void> removePin() async {
    await _secureStorage.clearPin();
    await _preferences.setBiometricEnabled(false);
    state = state.copyWith(
      hasPin: false,
      isLocked: false,
      biometricEnabled: false,
      failedAttempts: 0,
    );
  }

  Future<bool> setBiometricEnabled(
    bool enabled, {
    required String localizedReason,
  }) async {
    if (!state.biometricSupported || !state.hasPin) {
      return false;
    }
    if (enabled) {
      final bool verified = await _biometricService.authenticate(
        localizedReason: localizedReason,
      );
      if (!verified) {
        return false;
      }
    }
    await _preferences.setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
    return true;
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    await _preferences.setAutoLockSeconds(seconds);
    state = state.copyWith(autoLockSeconds: seconds);
  }
}

final StateNotifierProvider<AppLockController, AppLockState>
appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((Ref ref) {
      return AppLockController(
        secureStorage: ref.watch(secureStorageProvider),
        preferences: ref.watch(preferencesServiceProvider),
        biometricService: ref.watch(biometricServiceProvider),
      );
    });
