import 'dart:async';

import 'package:cipherly/models/models.dart';
import 'package:cipherly/services/crypto/e2e_crypto.dart';
import 'package:cipherly/services/demo/demo_backend.dart';
import 'package:cipherly/services/p2p/secure_channel.dart';
import 'package:flutter_test/flutter_test.dart';

PeerProfile _profile(String id, IdentityKey k) =>
    PeerProfile(id: id, email: '$id@x.io', displayName: id, publicKey: k.publicKeyBase64);

void main() {
  test('session cipher round trip and replay rejection', () async {
    final a = await IdentityKey.generate();
    final b = await IdentityKey.generate();
    final ia = await SessionCipher.create(identity: a, peerIdentityPublicKey: b.publicKey, initiator: true);
    final rb = await SessionCipher.create(identity: b, peerIdentityPublicKey: a.publicKey, initiator: false);
    await ia.completeHandshake(rb.ephemeralPublic);
    await rb.completeHandshake(ia.ephemeralPublic);

    final f = await ia.seal('hello bob');
    expect(f['d'], isNot(contains('hello')));
    expect(await rb.open(f), 'hello bob');
    expect(() => rb.open(f), throwsA(isA<CryptoException>()));
    expect(await ia.open(await rb.seal('hi alice')), 'hi alice');
  });

  test('wrong identity key cannot complete handshake', () async {
    final a = await IdentityKey.generate();
    final b = await IdentityKey.generate();
    final mallory = await IdentityKey.generate();
    // Alice believes she talks to Bob, but Mallory answers with her own key.
    final ia = await SessionCipher.create(identity: a, peerIdentityPublicKey: b.publicKey, initiator: true);
    final rm = await SessionCipher.create(identity: mallory, peerIdentityPublicKey: a.publicKey, initiator: false);
    await ia.completeHandshake(rm.ephemeralPublic);
    await rm.completeHandshake(ia.ephemeralPublic);
    expect(() async => rm.open(await ia.seal('secret')), throwsA(isA<CryptoException>()));
  });

  test('safety number is symmetric', () async {
    final a = await IdentityKey.generate();
    final b = await IdentityKey.generate();
    final s1 = await safetyNumber(a.publicKey, b.publicKey);
    expect(s1, await safetyNumber(b.publicKey, a.publicKey));
    expect(s1.split(' ').length, 12);
  });

  test('secure channels exchange payloads over a transport', () async {
    final a = await IdentityKey.generate();
    final b = await IdentityKey.generate();
    final (ta, tb) = MemoryTransport.pair('alice', 'bob');
    final ca = SecureChannel(transport: ta, identity: a, peer: _profile('bob', b));
    final cb = SecureChannel(transport: tb, identity: b, peer: _profile('alice', a));
    final got = Completer<Map<String, dynamic>>();
    cb.payloads.listen(got.complete);
    await ca.send({'k': 'text', 'body': 'p2p works'});
    final p = await got.future.timeout(const Duration(seconds: 5));
    expect(p['body'], 'p2p works');
    expect(ca.isSecure && cb.isSecure, isTrue);
  });
}
