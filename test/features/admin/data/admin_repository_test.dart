import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:shopmate/features/admin/data/models/admin_shop_model.dart';
import 'package:shopmate/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:shopmate/features/admin/domain/entities/admin_exception.dart';
import 'package:shopmate/features/admin/domain/entities/admin_shop.dart';

Map<String, Object?> _row({
  String id = 'shop-1',
  String status = 'pending',
  String? phone = '+233241111111',
  String? owner = 'owner@shop.test',
  String? approvedAt,
}) {
  return {
    'shop_id': id,
    'shop_name': 'Pending Mart',
    'shop_phone': phone,
    'shop_status': status,
    'owner_email': owner,
    'created_at': '2026-10-01T09:00:00+00:00',
    'approved_at': approvedAt,
    'updated_at': '2026-10-02T09:00:00+00:00',
  };
}

class _Request {
  _Request(this.method, this.path, this.body);

  final String method;
  final String path;
  final Object? body;
}

/// Loopback stand-in for PostgREST that replies from a queue.
class _FakePostgrest {
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
  void replyError(String code, {int status = 400}) {
    reply({
      'code': code,
      'message': 'raw database text for $code',
      'details': null,
      'hint': null,
    }, status: status);
  }

  Future<void> stop() => _server.close(force: true);
}

Matcher _throwsKind(AdminErrorKind kind) {
  return throwsA(isA<AdminException>().having((e) => e.kind, 'kind', kind));
}

void main() {
  late _FakePostgrest server;
  late SupabaseClient client;
  late AdminRepositoryImpl repository;

  setUp(() async {
    server = _FakePostgrest();
    await server.start();
    client = SupabaseClient(
      server.url,
      'test-anon-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    repository = AdminRepositoryImpl(AdminRemoteDataSource(client));
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('model', () {
    test('parses a full row', () {
      final shop = AdminShopModel.fromRow(
        _row(status: 'active', approvedAt: '2026-10-03T10:00:00+00:00'),
      );

      expect(shop.id, 'shop-1');
      expect(shop.name, 'Pending Mart');
      expect(shop.phone, '+233241111111');
      expect(shop.status, AdminShopStatus.active);
      expect(shop.ownerEmail, 'owner@shop.test');
      expect(shop.createdAt, DateTime.utc(2026, 10, 1, 9));
      expect(shop.approvedAt, DateTime.utc(2026, 10, 3, 10));
    });

    test('optional fields may be null', () {
      final shop = AdminShopModel.fromRow(_row(phone: null, owner: null));

      expect(shop.phone, isNull);
      expect(shop.ownerEmail, isNull);
      expect(shop.approvedAt, isNull);
    });

    test('rejects malformed rows', () {
      expect(
        () => AdminShopModel.fromRow({..._row(), 'shop_id': 42}),
        throwsFormatException,
      );
      expect(
        () => AdminShopModel.fromRow(_row(status: 'deleted')),
        throwsFormatException,
      );
      expect(
        () => AdminShopModel.fromRow({..._row(), 'created_at': 'not a date'}),
        throwsFormatException,
      );
    });
  });

  group('is platform admin', () {
    test('asks the database', () async {
      server.reply(true);

      expect(await repository.isPlatformAdmin(), isTrue);
      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.path, '/rest/v1/rpc/is_platform_admin');
    });

    test('false for everyone else', () async {
      server.reply(false);

      expect(await repository.isPlatformAdmin(), isFalse);
    });

    test('an unexpected answer is a failure, never "admin"', () async {
      server.reply('yes');

      await expectLater(
        repository.isPlatformAdmin(),
        _throwsKind(AdminErrorKind.loadFailed),
      );
    });
  });

  group('list shops', () {
    test('calls admin_list_shops with the status and maps rows', () async {
      server.reply([_row(), _row(id: 'shop-2')]);

      final shops = await repository.getShops(AdminShopStatus.pending);

      expect(shops.map((s) => s.id), ['shop-1', 'shop-2']);
      final request = server.requests.single;
      expect(request.path, '/rest/v1/rpc/admin_list_shops');
      expect(request.body, {'p_status': 'pending'});
    });

    test('a non-admin is refused by the database', () async {
      server.replyError('42501', status: 403);

      await expectLater(
        repository.getShops(AdminShopStatus.active),
        _throwsKind(AdminErrorKind.permissionDenied),
      );
    });

    test('server errors and malformed data are load failures', () async {
      server.replyError('XX000', status: 500);
      await expectLater(
        repository.getShops(AdminShopStatus.active),
        _throwsKind(AdminErrorKind.loadFailed),
      );

      server.reply([
        {'shop_id': 1},
      ]);
      await expectLater(
        repository.getShops(AdminShopStatus.active),
        _throwsKind(AdminErrorKind.loadFailed),
      );
    });
  });

  group('actions', () {
    final calls = {
      'admin_approve_shop': (AdminRepositoryImpl r) => r.approveShop('shop-1'),
      'admin_suspend_shop': (AdminRepositoryImpl r) => r.suspendShop('shop-1'),
      'admin_reactivate_shop': (AdminRepositoryImpl r) =>
          r.reactivateShop('shop-1'),
    };

    calls.forEach((function, call) {
      test('$function sends only the shop id', () async {
        server.reply(null);

        await call(repository);

        final request = server.requests.single;
        expect(request.path, '/rest/v1/rpc/$function');
        expect(request.body, {'p_shop_id': 'shop-1'});
      });
    });

    test('a non-admin (e.g. the shop owner) is refused', () async {
      server.replyError('42501', status: 403);

      await expectLater(
        repository.approveShop('shop-1'),
        _throwsKind(AdminErrorKind.permissionDenied),
      );
    });

    test('a shop already moved on is reported as changed', () async {
      server.replyError('55000');

      await expectLater(
        repository.suspendShop('shop-1'),
        _throwsKind(AdminErrorKind.statusChanged),
      );
    });

    test('a missing shop is reported as not found', () async {
      server.replyError('P0002', status: 404);

      await expectLater(
        repository.reactivateShop('shop-1'),
        _throwsKind(AdminErrorKind.notFound),
      );
    });

    test('other failures are generic and keep no database text', () async {
      server.replyError('XX000', status: 500);

      try {
        await repository.approveShop('shop-1');
        fail('expected an AdminException');
      } on AdminException catch (error) {
        expect(error.kind, AdminErrorKind.actionFailed);
        expect(error.code, 'XX000');
        expect(error.toString(), isNot(contains('raw database text')));
      }
    });
  });
}
