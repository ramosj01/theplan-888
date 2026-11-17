import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/models.dart';
import 'auth_service.dart';

/// Uses Supabase Auth e-mail OTP. Configure the "Magic Link" e-mail template
/// in Supabase to include `{{ .Token }}` so users receive a 6-digit code.
class SupabaseAuthService extends AuthService {
  final sb.SupabaseClient _client;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  StreamSubscription? _sub;

  SupabaseAuthService(this._client);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  AppUser? _map(sb.User? u) => u == null
      ? null
      : AppUser(
          id: u.id,
          email: u.email ?? '',
          displayName: u.userMetadata?['display_name'] as String?,
        );

  @override
  Future<void> initialize() async {
    _user = _map(_client.auth.currentUser);
    _sub = _client.auth.onAuthStateChange.listen((s) {
      _user = _map(s.session?.user);
      _controller.add(_user);
    });
  }

  @override
  Future<void> sendCode(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email.trim().toLowerCase(), shouldCreateUser: true);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<AppUser> verifyCode(String email, String code) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: sb.OtpType.email,
      );
      final user = _map(res.user);
      if (user == null) throw AuthException('Verification failed. Please try again.');
      _user = user;
      return user;
    } on sb.AuthException catch (e) {
      throw AuthException(e.message.contains('expired') || e.message.contains('invalid')
          ? 'That code is invalid or has expired.'
          : e.message);
    }
  }

  @override
  Future<AppUser> updateDisplayName(String name) async {
    final res = await _client.auth.updateUser(sb.UserAttributes(data: {'display_name': name}));
    _user = _map(res.user);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    _controller.add(null);
  }

  void dispose() => _sub?.cancel();
}
