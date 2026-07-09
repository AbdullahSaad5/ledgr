import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A salted PIN hash for at-rest verification. Never store the PIN itself.
class PinHash {
  const PinHash({required this.salt, required this.hash});
  final String salt;
  final String hash;
}

/// Salted SHA-256 hashing of the app-lock PIN (pure, unit-testable).
abstract final class PinHasher {
  /// Hash [pin] with [salt] (a random salt is generated when omitted).
  static PinHash hash(String pin, {String? salt}) {
    final actualSalt = salt ?? _randomSalt();
    final digest = sha256.convert(utf8.encode('$actualSalt:$pin'));
    return PinHash(salt: actualSalt, hash: digest.toString());
  }

  /// True when [pin] matches [stored].
  static bool verify(String pin, PinHash stored) {
    final computed = sha256.convert(utf8.encode('${stored.salt}:$pin'));
    return computed.toString() == stored.hash;
  }

  static String _randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
