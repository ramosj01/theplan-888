import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/backend.dart';
import '../services/crypto/e2e_crypto.dart';
import '../services/p2p/secure_channel.dart';
import '../services/p2p/transport.dart';

class ContactNotFound implements Exception {
  final String email;
  ContactNotFound(this.email);
  @override
  String toString() => 'No Cipherly user is registered with $email yet.';
}

/// Owns contacts, conversations and the live encrypted peer links.
class ChatController extends ChangeNotifier {
  final Backend backend;
  final AppUser user;

  late IdentityKey identity;
  final List<PeerProfile> contacts = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, SecureChannel> _channels = {};
  final Map<String, LinkState> _links = {};
  final Map<String, String> linkErrors = {};
  final Set<String> typing = {};
  final Map<String, int> unread = {};
  Set<String> online = {};
  String? activePeer;
  bool ready = false;

  final List<StreamSubscription> _subs = [];
  Timer? _saveDebounce;

  ChatController(this.backend, this.user);

  List<ChatMessage> messagesFor(String peerId) => _messages[peerId] ?? const [];
  LinkState linkState(String peerId) => _links[peerId] ?? LinkState.offline;
  PeerProfile? contact(String id) => contacts.where((c) => c.id == id).firstOrNull;

  ChatMessage? lastMessage(String peerId) {
    final m = _messages[peerId];
    return (m == null || m.isEmpty) ? null : m.last;
  }

  /// Contacts ordered by most recent activity.
  List<PeerProfile> get sortedContacts {
    final list = [...contacts];
    list.sort((a, b) {
      final ta = lastMessage(a.id)?.timestamp ?? DateTime(2000);
      final tb = lastMessage(b.id)?.timestamp ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    return list;
  }

  Future<void> start() async {
    identity = await backend.store.identityFor(user.id);
    Backend.registerMyKey(identity.publicKeyBase64);
    await backend.directory.publish(user, identity.publicKeyBase64);
    await _load();

    await backend.signaling.start(user.id);
    online = backend.signaling.online;
    _subs.add(backend.signaling.presence.listen((ids) {
      online = ids;
      notifyListeners();
    }));
    await backend.links.start(user.id);
    _subs.add(backend.links.incoming.listen(_onIncomingTransport));

    if (backend.demo && contacts.isEmpty) {
      for (final id in backend.signaling.online) {
        final p = await backend.directory.findById(id);
        if (p != null) contacts.add(p);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _load() async {
    final c = await backend.store.loadJson(user.id, 'contacts');
    if (c is List) {
      contacts.addAll(c.map((e) => PeerProfile.fromJson(Map<String, dynamic>.from(e as Map))));
    }
    final m = await backend.store.loadJson(user.id, 'messages');
    if (m is List) {
      for (final e in m) {
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(e as Map));
        if (msg.status == MessageStatus.sending) msg.status = MessageStatus.failed;
        _messages.putIfAbsent(msg.peerId, () => []).add(msg);
      }
    }
  }

  void _save() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () async {
      await backend.store.saveJson(user.id, 'contacts', contacts.map((c) => c.toJson()).toList());
      await backend.store.saveJson(user.id, 'messages',
          _messages.values.expand((l) => l).map((m) => m.toJson()).toList());
    });
  }

  /// Finds a user by e-mail, adds them as a contact and opens a link.
  Future<PeerProfile> addContactByEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e == user.email.toLowerCase()) throw ContactNotFound(e);
    final existing = contacts.where((c) => c.email == e).firstOrNull;
    if (existing != null) return existing;
    final p = await backend.directory.findByEmail(e);
    if (p == null) throw ContactNotFound(e);
    contacts.add(p);
    _save();
    notifyListeners();
    connect(p.id);
    return p;
  }

  void removeContact(String peerId) {
    _channels.remove(peerId)?.close();
    contacts.removeWhere((c) => c.id == peerId);
    _messages.remove(peerId);
    _links.remove(peerId);
    _save();
    notifyListeners();
  }

  /// Opens (or reuses) an encrypted peer-to-peer link.
  void connect(String peerId) {
    final existing = _channels[peerId];
    if (existing != null &&
        existing.state != SecureState.closed &&
        existing.state != SecureState.failed) {
      return;
    }
    final peer = contact(peerId);
    if (peer == null) return;
    _attach(backend.links.dial(peerId), peer);
  }

  Future<void> _onIncomingTransport(PeerTransport t) async {
    var peer = contact(t.peerId);
    if (peer == null) {
      // A new person reached out: look them up to learn their identity key.
      peer = await backend.directory.findById(t.peerId);
      if (peer == null) {
        await t.close();
        return;
      }
      contacts.add(peer);
      _save();
    }
    _channels.remove(peer.id)?.close();
    _attach(t, peer);
  }

