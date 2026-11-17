import 'dart:async';
import 'dart:convert';

import '../../models/models.dart';
import '../crypto/e2e_crypto.dart';
import 'transport.dart';

enum SecureState { connecting, handshaking, secure, failed, closed }

/// Runs the authenticated key exchange over a [PeerTransport] and then
/// exchanges AES-GCM sealed JSON payloads.
class SecureChannel {
  final PeerTransport transport;
  final IdentityKey identity;
  final PeerProfile peer;

  final _payloads = StreamController<Map<String, dynamic>>.broadcast();
  final _states = StreamController<SecureState>.broadcast();
  final List<Map<String, dynamic>> _queue = [];
  SessionCipher? _cipher;
  SecureState _state = SecureState.connecting;
  String? error;
  final List<StreamSubscription> _subs = [];
  Future<void> _chain = Future.value();

  SecureChannel({required this.transport, required this.identity, required this.peer}) {
    _subs.add(transport.incoming.listen((raw) {
      // Process frames strictly in order (crypto calls are async).
      _chain = _chain.then((_) => _onFrame(raw));
    }));
    _subs.add(transport.stateChanges.listen(_onTransportState, onDone: () => _setState(SecureState.closed)));
    _init();
  }

  Stream<Map<String, dynamic>> get payloads => _payloads.stream;
  Stream<SecureState> get states => _states.stream;
  SecureState get state => _state;
  bool get isSecure => _state == SecureState.secure;

  Future<void> _init() async {
    _cipher = await SessionCipher.create(
      identity: identity,
      peerIdentityPublicKey: base64Decode(peer.publicKey),
      initiator: transport.initiator,
    );
    if (transport.state == TransportState.open) _sendHello();
    if (transport.state == TransportState.closed) _setState(SecureState.closed);
  }

  void _onTransportState(TransportState s) {
    if (s == TransportState.open && _cipher != null) _sendHello();
    if (s == TransportState.closed) _setState(SecureState.closed);
  }

  bool _helloSent = false;
  void _sendHello() {
    if (_helloSent) return;
    _helloSent = true;
    _setState(SecureState.handshaking);
    transport.send(jsonEncode({
      't': 'hello',
      'v': 1,
      'eph': base64Encode(_cipher!.ephemeralPublic),
      'id': identity.publicKeyBase64,
    }));
  }

  Future<void> _onFrame(String raw) async {
    if (_state == SecureState.failed || _state == SecureState.closed) return;
    try {
      final frame = jsonDecode(raw) as Map<String, dynamic>;
      while (_cipher == null) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      final cipher = _cipher!;
      switch (frame['t']) {
        case 'hello':
          if (frame['id'] != peer.publicKey) {
            return _fail('Identity key mismatch - possible interception.');
          }
          _sendHello();
          await cipher.completeHandshake(base64Decode(frame['eph'] as String));
          transport.send(jsonEncode(await cipher.seal(jsonEncode({'k': 'confirm'}))));
        case 'msg':
          final payload = jsonDecode(await cipher.open(frame)) as Map<String, dynamic>;
          if (payload['k'] == 'confirm') {
            _setState(SecureState.secure);
            for (final p in _queue) {
              await _sendNow(p);
            }
            _queue.clear();
          } else if (_state == SecureState.secure) {
            _payloads.add(payload);
          }
      }
    } on CryptoException catch (e) {
      _fail('Could not verify peer: ${e.message}');
    } catch (_) {
      // Malformed frame - ignore.
    }
  }

  Future<void> _sendNow(Map<String, dynamic> payload) async {
    transport.send(jsonEncode(await _cipher!.seal(jsonEncode(payload))));
  }

  Future<void> send(Map<String, dynamic> payload) async {
    if (_state == SecureState.secure) {
      _chain = _chain.then((_) => _sendNow(payload));
      await _chain;
    } else {
      _queue.add(payload);
    }
  }

  void _fail(String reason) {
    error = reason;
    _setState(SecureState.failed);
    transport.close();
  }

  void _setState(SecureState s) {
    if (_state == s) return;
    if ((_state == SecureState.failed || _state == SecureState.closed)) return;
    _state = s;
    if (!_states.isClosed) _states.add(s);
    if (s == SecureState.failed || s == SecureState.closed) {
      for (final sub in _subs) {
        sub.cancel();
      }
      _states.close();
      _payloads.close();
    }
  }

  Future<void> close() async {
    await transport.close();
    _setState(SecureState.closed);
  }
}
