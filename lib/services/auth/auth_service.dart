import 'dart:async';

import '../../models/models.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Passwordless e-mail authentication: a one-time verification code is sent
/// to the address and proves ownership of it. Registration and sign-in use
/// the same flow - the account is created on first successful verification.
abstract class AuthService {
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;

  Future<void> initialize();

  /// Sends a fresh verification code to [email].
  Future<void> sendCode(String email);

  /// Verifies [code] for [email] and signs the user in.
  Future<AppUser> verifyCode(String email, String code);

  Future<AppUser> updateDisplayName(String name);

  Future<void> signOut();

  /// Demo mode only: lets the UI show the code that would have been e-mailed.
  String? debugLastCode(String email) => null;
}

final _emailRe = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$");

bool isValidEmail(String email) => _emailRe.hasMatch(email.trim());
