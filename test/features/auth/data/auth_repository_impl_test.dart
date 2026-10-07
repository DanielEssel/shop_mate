import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:shopmate/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:shopmate/features/auth/domain/entities/auth_credentials.dart';
import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/domain/entities/auth_user.dart';
import 'package:shopmate/features/auth/domain/entities/sign_up_outcome.dart';

class _Request {
  _Request(this.method, this.uri, this.body);

  final String method;
  final Uri uri;
  final Object? body;

  Map<String, Object?> get json => Map<String, Object?>.from(body! as Map);
}

/// Loopback stand-in for Supabase Auth (GoTrue) that replies from a queue.
class _FakeGoTrue {
  late final HttpServer _server;
  final requests = <_Request>[];
  final _replies = <(int, Object?)>[];

  String get url => 'http://${_server.address.host}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      requests.add(
        _Request(
          request.method,
          request.uri,
          text.isEmpty ? null : jsonDecode(text),
        ),
      );
      final (status, body) = _replies.isEmpty
          ? (200, <String, Object?>{})
          : _replies.removeAt(0);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        // Current Supabase Auth API: error codes are sent as `code`.
        ..headers.set('x-supabase-api-version', '2024-01-01')
        ..write(jsonEncode(body));
      await request.response.close();
    });
  }

  void reply(Object? body, {int status = 200}) => _replies.add((status, body));

  void replyError(String code, {int status = 400}) {
    reply({
      'code': code,
      'message': 'raw server text for $code',
    }, status: status);
  }

  Future<void> stop() => _server.close(force: true);
}

Map<String, Object?> _user({String id = 'user-1', String? email}) => {
  'id': id,
  'aud': 'authenticated',
  'email': email ?? 'owner@example.com',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-10-07T09:00:00Z',
};