  void _attach(PeerTransport t, PeerProfile peer) {
    final ch = SecureChannel(transport: t, identity: identity, peer: peer);
    _channels[peer.id] = ch;
    linkErrors.remove(peer.id);
    _setLink(peer.id, LinkState.connecting);

    ch.states.listen((s) {
      if (_channels[peer.id] != ch) return;
      switch (s) {
        case SecureState.connecting:
          _setLink(peer.id, LinkState.connecting);
        case SecureState.handshaking:
          _setLink(peer.id, LinkState.handshaking);
        case SecureState.secure:
          _setLink(peer.id, LinkState.secure);
          _flushPending(peer.id);
        case SecureState.failed:
          linkErrors[peer.id] = ch.error ?? 'Connection failed';
          _setLink(peer.id, LinkState.failed);
        case SecureState.closed:
          _setLink(peer.id, _links[peer.id] == LinkState.secure ? LinkState.offline : LinkState.failed);
          if (!linkErrors.containsKey(peer.id) && _links[peer.id] == LinkState.failed) {
            linkErrors[peer.id] = 'Peer is unreachable right now.';
          }
          typing.remove(peer.id);
      }
    });
    ch.payloads.listen((p) => _onPayload(peer.id, ch, p));
  }

  void _setLink(String peerId, LinkState s) {
    _links[peerId] = s;
    notifyListeners();
  }

  void _onPayload(String peerId, SecureChannel ch, Map<String, dynamic> p) {
    switch (p['k']) {
      case 'text':
        final id = p['id'] as String;
        final list = _messages.putIfAbsent(peerId, () => []);
        if (!list.any((m) => m.id == id)) {
          list.add(ChatMessage(
            id: id,
            peerId: peerId,
            outgoing: false,
            text: p['body'] as String,
            timestamp: DateTime.now(),
          ));
          if (activePeer != peerId) unread[peerId] = (unread[peerId] ?? 0) + 1;
        }
        typing.remove(peerId);
        ch.send({'k': 'ack', 'id': id});
        _save();
      case 'ack':
        for (final m in messagesFor(peerId)) {
          if (m.id == p['id'] && m.outgoing) m.status = MessageStatus.delivered;
        }
        _save();
      case 'typing':
        p['on'] == true ? typing.add(peerId) : typing.remove(peerId);
    }
    notifyListeners();
  }

  void _flushPending(String peerId) {
    for (final m in messagesFor(peerId)) {
      if (m.outgoing && (m.status == MessageStatus.sending || m.status == MessageStatus.failed)) {
        _transmit(m);
      }
    }
  }

  Future<void> _transmit(ChatMessage m) async {
    final ch = _channels[m.peerId];
    if (ch == null || !ch.isSecure) return;
    m.status = MessageStatus.sending;
    await ch.send({
      'k': 'text',
      'id': m.id,
      'body': m.text,
      'ts': m.timestamp.millisecondsSinceEpoch,
    });
    if (m.status == MessageStatus.sending) m.status = MessageStatus.sent;
    _save();
    notifyListeners();
  }

  void sendText(String peerId, String text) {
    final body = text.trim();
    if (body.isEmpty) return;
    final m = ChatMessage(
      id: randomId(),
      peerId: peerId,
      outgoing: true,
      text: body,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    _messages.putIfAbsent(peerId, () => []).add(m);
    notifyListeners();
    _save();
    if (linkState(peerId) == LinkState.secure) {
      _transmit(m);
    } else {
      connect(peerId);
    }
  }

  void retry(ChatMessage m) {
    m.status = MessageStatus.sending;
    notifyListeners();
    linkState(m.peerId) == LinkState.secure ? _transmit(m) : connect(m.peerId);
  }

  DateTime _lastTyping = DateTime(2000);
  void notifyTyping(String peerId, bool on) {
    final ch = _channels[peerId];
    if (ch == null || !ch.isSecure) return;
    final now = DateTime.now();
    if (on && now.difference(_lastTyping) < const Duration(seconds: 2)) return;
    _lastTyping = on ? now : DateTime(2000);
    ch.send({'k': 'typing', 'on': on});
  }

  void openConversation(String peerId) {
    activePeer = peerId;
    unread.remove(peerId);
    notifyListeners();
    connect(peerId);
  }

  void closeConversation() {
    activePeer = null;
  }

  Future<String> safetyNumberWith(String peerId) async {
    final p = contact(peerId)!;
    return safetyNumber(identity.publicKey, _b64(p.publicKey));
  }

  Future<String> myFingerprint() => fingerprint(identity.publicKey);
  Future<String> peerFingerprint(String peerId) => fingerprint(_b64(contact(peerId)!.publicKey));

  static List<int> _b64(String s) => base64Decode(s);

  Future<void> shutdown() async {
    _saveDebounce?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    for (final c in _channels.values) {
      await c.close();
    }
    _channels.clear();
    await backend.links.stop();
    await backend.signaling.stop();
  }
}
