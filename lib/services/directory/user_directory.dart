import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/models.dart';

/// Public directory of users and their identity public keys.
abstract class UserDirectory {
  Future<void> publish(AppUser user, String publicKeyBase64);
  Future<PeerProfile?> findByEmail(String email);
  Future<PeerProfile?> findById(String id);
}

class SupabaseUserDirectory implements UserDirectory {
  final sb.SupabaseClient _client;
  SupabaseUserDirectory(this._client);

  @override
  Future<void> publish(AppUser user, String publicKeyBase64) async {
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email.toLowerCase(),
      'display_name': user.name,
      'public_key': publicKeyBase64,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<PeerProfile?> findByEmail(String email) async {
    final row = await _client
        .from('profiles')
        .select('id,email,display_name,public_key')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    return row == null ? null : PeerProfile.fromJson(row);
  }

  @override
  Future<PeerProfile?> findById(String id) async {
    final row = await _client
        .from('profiles')
        .select('id,email,display_name,public_key')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : PeerProfile.fromJson(row);
  }
}

/// In-memory directory used in demo mode (pre-seeded with demo peers).
class DemoUserDirectory implements UserDirectory {
  final Map<String, PeerProfile> _byId = {};

  void add(PeerProfile p) => _byId[p.id] = p;

  @override
  Future<void> publish(AppUser user, String publicKeyBase64) async {
    _byId[user.id] = PeerProfile(
        id: user.id, email: user.email, displayName: user.name, publicKey: publicKeyBase64);
  }

  @override
  Future<PeerProfile?> findByEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final e = email.trim().toLowerCase();
    for (final p in _byId.values) {
      if (p.email == e) return p;
    }
    return null;
  }

  @override
  Future<PeerProfile?> findById(String id) async => _byId[id];
}
