import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Long-lived X25519 identity key of a user. The public half is published to
/// the user directory so peers can authenticate the handshake.
class IdentityKey {
  final SimpleKeyPair keyPair;
  final List<int> publicKey;

  IdentityKey._(this.keyPair, this.publicKey);

  static final _x25519 = X25519();

  static Future<IdentityKey> generate() async {
    final kp = await _x25519.newKeyPair();
    final pub = await kp.extractPublicKey();
    return IdentityKey._(kp, pub.bytes);
  }

  static Future<IdentityKey> fromSeed(List<int> seed) async {
    final kp = await _x25519.newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return IdentityKey._(kp, pub.bytes);
  }

  Future<List<int>> seed() => keyPair.extractPrivateKeyBytes();

  String get publicKeyBase64 => base64Encode(publicKey);
}

/// Thrown when a peer's frame cannot be authenticated.
class CryptoException implements Exception {
  final String message;
  CryptoException(this.message);
  @override
  String toString() => 'CryptoException: $message';
}

/// Authenticated key agreement + AEAD for one peer-to-peer session.
///
/// Handshake (both sides send `hello` with a fresh ephemeral X25519 key):
///
/// ```
///   dh1 = DH(eph_I,  eph_R)     -> forward secrecy
///   dh2 = DH(id_I,   eph_R)     -> authenticates the initiator
///   dh3 = DH(eph_I,  id_R)      -> authenticates the responder
///   k_I->R, k_R->I = HKDF-SHA256(dh1 || dh2 || dh3, salt = eph_I || eph_R)
/// ```
///
/// Identity public keys are taken from the user directory (never from the
/// wire), so a man-in-the-middle cannot complete the handshake without the
/// victims' identity private keys. Users can additionally compare a safety
/// number out of band.
///
/// Every frame is sealed with AES-256-GCM using a random 96-bit nonce and a
/// monotonically increasing counter bound in the associated data, which
/// rejects replayed and reordered frames.
class SessionCipher {
  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();

  final IdentityKey identity;
  final List<int> peerIdentityPublicKey;
  final bool initiator;

  late final SimpleKeyPair _ephemeral;
  late final List<int> ephemeralPublic;

  SecretKey? _sendKey;
  SecretKey? _recvKey;
  int _sendCounter = 0;
  int _recvCounter = -1;

  SessionCipher._(this.identity, this.peerIdentityPublicKey, this.initiator);

  static Future<SessionCipher> create({
    required IdentityKey identity,
    required List<int> peerIdentityPublicKey,
    required bool initiator,
  }) async {
    final c = SessionCipher._(identity, peerIdentityPublicKey, initiator);
    c._ephemeral = await _x25519.newKeyPair();
    c.ephemeralPublic = (await c._ephemeral.extractPublicKey()).bytes;
    return c;
  }

  bool get ready => _sendKey != null;

  Future<List<int>> _dh(SimpleKeyPair mine, List<int> theirs) async {
    final s = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(theirs, type: KeyPairType.x25519),
    );
    return s.extractBytes();
  }

  /// Derives the directional session keys from the peer's ephemeral key.
  Future<void> completeHandshake(List<int> peerEphemeral) async {
    final List<int> dh1, dh2, dh3;
    if (initiator) {
      dh1 = await _dh(_ephemeral, peerEphemeral);
      dh2 = await _dh(identity.keyPair, peerEphemeral);
      dh3 = await _dh(_ephemeral, peerIdentityPublicKey);
    } else {
      dh1 = await _dh(_ephemeral, peerEphemeral);
      dh2 = await _dh(_ephemeral, peerIdentityPublicKey);
      dh3 = await _dh(identity.keyPair, peerEphemeral);
    }
    final ikm = [...dh1, ...dh2, ...dh3];
    final salt = initiator ? [...ephemeralPublic, ...peerEphemeral] : [...peerEphemeral, ...ephemeralPublic];

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final kIR = await hkdf.deriveKey(
        secretKey: SecretKey(ikm), nonce: salt, info: utf8.encode('cipherly/v1/I->R'));
    final kRI = await hkdf.deriveKey(
        secretKey: SecretKey(ikm), nonce: salt, info: utf8.encode('cipherly/v1/R->I'));
    _sendKey = initiator ? kIR : kRI;
    _recvKey = initiator ? kRI : kIR;
  }

  static List<int> _nonce() {
    final r = Random.secure();
    return List<int>.generate(12, (_) => r.nextInt(256));
  }

  List<int> _aad(int counter, bool fromInitiator) =>
      utf8.encode('cipherly/v1|${fromInitiator ? 'I' : 'R'}|$counter');

  /// Encrypts [plaintext] into a JSON-serialisable frame.
  Future<Map<String, dynamic>> seal(String plaintext) async {
    final key = _sendKey;
    if (key == null) throw CryptoException('Handshake not complete');
    final counter = _sendCounter++;
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: _nonce(),
      aad: _aad(counter, initiator),
    );
    return {
      't': 'msg',
      'c': counter,
      'n': base64Encode(box.nonce),
      'd': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
  }

  /// Authenticates and decrypts a frame produced by the peer's [seal].
  Future<String> open(Map<String, dynamic> frame) async {
    final key = _recvKey;
    if (key == null) throw CryptoException('Handshake not complete');
    final counter = frame['c'] as int;
    if (counter <= _recvCounter) throw CryptoException('Replayed frame rejected');
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          base64Decode(frame['d'] as String),
          nonce: base64Decode(frame['n'] as String),
          mac: Mac(base64Decode(frame['m'] as String)),
        ),
        secretKey: key,
        aad: _aad(counter, !initiator),
      );
      _recvCounter = counter;
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw CryptoException('Frame failed authentication');
    }
  }
}

/// Human-comparable safety number for two identity keys (order independent).
Future<String> safetyNumber(List<int> a, List<int> b) async {
  final ka = base64Encode(a), kb = base64Encode(b);
  final ordered = ka.compareTo(kb) <= 0 ? [...a, ...b] : [...b, ...a];
  final hash = (await Sha512().hash(ordered)).bytes;
  final groups = <String>[];
  for (var i = 0; i < 12; i++) {
    final chunk = hash.sublist(i * 5, i * 5 + 5);
    var v = 0;
    for (final byte in chunk) {
      v = (v * 256 + byte) % 100000;
    }
    groups.add(v.toString().padLeft(5, '0'));
  }
  return groups.join(' ');
}

/// Short fingerprint of a single key, e.g. `3F:A2:...`.
Future<String> fingerprint(List<int> publicKey) async {
  final hash = (await Sha256().hash(publicKey)).bytes;
  return hash
      .take(10)
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

Uint8List randomBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
}
