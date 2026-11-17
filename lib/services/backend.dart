import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/models.dart';
import 'auth/auth_service.dart';
import 'auth/demo_auth_service.dart';
import 'auth/supabase_auth_service.dart';
import 'demo/demo_backend.dart';
import 'directory/user_directory.dart';
import 'p2p/transport.dart';
import 'p2p/webrtc_link.dart';
import 'signaling/signaling_service.dart';
import 'storage/secure_store.dart';

/// Bundles the services the app needs, either backed by Supabase or by the
/// self-contained demo implementation.
class Backend {
  final AuthService auth;
  final UserDirectory directory;
  final SignalingService signaling;
  final PeerLinkFactory links;
  final SecureStore store;
  final bool demo;

  Backend._(this.auth, this.directory, this.signaling, this.links, this.store, this.demo);

  static Future<Backend> create() async {
    final store = SecureStore();
    if (AppConfig.demoMode) {
      final dir = DemoUserDirectory();
      final bots = await createDemoBots(dir);
      final auth = DemoAuthService(store);
      PeerProfile me() {
        final u = auth.currentUser!;
        return PeerProfile(id: u.id, email: u.email, displayName: u.name, publicKey: _myKey ?? '');
      }

      final backend = Backend._(
        auth,
        dir,
        DemoSignalingService(bots.keys.toSet()),
        DemoLinkFactory(bots, me),
        store,
        true,
      );
      await auth.initialize();
      return backend;
    }

    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
    final client = Supabase.instance.client;
    final signaling = SupabaseSignalingService(client);
    final auth = SupabaseAuthService(client);
    await auth.initialize();
    return Backend._(
      auth,
      SupabaseUserDirectory(client),
      signaling,
      WebRtcLinkFactory(signaling),
      store,
      false,
    );
  }

  static String? _myKey;

  /// Lets demo peers learn the signed-in user's identity public key.
  static void registerMyKey(String key) => _myKey = key;
}
