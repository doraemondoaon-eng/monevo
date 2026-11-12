import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorageService {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();

  Future<String?> getPinHash();
  Future<String?> getPinSalt();
  Future<void> savePinHash({required String hash, required String salt});
  Future<void> clearPin();
}

class FlutterSecureStorageService implements SecureStorageService {
  const FlutterSecureStorageService([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  static const String _keyAccessToken = 'monevo_access_token';
  static const String _keyRefreshToken = 'monevo_refresh_token';
  static const String _keyPinHash = 'monevo_pin_hash';
  static const String _keyPinSalt = 'monevo_pin_salt';

  @override
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  @override
  Future<String?> getPinHash() => _storage.read(key: _keyPinHash);

  @override
  Future<String?> getPinSalt() => _storage.read(key: _keyPinSalt);

  @override
  Future<void> savePinHash({
    required String hash,
    required String salt,
  }) async {
    await _storage.write(key: _keyPinHash, value: hash);
    await _storage.write(key: _keyPinSalt, value: salt);
  }

  @override
  Future<void> clearPin() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
  }
}

/// In-memory implementation useful for tests or fallback environments.
class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getAccessToken() async => _store['accessToken'];

  @override
  Future<String?> getRefreshToken() async => _store['refreshToken'];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _store['accessToken'] = accessToken;
    _store['refreshToken'] = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _store.remove('accessToken');
    _store.remove('refreshToken');
  }

  @override
  Future<String?> getPinHash() async => _store['pinHash'];

  @override
  Future<String?> getPinSalt() async => _store['pinSalt'];

  @override
  Future<void> savePinHash({
    required String hash,
    required String salt,
  }) async {
    _store['pinHash'] = hash;
    _store['pinSalt'] = salt;
  }

  @override
  Future<void> clearPin() async {
    _store.remove('pinHash');
    _store.remove('pinSalt');
  }
}

final Provider<SecureStorageService> secureStorageProvider =
    Provider<SecureStorageService>((Ref ref) {
      return const FlutterSecureStorageService();
    });
