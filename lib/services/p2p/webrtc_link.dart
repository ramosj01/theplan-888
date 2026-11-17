import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/config.dart';
import '../../models/models.dart';
import '../signaling/signaling_service.dart';
import 'transport.dart';

/// WebRTC data channel transport. Media never flows; only a single ordered,
/// reliable data channel (DTLS-SRTP encrypted by WebRTC, with Cipherly's own
/// end-to-end layer on top).
class WebRtcTransport extends BaseTransport {
  final String sessionId;
  final RTCPeerConnection pc;
  RTCDataChannel? _channel;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteSet = false;

  WebRtcTransport(super.peerId, super.initiator, this.sessionId, this.pc) {
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        close();
      }
    };
  }

  void attachChannel(RTCDataChannel ch) {
    _channel = ch;
    ch.onMessage = (m) {
      if (!m.isBinary) deliver(m.text);
    };
    ch.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) setState(TransportState.open);
      if (s == RTCDataChannelState.RTCDataChannelClosed) close();
    };
    if (ch.state == RTCDataChannelState.RTCDataChannelOpen) setState(TransportState.open);
  }

  Future<void> setRemote(RTCSessionDescription d) async {
    await pc.setRemoteDescription(d);
    _remoteSet = true;
    for (final c in _pendingIce) {
      await pc.addCandidate(c);
    }
    _pendingIce.clear();
  }

  Future<void> addIce(RTCIceCandidate c) async {
    if (_remoteSet) {
      await pc.addCandidate(c);
    } else {
      _pendingIce.add(c);
    }
  }

  @override
  void rawSend(String text) => _channel?.send(RTCDataChannelMessage(text));

  @override
  Future<void> close() async {
    if (state == TransportState.closed) return;
    setState(TransportState.closed);
    try {
      await _channel?.close();
      await pc.close();
    } catch (_) {}
  }
}

class WebRtcLinkFactory implements PeerLinkFactory {
  final SignalingService signaling;
  final _incoming = StreamController<PeerTransport>.broadcast();
  final Map<String, WebRtcTransport> _sessions = {};
  StreamSubscription? _sub;
  late String _me;

  WebRtcLinkFactory(this.signaling);

  @override
  Stream<PeerTransport> get incoming => _incoming.stream;

  Map<String, dynamic> get _config => {
        'iceServers': AppConfig.iceServers,
        'sdpSemantics': 'unified-plan',
      };

  @override
  Future<void> start(String myUserId) async {
    _me = myUserId;
    _sub = signaling.messages.listen(_onSignal);
  }

  Future<WebRtcTransport> _newTransport(String peerId, bool initiator, String sid) async {
    final pc = await createPeerConnection(_config);
    final t = WebRtcTransport(peerId, initiator, sid, pc);
    _sessions[sid] = t;
    t.stateChanges.listen((s) {
      if (s == TransportState.closed) _sessions.remove(sid);
    }, onDone: () => _sessions.remove(sid));
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      signaling.send(peerId, 'ice', {
        'sid': sid,
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    return t;
  }

  @override
  PeerTransport dial(String peerId) {
    final sid = randomId(12);
    late WebRtcTransport transport;
    final proxy = _DeferredTransport(peerId, true);
    () async {
      try {
        transport = await _newTransport(peerId, true, sid);
        proxy.bind(transport);
        final ch = await transport.pc
            .createDataChannel('cipherly', RTCDataChannelInit()..ordered = true);
        transport.attachChannel(ch);
        final offer = await transport.pc.createOffer();
        await transport.pc.setLocalDescription(offer);
        await signaling.send(peerId, 'offer', {'sid': sid, 'sdp': offer.sdp, 'type': offer.type});
        // Give up if the peer never answers.
        Future.delayed(const Duration(seconds: 30), () {
          if (transport.state == TransportState.opening) transport.close();
        });
      } catch (e) {
        debugPrint('dial failed: $e');
        proxy.close();
      }
    }();
    return proxy;
  }

  Future<void> _onSignal(SignalMessage m) async {
    final sid = m.data['sid'] as String?;
    if (sid == null) return;
    try {
      switch (m.type) {
        case 'offer':
          // Glare: both sides dialled each other. The lower user id keeps its
          // own offer; the other side yields and answers.
          final dialling = _sessions.values
              .where((s) => s.peerId == m.from && s.initiator && s.state == TransportState.opening)
              .toList();
          if (dialling.isNotEmpty) {
            if (_me.compareTo(m.from) < 0) return;
            for (final d in dialling) {
              await d.close();
            }
          }
          final t = await _newTransport(m.from, false, sid);
          t.pc.onDataChannel = t.attachChannel;
          await t.setRemote(RTCSessionDescription(m.data['sdp'] as String, m.data['type'] as String));
          final answer = await t.pc.createAnswer();
          await t.pc.setLocalDescription(answer);
          await signaling.send(m.from, 'answer', {'sid': sid, 'sdp': answer.sdp, 'type': answer.type});
          _incoming.add(t);
        case 'answer':
          final t = _sessions[sid];
          if (t == null || t.peerId != m.from) return;
          await t.setRemote(RTCSessionDescription(m.data['sdp'] as String, m.data['type'] as String));
        case 'ice':
          final t = _sessions[sid];
          if (t == null || t.peerId != m.from) return;
          await t.addIce(RTCIceCandidate(
            m.data['candidate'] as String?,
            m.data['sdpMid'] as String?,
            m.data['sdpMLineIndex'] as int?,
          ));
      }
    } catch (e) {
      debugPrint('signal ${m.type} failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    for (final s in _sessions.values.toList()) {
      await s.close();
    }
    _sessions.clear();
  }
}

/// Returned synchronously by [WebRtcLinkFactory.dial] while the real peer
/// connection is created asynchronously.
class _DeferredTransport extends BaseTransport {
  PeerTransport? _inner;
  _DeferredTransport(super.peerId, super.initiator);

  void bind(PeerTransport inner) {
    _inner = inner;
    inner.incoming.listen(deliver);
    inner.stateChanges.listen(setState, onDone: () => setState(TransportState.closed));
    if (inner.state != TransportState.opening) setState(inner.state);
  }

  @override
  void rawSend(String text) => _inner?.send(text);

  @override
  Future<void> close() async {
    setState(TransportState.closed);
    await _inner?.close();
  }
}
