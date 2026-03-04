import 'dart:convert';

import 'package:flutter_adb/adb_crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titancast/core/app_logger.dart';

const _tag = 'AdbKeyStore';

/// Persists a single RSA keypair used for all ADB-over-WiFi connections.
///
/// ADB identifies clients by their RSA public key. Generating a fresh key
/// each time means the device never recognises the app and either shows
/// the authorisation dialog on every launch or — on projectors/TV-boxes
/// that don't show the dialog over WiFi — refuses the connection silently.
///
/// Usage:
///   ```dart
///   _crypto = await AdbKeyStore.loadOrCreate();
///   ```
class AdbKeyStore {
  static const String _prefKey = 'adb_rsa_keypair_v1';

  /// Returns a persisted [AdbCrypto] with a stable RSA keypair.
  ///
  /// Generates and saves a new keypair on first call.
  /// On subsequent calls the same keypair is deserialized from
  /// SharedPreferences, so the device always sees the same public key.
  static Future<AdbCrypto> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);

    if (stored != null) {
      try {
        final map = jsonDecode(stored) as Map<String, dynamic>;
        final n = BigInt.parse(map['n'] as String, radix: 16);
        final e = BigInt.parse(map['e'] as String, radix: 16);
        final d = BigInt.parse(map['d'] as String, radix: 16);
        final p = BigInt.parse(map['p'] as String, radix: 16);
        final q = BigInt.parse(map['q'] as String, radix: 16);
        final keyPair = AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
          RSAPublicKey(n, e),
          RSAPrivateKey(n, d, p, q),
        );
        AppLogger.d(_tag, 'loaded persisted RSA keypair (n=${n.bitLength} bits)');
        return AdbCrypto(keyPair: keyPair);
      } catch (e) {
        AppLogger.w(_tag, 'failed to deserialize stored keypair ($e) — regenerating');
      }
    }

    AppLogger.i(_tag, 'generating new RSA keypair (first run or corrupt store)');
    final keyPair = AdbCrypto.generateAdbKeyPair();
    final map = {
      'n': keyPair.publicKey.modulus!.toRadixString(16),
      'e': keyPair.publicKey.publicExponent!.toRadixString(16),
      'd': keyPair.privateKey.privateExponent!.toRadixString(16),
      'p': keyPair.privateKey.p!.toRadixString(16),
      'q': keyPair.privateKey.q!.toRadixString(16),
    };
    await prefs.setString(_prefKey, jsonEncode(map));
    AppLogger.i(_tag, 'new keypair generated and persisted');
    return AdbCrypto(keyPair: keyPair);
  }

  /// Clears the stored keypair so a fresh one is generated on next call.
  /// Call this if the user explicitly wants to "reset" ADB authorisation.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    AppLogger.i(_tag, 'persisted keypair cleared');
  }
}
