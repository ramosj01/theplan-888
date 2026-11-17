import 'dart:async';
import 'dart:math';

import '../../models/models.dart';
import '../storage/secure_store.dart';
import 'auth_service.dart';

/// Offline stand-in for the e-mail OTP backend. Codes expire after 10 minutes
/// and are surfaced to the UI via [debugLastCode] instead of being e-mailed.
class DemoAuthService extends AuthService {
  final SecureStore _store;
  final _controller = StreamController<AppUser?>.broadcast();
  final _codes = <String, (String, DateTime)>{};
  AppUser? _user;

  DemoAuthService(this._store);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  @override
  Future<void> initialize() async {
    final email = await _store.getFlag('demo.session.email');
    if (email != null) {
      _user = AppUser(
        id: 'demo-${email.hashCode.toUnsigned(32)}',
        email: email,
        displayName: await _store.getFlag('demo.name.$email'),
      );
    }
  }

  @override
  Future<void> sendCode(String email) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final code = List.generate(6, (_) => Random.secure().nextInt(10)).join();
    _codes[email.trim().toLowerCase()] = (code, DateTime.now().add(const Duration(minutes: 10)));
  }

  @override
  String? debugLastCode(String email) => _codes[email.trim().toLowerCase()]?.$1;

  @override
  Future<AppUser> verifyCode(String email, String code) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final key = email.trim().toLowerCase();
    final entry = _codes[key];
    if (entry == null || DateTime.now().isAfter(entry.$2) || entry.$1 != code.trim()) {
      throw AuthException('That code is invalid or has expired.');
    }
    _codes.remove(key);
    await _store.setFlag('demo.session.email', key);
    _user = AppUser(
      id: 'demo-${key.hashCode.toUnsigned(32)}',
      email: key,
      displayName: await _store.getFlag('demo.name.$key'),
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> updateDisplayName(String name) async {
    await _store.setFlag('demo.name.${_user!.email}', name);
    _user = _user!.copyWith(displayName: name);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    await _store.setFlag('demo.session.email', null);
    _user = null;
    _controller.add(null);
  }
}
