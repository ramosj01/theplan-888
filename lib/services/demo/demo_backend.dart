import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../models/models.dart';
import '../crypto/e2e_crypto.dart';
import '../directory/user_directory.dart';
import '../p2p/secure_channel.dart';
import '../p2p/transport.dart';
import '../signaling/signaling_service.dart';

/// In-memory transport pair with a little simulated latency.
class MemoryTransport extends BaseTransport {
  MemoryTransport? other;
  MemoryTransport(super.peerId, super.initiator);

  static (MemoryTransport, MemoryTransport) pair(String aId, String bId) {
    final a = MemoryTransport(bId, true); // a talks to b
    final b = MemoryTransport(aId, false);
    a.other = b;
    b.other = a;
    Future.delayed(const Duration(milliseconds: 500), () {
      a.setState(TransportState.open);
      b.setState(TransportState.open);
    });
    return (a, b);
  }

  @override
  void rawSend(String text) {
    Future.delayed(const Duration(milliseconds: 40), () => other?.deliver(text));
  }

  @override
  Future<void> close() async {
    setState(TransportState.closed);
    other?.setState(TransportState.closed);
  }
}

/// A scripted peer that performs the real encrypted handshake and chats back.
class DemoBot {
  final PeerProfile profile;
  final IdentityKey identity;
  final List<String> replies;
  int _i = 0;

  DemoBot(this.profile, this.identity, this.replies);

  void accept(PeerTransport transport, PeerProfile user) {
    final ch = SecureChannel(transport: transport, identity: identity, peer: user);
    ch.payloads.listen((p) async {
      if (p['k'] != 'text') return;
      await ch.send({'k': 'ack', 'id': p['id']});
      await Future.delayed(const Duration(milliseconds: 600));
      await ch.send({'k': 'typing', 'on': true});
      final text = _reply(p['body'] as String);
      await Future.delayed(Duration(milliseconds: 900 + min(text.length * 18, 1600)));
      await ch.send({'k': 'typing', 'on': false});
      await ch.send({
        'k': 'text',
        'id': randomId(),
        'body': text,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  String _reply(String incoming) {
    final l = incoming.toLowerCase();
    if (l.contains('encrypt') || l.contains('secure') || l.contains('safe')) {
      return 'Every message is sealed with AES-256-GCM using keys from an X25519 handshake. '
          'Tap the shield icon to compare our safety number 🔐';
    }
    if (l.contains('hello') || l.contains('hi') || l.contains('hey')) {
      return 'Hey! 👋 We are connected peer-to-peer.';
    }
    final r = replies[_i % replies.length];
    _i++;
    return r;
  }
}

class DemoLinkFactory implements PeerLinkFactory {
  final Map<String, DemoBot> bots;
  final PeerProfile Function() me;
  final _incoming = StreamController<PeerTransport>.broadcast();

  DemoLinkFactory(this.bots, this.me);

  @override
  Stream<PeerTransport> get incoming => _incoming.stream;

  @override
  Future<void> start(String myUserId) async {}

  @override
  PeerTransport dial(String peerId) {
    final bot = bots[peerId];
    final (mine, theirs) = MemoryTransport.pair(me().id, peerId);
    if (bot == null) {
      // Unknown peer in demo mode: never answers.
      Future.delayed(const Duration(seconds: 4), mine.close);
    } else {
      bot.accept(theirs, me());
    }
    return mine;
  }

  @override
  Future<void> stop() async {}
}

class DemoSignalingService implements SignalingService {
  final Set<String> _online;
  DemoSignalingService(this._online);

  @override
  Stream<SignalMessage> get messages => const Stream.empty();
  @override
  Stream<Set<String>> get presence => const Stream.empty();
  @override
  Set<String> get online => _online;
  @override
  Future<void> send(String toUserId, String type, Map<String, dynamic> data) async {}
  @override
  Future<void> start(String myUserId) async {}
  @override
  Future<void> stop() async {}
}

/// Builds the demo peers and registers them in [directory].
Future<Map<String, DemoBot>> createDemoBots(DemoUserDirectory directory) async {
  final specs = [
    (
      'bot-aurora',
      'aurora@cipherly.demo',
      'Aurora',
      [
        'This line is running over a direct peer link - no server can read it ✨',
        'Fun fact: my keys were generated on this device and never left it.',
        'Try closing the chat and reconnecting - a brand-new session key is negotiated each time.',
      ]
    ),
    (
      'bot-milo',
      'milo@cipherly.demo',
      'Milo',
      [
        'Got it! 📬',
        'Sounds great - talk soon.',
        'Haha, nice one 😄',
      ]
    ),
    (
      'bot-nova',
      'nova@cipherly.demo',
      'Nova',
      [
        'Message received loud and clear, and encrypted 🛰️',
        'I love how glossy this UI is.',
        'Ping me anytime!',
      ]
    ),
  ];
  final bots = <String, DemoBot>{};
  for (final (id, email, name, replies) in specs) {
    final key = await IdentityKey.fromSeed(utf8.encode(id.padRight(32, '#')).sublist(0, 32));
    final profile = PeerProfile(id: id, email: email, displayName: name, publicKey: key.publicKeyBase64);
    directory.add(profile);
    bots[id] = DemoBot(profile, key, replies);
  }
  return bots;
}
