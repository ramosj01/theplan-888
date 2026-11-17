import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A signaling message relayed between two users (SDP offers/answers, ICE
/// candidates). Signaling only brokers the connection - chat content never
/// passes through it.
class SignalMessage {
  final String from;
  final String type;
  final Map<String, dynamic> data;
  SignalMessage(this.from, this.type, this.data);
}

abstract class SignalingService {
  Stream<SignalMessage> get messages;

  /// User ids currently online.
  Stream<Set<String>> get presence;
  Set<String> get online;

  Future<void> start(String myUserId);
  Future<void> send(String toUserId, String type, Map<String, dynamic> data);
  Future<void> stop();
}

/// Supabase Realtime broadcast based signaling: each user listens on
/// `signal:<their id>` and presence is tracked on the `lobby` channel.
class SupabaseSignalingService implements SignalingService {
  final sb.SupabaseClient _client;
  final _messages = StreamController<SignalMessage>.broadcast();
  final _presence = StreamController<Set<String>>.broadcast();
  final Map<String, sb.RealtimeChannel> _outbound = {};
  sb.RealtimeChannel? _inbox;
  sb.RealtimeChannel? _lobby;
  String? _me;
  Set<String> _online = {};

  SupabaseSignalingService(this._client);

  @override
  Stream<SignalMessage> get messages => _messages.stream;
  @override
  Stream<Set<String>> get presence => _presence.stream;
  @override
  Set<String> get online => _online;

  @override
  Future<void> start(String myUserId) async {
    _me = myUserId;
    _inbox = _client.channel('signal:$myUserId')
      ..onBroadcast(
        event: 'signal',
        callback: (payload) {
          final from = payload['from'] as String?;
          final type = payload['kind'] as String?;
          final data = payload['data'];
          if (from == null || type == null || data is! Map) return;
          _messages.add(SignalMessage(from, type, Map<String, dynamic>.from(data)));
        },
      )
      ..subscribe();

    _lobby = _client.channel('lobby', opts: sb.RealtimeChannelConfig(key: myUserId));
    _lobby!
        .onPresenceSync((_) {
          final ids = <String>{};
          for (final state in _lobby!.presenceState()) {
            for (final p in state.presences) {
              final id = p.payload['user_id'];
              if (id is String) ids.add(id);
            }
          }
          _online = ids;
          _presence.add(ids);
        })
        .subscribe((status, _) async {
          if (status == sb.RealtimeSubscribeStatus.subscribed) {
            await _lobby!.track({'user_id': myUserId});
          }
        });
  }

  Future<sb.RealtimeChannel> _channelFor(String userId) async {
    final existing = _outbound[userId];
    if (existing != null) return existing;
    final ready = Completer<void>();
    final ch = _client.channel('signal:$userId');
    ch.subscribe((status, _) {
      if (status == sb.RealtimeSubscribeStatus.subscribed && !ready.isCompleted) ready.complete();
    });
    _outbound[userId] = ch;
    await ready.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    return ch;
  }

  @override
  Future<void> send(String toUserId, String type, Map<String, dynamic> data) async {
    final ch = await _channelFor(toUserId);
    await ch.sendBroadcastMessage(
      event: 'signal',
      payload: {'from': _me, 'kind': type, 'data': data},
    );
  }

  @override
  Future<void> stop() async {
    for (final ch in [..._outbound.values, if (_inbox != null) _inbox!, if (_lobby != null) _lobby!]) {
      await _client.removeChannel(ch);
    }
    _outbound.clear();
    _inbox = null;
    _lobby = null;
    _online = {};
  }
}
