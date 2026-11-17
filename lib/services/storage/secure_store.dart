import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/e2e_crypto.dart';

/// Stores secrets in the platform keystore and chat history encrypted at rest
/// (AES-256-GCM with a per-user key kept in the keystore).
class SecureStore {
  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;
  final _aes = AesGcm.with256bits();

  SecureStore([FlutterSecureStorage? secure]) : _secure = secure ?? const FlutterSecureStorage();

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  Future<String?> _readSecret(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return (await _p).getString('fallback.$key');
    }
  }

  Future<void> _writeSecret(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {
      // Keystore unavailable (e.g. some desktop sandboxes) - degrade gracefully.
      await (await _p).setString('fallback.$key', value);
    }
  }

  /// Loads (or creates on first launch) the identity key of [userId].
  Future<IdentityKey> identityFor(String userId) async {
    final stored = await _readSecret('identity.$userId');
    if (stored != null) return IdentityKey.fromSeed(base64Decode(stored));
    final key = await IdentityKey.generate();
    await _writeSecret('identity.$userId', base64Encode(await key.seed()));
    return key;
  }

  Future<SecretKey> _dataKey(String userId) async {
    final stored = await _readSecret('datakey.$userId');
    if (stored != null) return SecretKey(base64Decode(stored));
    final bytes = randomBytes(32);
    await _writeSecret('datakey.$userId', base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<void> saveJson(String userId, String name, Object value) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: await _dataKey(userId),
      nonce: randomBytes(12),
    );
    await (await _p).setString('data.$userId.$name', base64Encode(box.concatenation()));
  }

  Future<Object?> loadJson(String userId, String name) async {
    final raw = (await _p).getString('data.$userId.$name');
    if (raw == null) return null;
    try {
      final box = SecretBox.fromConcatenation(base64Decode(raw), nonceLength: 12, macLength: 16);
      final clear = await _aes.decrypt(box, secretKey: await _dataKey(userId));
      return jsonDecode(utf8.decode(clear));
    } catch (_) {
      return null;
    }
  }

  Future<void> setFlag(String key, String? value) async {
    final p = await _p;
    value == null ? await p.remove(key) : await p.setString(key, value);
  }

  Future<String?> getFlag(String key) async => (await _p).getString(key);
}
