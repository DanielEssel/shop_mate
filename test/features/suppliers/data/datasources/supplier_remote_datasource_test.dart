import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/suppliers/data/datasources/supplier_remote_datasource.dart';
import 'package:shopmate/features/suppliers/data/repositories/supplier_repository_impl.dart';

const _supplierId = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> _row({String name = 'Kofi Bentley', bool active = true}) {
  return {
    'id': _supplierId,
    'shop_id': '22222222-2222-4222-8222-222222222222',
    'name': name,
    'phone': '0240000001',
    'email': null,
    'address': null,
    'notes': null,
    'is_active': active,
    'created_by': '33333333-3333-4333-8333-333333333333',
    'created_at': '2026-10-06T09:00:00+00:00',
    'updated_at': '2026-10-06T09:00:00+00:00',
  };
}

class _RecordedRequest {
  _RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final Object? body;

  Map<String, Object?> get jsonBody {
    final value = body;
    if (value is! Map) throw StateError('Expected a JSON object body.');
    return Map<String, Object?>.from(value);
  }
}

/// A loopback stand-in for PostgREST that records requests and replies with
/// the queued JSON responses. No network or credentials are involved.
class _FakePostgrest {
  late final HttpServer _server;
  final requests = <_RecordedRequest>[];
  final _responses = <Object>[];

  String get url => 'http://${_server.address.host}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      final Object? decoded = text.isEmpty ? null : jsonDecode(text);
      requests.add(
        _RecordedRequest(request.method, request.uri, request.headers, decoded),
      );

      final reply = _responses.isEmpty ? <Object>[] : _responses.removeAt(0);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(reply));
      await request.response.close();
    });
  }

  void reply(Object json) => _responses.add(json);

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late _FakePostgrest server;
  late SupabaseClient client;
  late SupplierRemoteDataSource dataSource;

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
    dataSource = SupplierRemoteDataSource(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('list query', () {
    test(
      'reads active suppliers ordered by name, without a shop filter',
      () async {
        server.reply([_row(), _row(name: 'Tuth')]);

        final suppliers = await dataSource.getSuppliers(includeInactive: false);

        expect(suppliers.map((s) => s.name), ['Kofi Bentley', 'Tuth']);
        final request = server.requests.single;
        expect(request.method, 'GET');
        expect(request.uri.path, '/rest/v1/suppliers');
        expect(request.uri.queryParameters['is_active'], 'eq.true');
        expect(request.uri.queryParameters['order'], 'name.asc.nullslast');
        expect(
          request.uri.queryParameters['select'],
          'id,shop_id,name,phone,email,address,notes,is_active,'
          'created_by,created_at,updated_at',
        );
        expect(request.uri.queryParameters.containsKey('shop_id'), isFalse);
      },
    );

    test('includes inactive suppliers when asked', () async {
      server.reply([_row(active: false)]);

      final suppliers = await dataSource.getSuppliers(includeInactive: true);

      expect(suppliers.single.isActive, isFalse);
      final query = server.requests.single.uri.queryParameters;
      expect(query.containsKey('is_active'), isFalse);
      expect(query['order'], 'name.asc.nullslast');
    });

    test('rejects a malformed row instead of skipping it', () async {
      server.reply([
        {..._row(), 'is_active': null},
      ]);

      expect(
        () => dataSource.getSuppliers(includeInactive: false),
        throwsFormatException,
      );
    });
  });

  test('single supplier query filters by id and expects one object', () async {
    server.reply(_row());

    final supplier = await dataSource.getSupplierById(_supplierId);

    expect(supplier.id, _supplierId);
    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/rest/v1/suppliers');
    expect(request.uri.queryParameters['id'], 'eq.$_supplierId');
    expect(
      request.headers.value(HttpHeaders.acceptHeader),
      'application/vnd.pgrst.object+json',
    );
  });

  test('insert sends only client-owned fields, trimmed', () async {
    server.reply(_row());

    final created = await dataSource.createSupplier(
      name: '  Kofi Bentley  ',
      phone: ' 0240000001 ',
      email: '   ',
      address: null,
      notes: ' Delivers on Mondays ',
    );

    expect(created.name, 'Kofi Bentley');
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/rest/v1/suppliers');
    expect(request.jsonBody, {
      'name': 'Kofi Bentley',
      'phone': '0240000001',
      'email': null,
      'address': null,
      'notes': 'Delivers on Mondays',
    });
    expect(request.headers.value('prefer'), contains('return=representation'));
    expect(request.uri.queryParameters['select'], contains('shop_id'));
  });

  test(
    'insert preserves capitalisation and inner spacing of the name',
    () async {
      server.reply(_row(name: 'ABC  Distributors'));

      await dataSource.createSupplier(name: ' ABC  Distributors ');

      expect(server.requests.single.jsonBody['name'], 'ABC  Distributors');
    },
  );

  test('update sends editable fields and a UTC updated_at only', () async {
    server.reply(_row(name: 'Kofi Bentley Ltd', active: false));
    final before = DateTime.now().toUtc();

    final updated = await dataSource.updateSupplier(
      id: _supplierId,
      name: ' Kofi Bentley Ltd ',
      isActive: false,
      phone: '',
      email: 'kofi@example.com',
    );

    expect(updated.isActive, isFalse);
    final request = server.requests.single;
    expect(request.method, 'PATCH');
    expect(request.uri.path, '/rest/v1/suppliers');
    expect(request.uri.queryParameters['id'], 'eq.$_supplierId');

    final body = request.jsonBody;
    expect(body.keys.toSet(), {
      'name',
      'phone',
      'email',
      'address',
      'notes',
      'is_active',
      'updated_at',
    });
    expect(body['name'], 'Kofi Bentley Ltd');
    expect(body['phone'], isNull);
    expect(body['email'], 'kofi@example.com');
    expect(body['is_active'], isFalse);

    final updatedAt = body['updated_at'];
    expect(updatedAt, isA<String>());
    final sentAt = DateTime.parse(updatedAt! as String);
    expect(sentAt.isUtc, isTrue);
    expect(
      sentAt.isBefore(before.subtract(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('repository implementation returns datasource results', () async {
    final repository = SupplierRepositoryImpl(dataSource);
    server
      ..reply([_row()])
      ..reply(_row())
      ..reply(_row())
      ..reply(_row(active: false));

    final list = await repository.getSuppliers();
    final single = await repository.getSupplierById(_supplierId);
    final created = await repository.createSupplier(name: 'Kofi Bentley');
    final updated = await repository.updateSupplier(
      id: _supplierId,
      name: 'Kofi Bentley',
      isActive: false,
    );

    expect(list.single.id, _supplierId);
    expect(single.id, _supplierId);
    expect(created.id, _supplierId);
    expect(updated.isActive, isFalse);
    expect(server.requests.map((r) => r.method), [
      'GET',
      'GET',
      'POST',
      'PATCH',
    ]);
    expect(server.requests.first.uri.queryParameters['is_active'], 'eq.true');
  });
}
