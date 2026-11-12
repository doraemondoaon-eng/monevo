import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../domain/backup_models.dart';

/// Pure-Dart authenticated encryption (PBKDF2-HMAC-SHA256 + SHA256-CTR stream
/// cipher + Encrypt-then-MAC HMAC-SHA256) for password-protected local backups.
class BackupCrypto {
  const BackupCrypto._();

  static const String encryptedSchema = 'com.monevo.encrypted_backup';
  static const int _pbkdf2Iterations = 12000;

  static bool isEncryptedJsonMap(Map<String, dynamic> map) {
    return map['schema'] == encryptedSchema && map['encrypted'] == true;
  }

  static Map<String, dynamic> encryptToEnvelope({
    required Uint8List plaintextBytes,
    required String password,
  }) {
    final Random rng = Random.secure();
    final Uint8List salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );
    final Uint8List nonce = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );

    final _DerivedKeys keys = _deriveKeys(
      password: password,
      salt: salt,
      iterations: _pbkdf2Iterations,
    );

    final Uint8List ciphertext = _xorKeystream(
      input: plaintextBytes,
      encKey: keys.encKey,
      nonce: nonce,
    );

    final Uint8List mac = _computeMac(
      macKey: keys.macKey,
      iterations: _pbkdf2Iterations,
      salt: salt,
      nonce: nonce,
      ciphertext: ciphertext,
    );

    return <String, dynamic>{
      'schema': encryptedSchema,
      'backupFormatVersion': BackupPayload.currentFormatVersion,
      'encrypted': true,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
    };
  }

  static Uint8List decryptFromEnvelope({
    required Map<String, dynamic> envelope,
    required String password,
  }) {
    try {
      final int iterations =
          (envelope['iterations'] as num?)?.toInt() ?? _pbkdf2Iterations;
      final Uint8List salt = base64Decode((envelope['salt'] ?? '').toString());
      final Uint8List nonce = base64Decode(
        (envelope['nonce'] ?? '').toString(),
      );
      final Uint8List ciphertext = base64Decode(
        (envelope['ciphertext'] ?? '').toString(),
      );
      final Uint8List expectedMac = base64Decode(
        (envelope['mac'] ?? '').toString(),
      );

      if (salt.length != 16 || nonce.length != 16 || expectedMac.length != 32) {
        throw const BackupCorruptedException(
          'Invalid encryption header parameters.',
        );
      }

      final _DerivedKeys keys = _deriveKeys(
        password: password,
        salt: salt,
        iterations: iterations,
      );

      final Uint8List actualMac = _computeMac(
        macKey: keys.macKey,
        iterations: iterations,
        salt: salt,
        nonce: nonce,
        ciphertext: ciphertext,
      );

      if (!_constantTimeEquals(actualMac, expectedMac)) {
        throw const BackupInvalidPasswordException();
      }

      return _xorKeystream(
        input: ciphertext,
        encKey: keys.encKey,
        nonce: nonce,
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupCorruptedException(
        'Encrypted backup envelope could not be decoded.',
      );
    }
  }

  static _DerivedKeys _deriveKeys({
    required String password,
    required Uint8List salt,
    required int iterations,
  }) {
    final Uint8List passwordBytes = Uint8List.fromList(utf8.encode(password));
    final Uint8List block1 = _pbkdf2Block(
      passwordBytes: passwordBytes,
      salt: salt,
      iterations: iterations,
      blockIndex: 1,
    );
    final Uint8List block2 = _pbkdf2Block(
      passwordBytes: passwordBytes,
      salt: salt,
      iterations: iterations,
      blockIndex: 2,
    );
    return _DerivedKeys(encKey: block1, macKey: block2);
  }

  static Uint8List _pbkdf2Block({
    required Uint8List passwordBytes,
    required Uint8List salt,
    required int iterations,
    required int blockIndex,
  }) {
    final Hmac hmac = Hmac(sha256, passwordBytes);
    final Uint8List saltAndIndex = Uint8List(salt.length + 4);
    saltAndIndex.setRange(0, salt.length, salt);
    saltAndIndex[salt.length] = (blockIndex >> 24) & 0xff;
    saltAndIndex[salt.length + 1] = (blockIndex >> 16) & 0xff;
    saltAndIndex[salt.length + 2] = (blockIndex >> 8) & 0xff;
    saltAndIndex[salt.length + 3] = blockIndex & 0xff;

    List<int> u = hmac.convert(saltAndIndex).bytes;
    final Uint8List out = Uint8List.fromList(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static Uint8List _xorKeystream({
    required Uint8List input,
    required Uint8List encKey,
    required Uint8List nonce,
  }) {
    final Hmac hmac = Hmac(sha256, encKey);
    final Uint8List out = Uint8List(input.length);
    final Uint8List counterBlock = Uint8List(nonce.length + 4);
    counterBlock.setRange(0, nonce.length, nonce);

    int offset = 0;
    int counter = 1;
    while (offset < input.length) {
      counterBlock[nonce.length] = (counter >> 24) & 0xff;
      counterBlock[nonce.length + 1] = (counter >> 16) & 0xff;
      counterBlock[nonce.length + 2] = (counter >> 8) & 0xff;
      counterBlock[nonce.length + 3] = counter & 0xff;

      final List<int> streamBlock = hmac.convert(counterBlock).bytes;
      final int chunk = min(32, input.length - offset);
      for (int i = 0; i < chunk; i++) {
        out[offset + i] = input[offset + i] ^ streamBlock[i];
      }
      offset += chunk;
      counter++;
    }
    return out;
  }

  static Uint8List _computeMac({
    required Uint8List macKey,
    required int iterations,
    required Uint8List salt,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) {
    final Hmac hmac = Hmac(sha256, macKey);
    final BytesBuilder builder = BytesBuilder(copy: false)
      ..add(utf8.encode(encryptedSchema))
      ..add(<int>[
        (iterations >> 24) & 0xff,
        (iterations >> 16) & 0xff,
        (iterations >> 8) & 0xff,
        iterations & 0xff,
      ])
      ..add(salt)
      ..add(nonce)
      ..add(ciphertext);
    return Uint8List.fromList(hmac.convert(builder.toBytes()).bytes);
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _DerivedKeys {
  const _DerivedKeys({required this.encKey, required this.macKey});

  final Uint8List encKey;
  final Uint8List macKey;
}