/// An unsigned token with a future `exp`, enough for the client to accept it.
String _accessToken() {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': 'user-1', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

Map<String, Object?> _session() => {
  'access_token': _accessToken(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-1',
  'user': _user(),
};

Matcher _throwsKind(AuthFailureKind kind) {
  return throwsA(isA<AuthFailure>().having((e) => e.kind, 'kind', kind));
}

void main() {
  late _FakeGoTrue server;
  late SupabaseClient client;
  late AuthRepositoryImpl repository;

  final credentials = AuthCredentials(
    email: '  owner@example.com ',
    password: ' secret pass ',
  );

  SupabaseClient clientFor(String url) {
    return SupabaseClient(
      url,
      'test-anon-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }

  setUp(() async {
    server = _FakeGoTrue();
    await server.start();
    client = clientFor(server.url);
    repository = AuthRepositoryImpl(client.auth);
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('sign in', () {
    test('returns the signed-in user and sends trimmed email', () async {
      server.reply(_session());

      final user = await repository.signIn(credentials);

      expect(user, const AuthUser(id: 'user-1', email: 'owner@example.com'));
      expect(repository.currentUser, user);

      final request = server.requests.single;
      expect(request.uri.path, '/auth/v1/token');
      expect(request.uri.queryParameters['grant_type'], 'password');
      expect(request.json['email'], 'owner@example.com');
      expect(request.json['password'], ' secret pass ');
    });

    test('wrong email or password', () async {
      server.replyError('invalid_credentials');

      await expectLater(
        repository.signIn(credentials),
        _throwsKind(AuthFailureKind.invalidCredentials),
      );
    });

    test('unconfirmed email', () async {
      server.replyError('email_not_confirmed');

      await expectLater(
        repository.signIn(credentials),
        _throwsKind(AuthFailureKind.emailNotConfirmed),
      );
    });

    test('rate limited by code', () async {
      server.replyError('over_request_rate_limit', status: 429);

      await expectLater(
        repository.signIn(credentials),
        _throwsKind(AuthFailureKind.tooManyRequests),
      );
    });

    test('rate limited by status alone', () async {
      server.reply({'message': 'slow down'}, status: 429);

      await expectLater(
        repository.signIn(credentials),
        _throwsKind(AuthFailureKind.tooManyRequests),
      );
    });

    test('unknown codes and server errors become a generic failure', () async {
      server.replyError('something_new');
      await expectLater(
        repository.signIn(credentials),
        _throwsKind(AuthFailureKind.unknown),
      );

      server.reply({'message': 'boom'}, status: 500);
      await expectLater(
        repository.signIn(credentials),
        _throwsKind(AuthFailureKind.unknown),
      );
    });

    test('no server reachable is a network failure', () async {
      final offline = clientFor(server.url);
      await server.stop();
      final offlineRepository = AuthRepositoryImpl(offline.auth);

      await expectLater(
        offlineRepository.signIn(credentials),
        _throwsKind(AuthFailureKind.network),
      );
      await offline.dispose();
    });

    test('failures keep the code but never the server message', () async {
      server.replyError('invalid_credentials');

      try {
        await repository.signIn(credentials);
        fail('expected an AuthFailure');
      } on AuthFailure catch (failure) {
        expect(failure.code, 'invalid_credentials');
        expect(failure.message, 'Incorrect email or password.');
        expect(failure.toString(), isNot(contains('raw server text')));
      }
    });
  });

  group('sign up', () {
    test('no session means email confirmation is required', () async {
      server.reply(_user());

      final outcome = await repository.signUp(credentials);

      expect(outcome, SignUpOutcome.emailConfirmationRequired);
      final request = server.requests.single;
      expect(request.uri.path, '/auth/v1/signup');
      expect(request.json['email'], 'owner@example.com');
      expect(request.json['password'], ' secret pass ');
    });

    test(
      'a new account (one identity, no session) needs confirmation',
      () async {
        server.reply({
          ..._user(),
          'identities': [
            {
              'id': 'identity-1',
              'user_id': 'user-1',
              'identity_id': 'identity-1',
              'provider': 'email',
              'identity_data': {'email': 'owner@example.com'},
              'created_at': '2026-10-07T09:00:00Z',
              'last_sign_in_at': '2026-10-07T09:00:00Z',
              'updated_at': '2026-10-07T09:00:00Z',
            },
          ],
        });

        expect(
          await repository.signUp(credentials),
          SignUpOutcome.emailConfirmationRequired,
        );
      },
    );

    test('an already registered email (no identities) is reported', () async {
      server.reply({..._user(), 'identities': <Object>[]});

      await expectLater(
        repository.signUp(credentials),
        _throwsKind(AuthFailureKind.emailAlreadyRegistered),
      );
    });

    test('a returned session means signed in', () async {
      server.reply(_session());

      expect(await repository.signUp(credentials), SignUpOutcome.signedIn);
      expect(repository.currentUser?.id, 'user-1');
    });

    test('weak password', () async {
      server.reply({
        'code': 'weak_password',
        'message': 'Password should be at least 8 characters.',
        'weak_password': {
          'reasons': ['length'],
        },
      }, status: 422);

      await expectLater(
        repository.signUp(credentials),
        _throwsKind(AuthFailureKind.weakPassword),
      );
    });

    test('already registered', () async {
      server.replyError('user_already_exists', status: 422);

      await expectLater(
        repository.signUp(credentials),
        _throwsKind(AuthFailureKind.emailAlreadyRegistered),
      );
    });

    test('invalid email', () async {
      server.replyError('validation_failed', status: 400);

      await expectLater(
        repository.signUp(credentials),
        _throwsKind(AuthFailureKind.invalidEmail),
      );
    });
  });

  group('sign out', () {
    test('clears the session and tells the server', () async {
      server
        ..reply(_session())
        ..reply(null, status: 204);
      await repository.signIn(credentials);

      await repository.signOut();

      expect(repository.currentUser, isNull);
      expect(server.requests.last.uri.path, '/auth/v1/logout');
    });

    test('still succeeds on this device when offline', () async {
      server.reply(_session());
      await repository.signIn(credentials);
      await server.stop();

      await repository.signOut();

      expect(repository.currentUser, isNull);
    });
  });

  test('auth state changes emit the user, then null', () async {
    final emitted = <AuthUser?>[];
    final subscription = repository.authStateChanges.listen(emitted.add);
    server
      ..reply(_session())
      ..reply(null, status: 204);

    await repository.signIn(credentials);
    await repository.signOut();
    await pumpEventQueue();

    expect(
      emitted,
      contains(const AuthUser(id: 'user-1', email: 'owner@example.com')),
    );
    expect(emitted.last, isNull);
    await subscription.cancel();
  });

  group('email requests', () {
    test('resend confirmation sends a signup resend', () async {
      server.reply(<String, Object?>{});

      await repository.resendEmailConfirmation('owner@example.com');

      final request = server.requests.single;
      expect(request.uri.path, '/auth/v1/resend');
      expect(request.json['type'], 'signup');
      expect(request.json['email'], 'owner@example.com');
    });

    test('password reset sends a recover request', () async {
      server.reply(<String, Object?>{});

      await repository.requestPasswordReset('owner@example.com');

      final request = server.requests.single;
      expect(request.uri.path, '/auth/v1/recover');
      expect(request.json['email'], 'owner@example.com');
    });

    test('a valid recovery code returns the account and signs it in', () async {
      server.reply(_session());

      final user = await repository.verifyPasswordResetCode(
        email: 'owner@example.com',
        code: '123456',
      );

      expect(user.id, 'user-1');
      expect(repository.currentUser?.id, 'user-1');
      final request = server.requests.single;
      expect(request.uri.path, '/auth/v1/verify');
      expect(request.json['type'], 'recovery');
      expect(request.json['email'], 'owner@example.com');
      expect(request.json['token'], '123456');
    });

    test('a wrong or expired code is reported as such', () async {
      server.replyError('otp_expired', status: 403);

      await expectLater(
        repository.verifyPasswordResetCode(
          email: 'owner@example.com',
          code: '000000',
        ),
        _throwsKind(AuthFailureKind.invalidRecoveryCode),
      );
      expect(repository.currentUser, isNull);
    });

    group('update password', () {
      Future<void> signInForRecovery() async {
        server.reply(_session());
        await repository.verifyPasswordResetCode(
          email: 'owner@example.com',
          code: '123456',
        );
      }

      test('sends only the new password for the signed-in account', () async {
        await signInForRecovery();
        server.reply(_user());

        await repository.updatePassword(' new password ');

        final request = server.requests.last;
        expect(request.method, 'PUT');
        expect(request.uri.path, '/auth/v1/user');
        expect(request.json['password'], ' new password ');
        expect(request.json.containsKey('email'), isFalse);
      });

      test('the same password as before', () async {
        await signInForRecovery();
        server.replyError('same_password', status: 422);

        await expectLater(
          repository.updatePassword('old-password'),
          _throwsKind(AuthFailureKind.samePassword),
        );
      });

      test('a weak password', () async {
        await signInForRecovery();
        server.reply({
          'code': 'weak_password',
          'message': 'Password is known to be weak.',
          'weak_password': {
            'reasons': ['pwned'],
          },
        }, status: 422);

        await expectLater(
          repository.updatePassword('password123'),
          _throwsKind(AuthFailureKind.weakPassword),
        );
      });

      test('without a session it asks to sign in again', () async {
        await expectLater(
          repository.updatePassword('new-password'),
          _throwsKind(AuthFailureKind.sessionExpired),
        );
        expect(server.requests, isEmpty);
      });
    });

    test('email rate limit', () async {
      server.replyError('over_email_send_rate_limit', status: 429);

      await expectLater(
        repository.requestPasswordReset('owner@example.com'),
        _throwsKind(AuthFailureKind.tooManyRequests),
      );
    });
  });
}
