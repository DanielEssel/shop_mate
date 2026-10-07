import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop_members/data/datasources/shop_members_remote_datasource.dart';
import 'package:shopmate/features/shop_members/data/models/created_shop_attendant_model.dart';
import 'package:shopmate/features/shop_members/data/models/shop_member_model.dart';
import 'package:shopmate/features/shop_members/data/repositories/shop_members_repository_impl.dart';
import 'package:shopmate/features/shop_members/domain/entities/new_shop_attendant.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_member.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_members_exception.dart';

const _password = 'Temp-Pass-123';

const _attendant = NewShopAttendant(
  email: 'esi@shop.test',
  displayName: 'Esi Mensah',
  temporaryPassword: _password,
);

Map<String, Object?> _row({
  String role = 'staff',
  String status = 'active',
  Object? email = 'esi@shop.test',
  Object? displayName = 'Esi Mensah',
}) {
  return {
    'member_id': 'member-1',
    'user_id': 'user-1',
    'role': role,
    'status': status,
    'email': email,
    'display_name': displayName,
    'created_at': '2026-10-01T09:00:00+00:00',
    'updated_at': '2026-10-02T09:00:00+00:00',
  };
}

class _Request {
  _Request(this.method, this.path, this.body);

  final String method;
  final String path;
  final Object? body;
}

/// Loopback stand-in for PostgREST and the Edge Function gateway that
/// replies from a queue.
class _FakeSupabase {
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
          request.uri.path,
          text.isEmpty ? null : jsonDecode(text),
        ),
      );
      final (status, body) = _replies.isEmpty
          ? (200, null)
          : _replies.removeAt(0);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
  }

  void reply(Object? body, {int status = 200}) => _replies.add((status, body));

  /// A raised exception as PostgREST reports it.
  void replyRpcError(String code, {int status = 400}) {
    reply({
      'code': code,
      'message': 'raw database text for $code',
      'details': null,
      'hint': null,
    }, status: status);
  }

  /// An Edge Function error response.
  void replyFunctionError(int status, String code) {
    reply({
      'error': {'code': code, 'message': 'raw function text for $code'},
    }, status: status);
  }

  Future<void> stop() => _server.close(force: true);
}

Matcher _throwsKind(ShopMembersErrorKind kind) {
  return throwsA(
    isA<ShopMembersException>().having((e) => e.kind, 'kind', kind),
  );
}

