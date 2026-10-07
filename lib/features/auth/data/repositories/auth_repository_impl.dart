// Supabase also exports an unrelated realtime `AuthUser`.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../domain/entities/auth_credentials.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/sign_up_outcome.dart';
import '../../domain/repositories/auth_repository.dart';

/// Supabase Auth behind [AuthRepository]. This is the only place that sees
/// Supabase auth types: users become [AuthUser] and every error becomes an
/// [AuthFailure], chosen by error code, never by message text.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth);

  final GoTrueClient _auth;

  @override
  Future<AuthUser> signIn(AuthCredentials credentials) async {
    final User? user;
    try {
      final response = await _auth.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );
      user = response.user;
    } catch (error) {
      throw _translate(error);
    }

    if (user == null) throw const AuthFailure(AuthFailureKind.unknown);
    return _toAuthUser(user);
  }

  @override
  Future<SignUpOutcome> signUp(AuthCredentials credentials) async {
    try {
      final response = await _auth.signUp(
        email: credentials.email,
        password: credentials.password,
      );

      final user = response.user;
      if (response.session != null) return SignUpOutcome.signedIn;

      // With email confirmation on, Supabase answers an email that is
      // already registered with a placeholder user that has no identities
      // (and sends no email). A new account always has one identity.
      if (user != null && (user.identities?.isEmpty ?? false)) {
        throw const AuthFailure(
          AuthFailureKind.emailAlreadyRegistered,
          code: 'user_already_exists',
        );
      }
      return SignUpOutcome.emailConfirmationRequired;
    } catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      // The local session is removed before the server is told, so a failed
      // server call (e.g. offline) still leaves this device signed out.
      if (_auth.currentSession == null) return;
      throw _translate(error);
    }
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    try {
      await _auth.resend(type: OtpType.signup, email: email);
    } catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<AuthUser> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final User? user;
    try {
      final response = await _auth.verifyOTP(
        type: OtpType.recovery,
        email: email,
        token: code,
      );
      user = response.user;
    } catch (error) {
      throw _translate(error);
    }

    if (user == null) throw const AuthFailure(AuthFailureKind.unknown);
    return _toAuthUser(user);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw _translate(error);
    }
  }

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _auth.onAuthStateChange.map((state) {
      final user = state.session?.user;
      return user == null ? null : _toAuthUser(user);
    });
  }

  static AuthUser _toAuthUser(User user) {
    return AuthUser(id: user.id, email: user.email);
  }

  static const _rateLimitCodes = {
    'over_request_rate_limit',
    'over_email_send_rate_limit',
  };

  static const _sessionCodes = {
    'session_expired',
    'session_not_found',
    'session_missing',
    'refresh_token_not_found',
    'refresh_token_already_used',
    'bad_jwt',
  };

  /// Maps a Supabase Auth error to a user-safe failure. Only the error code
  /// is kept; the backend's message text is dropped.
  static AuthFailure _translate(Object error) {
    if (error is AuthFailure) return error;
    if (error is! AuthException) {
      return const AuthFailure(AuthFailureKind.unknown);
    }

    final code = error.code;
    if (error is AuthWeakPasswordException) {
      return AuthFailure(AuthFailureKind.weakPassword, code: code);
    }
    if (error is AuthSessionMissingException) {
      return AuthFailure(AuthFailureKind.sessionExpired, code: code);
    }
    // Thrown when no response arrived (offline, DNS, timeout); a 5xx reply
    // also lands here but carries its status code.
    if (error is AuthRetryableFetchException && error.statusCode == null) {
      return AuthFailure(AuthFailureKind.network, code: code);
    }

    final kind = switch (code) {
      'invalid_credentials' => AuthFailureKind.invalidCredentials,
      'email_not_confirmed' => AuthFailureKind.emailNotConfirmed,
      'user_already_exists' ||
      'email_exists' => AuthFailureKind.emailAlreadyRegistered,
      'weak_password' => AuthFailureKind.weakPassword,
      // Every request here sends an email, and a malformed one is the
      // usual cause of a validation failure.
      'email_address_invalid' ||
      'validation_failed' => AuthFailureKind.invalidEmail,
      'request_timeout' => AuthFailureKind.network,
      // Supabase uses one code for a wrong and an expired one-time code.
      'otp_expired' => AuthFailureKind.invalidRecoveryCode,
      'same_password' => AuthFailureKind.samePassword,
      final String c when _rateLimitCodes.contains(c) =>
        AuthFailureKind.tooManyRequests,
      final String c when _sessionCodes.contains(c) =>
        AuthFailureKind.sessionExpired,
      _ when error.statusCode == '429' => AuthFailureKind.tooManyRequests,
      _ => AuthFailureKind.unknown,
    };
    return AuthFailure(kind, code: code);
  }
}
