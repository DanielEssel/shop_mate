import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/domain/entities/auth_credentials.dart';
import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/domain/entities/auth_user.dart';
import 'package:shopmate/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:shopmate/features/auth/domain/repositories/auth_repository.dart';
import 'package:shopmate/features/auth/domain/usecases/request_password_reset.dart';
import 'package:shopmate/features/auth/domain/usecases/resend_email_confirmation.dart';
import 'package:shopmate/features/auth/domain/usecases/sign_in.dart';
import 'package:shopmate/features/auth/domain/usecases/sign_out.dart';
import 'package:shopmate/features/auth/domain/usecases/sign_up.dart';
import 'package:shopmate/features/auth/domain/usecases/update_password.dart';
import 'package:shopmate/features/auth/domain/usecases/verify_password_reset_code.dart';

const _user = AuthUser(id: 'user-1', email: 'owner@example.com');

/// Records each call; throws [failure] instead when it is set.
class _RecordingRepository implements AuthRepository {
  final calls = <String>[];
  AuthFailure? failure;

  void _record(String call) {
    calls.add(call);
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<AuthUser> signIn(AuthCredentials credentials) async {
    _record('signIn ${credentials.email} ${credentials.password}');
    return _user;
  }

  @override
  Future<SignUpOutcome> signUp(AuthCredentials credentials) async {
    _record('signUp ${credentials.email} ${credentials.password}');
    return SignUpOutcome.emailConfirmationRequired;
  }

  @override
  Future<void> signOut() async => _record('signOut');

  @override
  Future<void> resendEmailConfirmation(String email) async {
    _record('resend $email');
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _record('reset $email');
  }

  @override
  Future<AuthUser> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    _record('verify $email $code');
    return _user;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    _record('update $newPassword');
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();
}

void main() {
  late _RecordingRepository repository;

  setUp(() => repository = _RecordingRepository());

  group('credentials', () {
    test('trim the email but keep the password as typed', () {
      final credentials = AuthCredentials(
        email: '  owner@example.com ',
        password: ' pass word ',
      );

      expect(credentials.email, 'owner@example.com');
      expect(credentials.password, ' pass word ');
    });

    test('never print the password', () {
      final credentials = AuthCredentials(
        email: 'owner@example.com',
        password: 'top-secret',
      );

      expect(credentials.toString(), isNot(contains('top-secret')));
    });
  });

  group('use cases delegate to the repository', () {
    final credentials = AuthCredentials(
      email: ' owner@example.com',
      password: 'secret',
    );

    test('sign in', () async {
      expect(await SignIn(repository).call(credentials), _user);
      expect(repository.calls, ['signIn owner@example.com secret']);
    });

    test('sign up', () async {
      expect(
        await SignUp(repository).call(credentials),
        SignUpOutcome.emailConfirmationRequired,
      );
      expect(repository.calls, ['signUp owner@example.com secret']);
    });

    test('sign out', () async {
      await SignOut(repository).call();
      expect(repository.calls, ['signOut']);
    });

    test('resend confirmation trims the email', () async {
      await ResendEmailConfirmation(repository).call(' owner@example.com ');
      expect(repository.calls, ['resend owner@example.com']);
    });

    test(
      'verify reset code trims the email and drops spaces in the code',
      () async {
        expect(
          await VerifyPasswordResetCode(
            repository,
          ).call(email: ' owner@example.com ', code: ' 123 456 '),
          _user,
        );
        expect(repository.calls, ['verify owner@example.com 123456']);
      },
    );

    test('update password keeps the password exactly as typed', () async {
      await UpdatePassword(repository).call(' new pass ');
      expect(repository.calls, ['update  new pass ']);
    });

    test('password reset trims the email', () async {
      await RequestPasswordReset(repository).call(' owner@example.com ');
      expect(repository.calls, ['reset owner@example.com']);
    });
  });

  test('typed failures pass through every use case unchanged', () async {
    const failure = AuthFailure(AuthFailureKind.tooManyRequests);
    repository.failure = failure;
    final credentials = AuthCredentials(email: 'a@b.co', password: 'secret');

    final calls = <Future<Object?> Function()>[
      () => SignIn(repository).call(credentials),
      () => SignUp(repository).call(credentials),
      () => SignOut(repository).call(),
      () => ResendEmailConfirmation(repository).call('a@b.co'),
      () => RequestPasswordReset(repository).call('a@b.co'),
      () =>
          VerifyPasswordResetCode(repository).call(email: 'a@b.co', code: '1'),
      () => UpdatePassword(repository).call('new-password'),
    ];
    for (final call in calls) {
      await expectLater(call(), throwsA(same(failure)));
    }
  });

  test('every failure kind has a safe, non-empty message', () {
    for (final kind in AuthFailureKind.values) {
      final failure = AuthFailure(kind, code: 'some_code');
      expect(failure.message, isNotEmpty);
      expect(failure.message, kind.message);
    }
  });
}
