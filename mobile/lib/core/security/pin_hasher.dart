import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinHasher {
  const PinHasher._();

  /// Generates a random 16-byte hex salt.
  static String generateSalt() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Computes a SHA-256 salted hash of the 6-digit PIN.
  static String hashPin(String pin, String salt) {
    final List<int> bytes = utf8.encode('monevo:$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Constant-time comparison of two hex hash strings.
  static bool verifyPin({
    required String inputPin,
    required String storedHash,
    required String storedSalt,
  }) {
    final String candidate = hashPin(inputPin, storedSalt);
    if (candidate.length != storedHash.length) {
      return false;
    }
    int diff = 0;
    for (int i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
