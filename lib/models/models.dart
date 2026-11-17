import 'dart:math';

/// The signed-in user.
class AppUser {
  final String id;
  final String email;
  final String? displayName;

  const AppUser({required this.id, required this.email, this.displayName});

  String get name =>
      (displayName == null || displayName!.trim().isEmpty) ? email.split('@').first : displayName!;

  AppUser copyWith({String? displayName}) =>
      AppUser(id: id, email: email, displayName: displayName ?? this.displayName);
}

/// A public directory entry for another user.
class PeerProfile {
  final String id;
  final String email;
  final String displayName;

  /// Base64 X25519 identity public key.
  final String publicKey;

  const PeerProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.publicKey,
  });

  String get name => displayName.trim().isEmpty ? email.split('@').first : displayName;

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'display_name': displayName, 'public_key': publicKey};

  factory PeerProfile.fromJson(Map<String, dynamic> j) => PeerProfile(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: (j['display_name'] as String?) ?? '',
        publicKey: j['public_key'] as String,
      );
}

enum MessageStatus { sending, sent, delivered, failed }

class ChatMessage {
  final String id;
  final String peerId;
  final bool outgoing;
  final String text;
  final DateTime timestamp;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.peerId,
    required this.outgoing,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'peer': peerId,
        'out': outgoing,
        'text': text,
        'ts': timestamp.millisecondsSinceEpoch,
        'st': status.index,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        peerId: j['peer'] as String,
        outgoing: j['out'] as bool,
        text: j['text'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        status: MessageStatus.values[j['st'] as int],
      );
}

/// Connection state of the peer-to-peer link to a contact.
enum LinkState { offline, connecting, handshaking, secure, failed }

String randomId([int len = 16]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
}