SupabaseClient _client(String url) {
  return SupabaseClient(
    url,
    'test-anon-key',
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

void main() {
  late _FakeSupabase server;
  late SupabaseClient client;
  late ShopMembersRepositoryImpl repository;

  setUp(() async {
    server = _FakeSupabase();
    await server.start();
    client = _client(server.url);
    repository = ShopMembersRepositoryImpl(ShopMembersRemoteDataSource(client));
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('model', () {
    test('parses a full row', () {
      final member = ShopMemberModel.fromRow(_row());

      expect(member.memberId, 'member-1');
      expect(member.userId, 'user-1');
      expect(member.role, ShopRole.attendant);
      expect(member.status, ShopMemberStatus.active);
      expect(member.email, 'esi@shop.test');
      expect(member.displayName, 'Esi Mensah');
      expect(member.createdAt, DateTime.utc(2026, 10, 1, 9));
      expect(member.updatedAt, DateTime.utc(2026, 10, 2, 9));
      expect(member.label, 'Esi Mensah');
    });

    test('maps the stored roles: owner, staff, and unknown values', () {
      expect(ShopMemberModel.fromRow(_row(role: 'owner')).role, ShopRole.owner);
      expect(
        ShopMemberModel.fromRow(_row(role: 'staff')).role,
        ShopRole.attendant,
      );
      // An unknown role can never be shown as an owner.
      expect(
        ShopMemberModel.fromRow(_row(role: 'manager')).role,
        ShopRole.attendant,
      );
    });

    test('maps both statuses and rejects anything else', () {
      expect(
        ShopMemberModel.fromRow(_row(status: 'active')).status,
        ShopMemberStatus.active,
      );
      expect(
        ShopMemberModel.fromRow(_row(status: 'suspended')).status,
        ShopMemberStatus.suspended,
      );
      expect(
        () => ShopMemberModel.fromRow(_row(status: 'revoked')),
        throwsFormatException,
      );
    });

    test('a missing or blank name falls back to the email', () {
      final noName = ShopMemberModel.fromRow(_row(displayName: null));
      final blank = ShopMemberModel.fromRow(_row(displayName: '   '));

      expect(noName.displayName, isNull);
      expect(noName.label, 'esi@shop.test');
      expect(blank.displayName, isNull);
      expect(blank.label, 'esi@shop.test');
    });

    test('rejects malformed rows', () {
      expect(
        () => ShopMemberModel.fromRow({..._row(), 'member_id': 42}),
        throwsFormatException,
      );
      expect(
        () => ShopMemberModel.fromRow({..._row(), 'created_at': 'yesterday'}),
        throwsFormatException,
      );
      expect(
        () => ShopMemberModel.fromRow(_row(email: 7)),
        throwsFormatException,
      );
    });

    test('parses the created attendant and rejects a malformed body', () {
      final created = CreatedShopAttendantModel.fromJson({
        'user_id': 'new-user',
        'email': 'esi@shop.test',
        'display_name': 'Esi Mensah',
        'role': 'staff',
        'status': 'active',
        'confirmation_email_sent': false,
      });

      expect(created.userId, 'new-user');
      expect(created.confirmationEmailSent, isFalse);
      expect(
        () => CreatedShopAttendantModel.fromJson({'user_id': 'x'}),
        throwsFormatException,
      );
    });

    test('the request never prints its password', () {
      expect(_attendant.toString(), isNot(contains(_password)));
    });
  });

  group('list', () {
    test('calls list_shop_members and parses every row', () async {
      server.reply([
        _row(role: 'owner', displayName: 'Kwame'),
        {..._row(), 'member_id': 'member-2', 'user_id': 'user-2'},
      ]);

      final members = await repository.getMembers();

      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.path, '/rest/v1/rpc/list_shop_members');
      expect(members.map((m) => m.role), [ShopRole.owner, ShopRole.attendant]);
    });

    test('an empty shop is an empty list', () async {
      server.reply(<Object?>[]);
      expect(await repository.getMembers(), isEmpty);
    });

    test('failures become safe kinds without the database text', () async {
      server.replyRpcError('42501', status: 403);
      await expectLater(
        repository.getMembers(),
        _throwsKind(ShopMembersErrorKind.permissionDenied),
      );

      server.replyRpcError('XX000', status: 500);
      await expectLater(
        repository.getMembers(),
        throwsA(
          isA<ShopMembersException>()
              .having((e) => e.kind, 'kind', ShopMembersErrorKind.loadFailed)
              .having(
                (e) => e.toString(),
                'text',
                isNot(contains('raw database text')),
              ),
        ),
      );

      server.reply({'not': 'a list'});
      await expectLater(
        repository.getMembers(),
        _throwsKind(ShopMembersErrorKind.loadFailed),
      );

      server.replyRpcError('PGRST303', status: 401);
      await expectLater(
        repository.getMembers(),
        _throwsKind(ShopMembersErrorKind.sessionExpired),
      );
    });
  });

  group('suspend, restore and revoke', () {
    test('suspend sends the member\'s user id and "suspended"', () async {
      await repository.suspendMember('user-2');

      final request = server.requests.single;
      expect(request.path, '/rest/v1/rpc/set_shop_member_status');
      expect(request.body, {
        'p_member_user_id': 'user-2',
        'p_status': 'suspended',
      });
    });

    test('restore sends the member\'s user id and "active"', () async {
      await repository.restoreMember('user-2');

      final request = server.requests.single;
      expect(request.path, '/rest/v1/rpc/set_shop_member_status');
      expect(request.body, {
        'p_member_user_id': 'user-2',
        'p_status': 'active',
      });
    });

    test('revoke calls remove_shop_member with the user id only', () async {
      await repository.revokeMember('user-2');

      final request = server.requests.single;
      expect(request.path, '/rest/v1/rpc/remove_shop_member');
      expect(request.body, {'p_member_user_id': 'user-2'});
    });

    test('SQLSTATEs map to safe kinds', () async {
      final expected = {
        '42501': ShopMembersErrorKind.permissionDenied,
        'P0002': ShopMembersErrorKind.notFound,
        '55000': ShopMembersErrorKind.statusChanged,
        '22023': ShopMembersErrorKind.actionFailed,
      };
      for (final MapEntry(key: code, value: kind) in expected.entries) {
        server.replyRpcError(code);
        await expectLater(
          repository.suspendMember('user-2'),
          _throwsKind(kind),
          reason: code,
        );
      }

      server.replyRpcError('42501');
      await expectLater(
        repository.revokeMember('user-2'),
        _throwsKind(ShopMembersErrorKind.permissionDenied),
      );
    });
  });

  group('create attendant', () {
    test('posts exactly email, display_name and temporary_password', () async {
      server.reply({
        'user_id': 'new-user',
        'email': 'esi@shop.test',
        'display_name': 'Esi Mensah',
        'role': 'staff',
        'status': 'active',
        'confirmation_email_sent': true,
      }, status: 201);

      final created = await repository.createAttendant(_attendant);

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/functions/v1/create-shop-attendant');
      expect(request.body, {
        'email': 'esi@shop.test',
        'display_name': 'Esi Mensah',
        'temporary_password': _password,
      });
      expect(created.userId, 'new-user');
      expect(created.email, 'esi@shop.test');
      expect(created.confirmationEmailSent, isTrue);
    });

    test('HTTP statuses and codes map to safe kinds', () async {
      final expected = <(int, String), ShopMembersErrorKind>{
        (409, 'email_exists'): ShopMembersErrorKind.emailExists,
        (403, 'not_owner'): ShopMembersErrorKind.permissionDenied,
        (401, 'unauthorized'): ShopMembersErrorKind.sessionExpired,
        (500, 'server_error'): ShopMembersErrorKind.createFailed,
        (500, 'create_failed'): ShopMembersErrorKind.createFailed,
        (400, 'invalid_email'): ShopMembersErrorKind.invalidEmail,
        (400, 'invalid_name'): ShopMembersErrorKind.invalidName,
        (400, 'invalid_password'): ShopMembersErrorKind.invalidPassword,
        (400, 'weak_password'): ShopMembersErrorKind.invalidPassword,
        (400, 'invalid_request'): ShopMembersErrorKind.createFailed,
      };
      for (final MapEntry(key: (status, code), value: kind)
          in expected.entries) {
        server.replyFunctionError(status, code);
        await expectLater(
          repository.createAttendant(_attendant),
          throwsA(
            isA<ShopMembersException>()
                .having((e) => e.kind, 'kind', kind)
                .having(
                  (e) => '$e ${e.message}',
                  'text',
                  allOf(
                    isNot(contains('raw function text')),
                    isNot(contains(_password)),
                  ),
                ),
          ),
          reason: '$status $code',
        );
      }
    });

    test('a 409 message tells the owner to use another email', () async {
      server.replyFunctionError(409, 'email_exists');
      await expectLater(
        repository.createAttendant(_attendant),
        throwsA(
          isA<ShopMembersException>().having(
            (e) => e.message,
            'message',
            'This email already has a ShopMate account. Use another email '
                'address.',
          ),
        ),
      );
    });

    test('a gateway 401 without our error body is a session problem', () async {
      server.reply({'msg': 'Invalid JWT'}, status: 401);
      await expectLater(
        repository.createAttendant(_attendant),
        _throwsKind(ShopMembersErrorKind.sessionExpired),
      );
    });

    test('an unexpected success body is a safe failure', () async {
      server.reply({'user_id': 42}, status: 201);
      await expectLater(
        repository.createAttendant(_attendant),
        _throwsKind(ShopMembersErrorKind.createFailed),
      );
    });

    test('no connection is a network failure', () async {
      // Nothing listens on port 1.
      final offline = _client('http://127.0.0.1:1');
      addTearDown(offline.dispose);
      final offlineRepository = ShopMembersRepositoryImpl(
        ShopMembersRemoteDataSource(offline),
      );

      await expectLater(
        offlineRepository.createAttendant(_attendant),
        _throwsKind(ShopMembersErrorKind.network),
      );
      await expectLater(
        offlineRepository.getMembers(),
        _throwsKind(ShopMembersErrorKind.loadFailed),
      );
    });
  });
}
