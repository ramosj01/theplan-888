import 'dart:async';

enum TransportState { opening, open, closed }

/// A bidirectional, ordered, reliable text pipe to a single peer.
abstract class PeerTransport {
  String get peerId;

  /// True when this side created the connection (offerer).
  bool get initiator;

  Stream<String> get incoming;
  TransportState get state;
  Stream<TransportState> get stateChanges;

  void send(String text);
  Future<void> close();
}

/// Creates outgoing transports and surfaces incoming ones.
abstract class PeerLinkFactory {
  Stream<PeerTransport> get incoming;
  Future<void> start(String myUserId);
  PeerTransport dial(String peerId);
  Future<void> stop();
}

/// Shared plumbing for transport implementations.
abstract class BaseTransport implements PeerTransport {
  @override
  final String peerId;
  @override
  final bool initiator;

  final _incoming = StreamController<String>.broadcast();
  final _state = StreamController<TransportState>.broadcast();
  final List<String> _buffer = [];
  TransportState _current = TransportState.opening;

  BaseTransport(this.peerId, this.initiator);

  @override
  Stream<String> get incoming => _incoming.stream;
  @override
  TransportState get state => _current;
  @override
  Stream<TransportState> get stateChanges => _state.stream;

  void deliver(String text) {
    if (!_incoming.isClosed) _incoming.add(text);
  }

  void setState(TransportState s) {
    if (_current == s || _current == TransportState.closed) return;
    _current = s;
    if (!_state.isClosed) _state.add(s);
    if (s == TransportState.open) {
      for (final m in _buffer) {
        rawSend(m);
      }
      _buffer.clear();
    }
    if (s == TransportState.closed) {
      _incoming.close();
      _state.close();
    }
  }

  void rawSend(String text);

  @override
  void send(String text) {
    if (_current == TransportState.open) {
      rawSend(text);
    } else if (_current == TransportState.opening) {
      _buffer.add(text);
    }
  }
}
