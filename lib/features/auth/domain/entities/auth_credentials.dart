import 'package:flutter/foundation.dart';

/// An email and password for signing in or signing up. The email is trimmed;
/// the password is kept exactly as typed.
@immutable
class AuthCredentials {
  AuthCredentials({required String email, required this.password})
    : email = email.trim();

  final String email;
  final String password;

  /// Never includes the password.
  @override
  String toString() => 'AuthCredentials($email)';
}
