import 'dart:async';

import 'package:shopmate/features/auth/domain/entities/auth_credentials.dart';
import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/domain/entities/auth_user.dart';
import 'package:shopmate/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:shopmate/features/auth/domain/repositories/auth_repository.dart';

const userA = AuthUser(id: 'user-a', email: 'a@shop.test');
const userB = AuthUser(id: 'user-b', email: 'b@shop.test');

/// In-memory [AuthRepository] whose session and auth events tests control.
///
/// Like Supabase, the session changes first and the auth event follows
/// asynchronously; [emitEvents] can turn the events off to prove a caller
/// does not depend on them.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._user]);

  AuthUser? _user;
  final _events = StreamController<AuthUser?>.broadcast();

  bool emitEvents = true;

  /// When set, sign-out fails and keeps the session (a server-side failure
  /// before the local session was removed).
  AuthFailure? signOutFailure;

  int signOutCalls = 0;

  /// Scripted results for the form tests; null means success.
  AuthFailure? signInFailure;
  AuthFailure? signUpFailure;
  AuthFailure? resendFailure;
  SignUpOutcome signUpOutcome = SignUpOutcome.emailConfirmationRequired;

  AuthFailure? resetRequestFailure;
  AuthFailure? updatePasswordFailure;

  /// The code the "email" contains; any other code is rejected like an
  /// invalid or expired one.
  String validResetCode = '123456';

  /// When set, the request waits for it (to observe the loading state).
  Completer<void>? resetGate;
  Completer<void>? updateGate;

  final resetRequests = <String>[];
  final verifyCalls = <(String, String)>[];
  final passwordUpdates = <String>[];

  final signInCalls = <AuthCredentials>[];
  final signUpCalls = <AuthCredentials>[];
  final resendCalls = <String>[];

  /// Switches the session to [user] (null signs out) and emits the event.
  void changeUser(AuthUser? user) {
    _user = user;
    _emit();
  }

  /// A token refresh: same account, new event.
  void refreshToken() => _emit();

  void _emit() {
    if (emitEvents) scheduleMicrotask(() => _events.add(_user));
  }

  Future<void> dispose() => _events.close();

  @override
  Future<AuthUser> signIn(AuthCredentials credentials) async {
    signInCalls.add(credentials);
    final failure = signInFailure;
    if (failure != null) throw failure;
    final user = credentials.email == userB.email ? userB : userA;
    changeUser(user);
    return user;
  }

  @override
  Future<SignUpOutcome> signUp(AuthCredentials credentials) async {
    signUpCalls.add(credentials);
    final failure = signUpFailure;
    if (failure != null) throw failure;
    return signUpOutcome;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = signOutFailure;
    if (failure != null) throw failure;
    changeUser(null);
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    resendCalls.add(email);
    final failure = resendFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetRequests.add(email);
    await resetGate?.future;
    final failure = resetRequestFailure;
    if (failure != null) throw failure;
  }

  /// Like Supabase, a valid code signs the account in (recovery session).
  @override
  Future<AuthUser> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    verifyCalls.add((email, code));
    if (code != validResetCode) {
      throw const AuthFailure(
        AuthFailureKind.invalidRecoveryCode,
        code: 'otp_expired',
      );
    }
    final user = email == userB.email ? userB : userA;
    changeUser(user);
    return user;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    passwordUpdates.add(newPassword);
    await updateGate?.future;
    final failure = updatePasswordFailure;
    if (failure != null) throw failure;
    if (_user == null) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => _events.stream;
}
