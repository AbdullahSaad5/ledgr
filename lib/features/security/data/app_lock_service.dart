import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ledgr/features/security/domain/pin_hasher.dart';
import 'package:local_auth/local_auth.dart';

/// Stores the app-lock PIN hash in platform secure storage and drives biometric
/// unlock. All platform calls are guarded so tests degrade to a no-op.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? auth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _kSalt = 'pin_salt';
  static const _kHash = 'pin_hash';

  Future<void> setPin(String pin) async {
    final hashed = PinHasher.hash(pin);
    try {
      await _storage.write(key: _kSalt, value: hashed.salt);
      await _storage.write(key: _kHash, value: hashed.hash);
    } on Object {
      // ignore: secure storage unavailable
    }
  }

  Future<bool> hasPin() async {
    try {
      return await _storage.read(key: _kHash) != null;
    } on Object {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final salt = await _storage.read(key: _kSalt);
      final hash = await _storage.read(key: _kHash);
      if (salt == null || hash == null) return false;
      return PinHasher.verify(pin, PinHash(salt: salt, hash: hash));
    } on Object {
      return false;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kSalt);
      await _storage.delete(key: _kHash);
    } on Object {
      // ignore
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      final canCheck =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return false;
      return await _auth.authenticate(
        localizedReason: 'Unlock Ledgr',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } on Object {
      return false;
    }
  }
}
