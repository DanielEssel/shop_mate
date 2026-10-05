import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/purchases/data/datasources/purchase_remote_datasource.dart';
import 'package:shopmate/features/purchases/data/repositories/purchase_repository_impl.dart';

const _purchaseId = '22222222-2222-4222-8222-222222222222';
const _supplierId = '11111111-1111-4111-8111-111111111111';

const _originalParams = {
  'p_supplier_name',
  'p_supplier_phone',
  'p_payment_method',
  'p_amount_paid',
  'p_purchase_date',
  'p_notes',
  'p_items',
};

final _items = <Map<String, Object?>>[
  {
    'product_id': '55555555-5555-4555-8555-555555555555',
    'product_name': 'Rice 5kg',
    'quantity': 3,
    'unit_cost': 20.0,
  },
];

Map<String, Object?> _purchaseRow({String? supplierId}) {
  return {
    'id': _purchaseId,
    'purchase_number': 'PU-20261006090000-ABC123',
    'supplier_id': supplierId,
    'supplier_name': 'Kofi Bentley',
    'supplier_phone': '0240000001',
    'total_amount': 60,
    'amount_paid': 25,
    'balance': 35,
    'payment_method': 'credit',
    'status': 'completed',
    'purchase_date': '2026-10-06',
    'notes': null,
    'created_by': null,
    'created_at': '2026-10-06T09:00:00+00:00',
    'updated_at': '2026-10-06T09:00:00+00:00',
  };
}

class _RecordedRequest {
  _RecordedRequest(this.method, this.uri, this.body);

  final String method;
  final Uri uri;
  final Object? body;

  Map<String, Object?> get jsonBody {
    final value = body;
    if (value is! Map) throw StateError('Expected a JSON object body.');
    return Map<String, Object?>.from(value);
  }
}

/// Loopback stand-in for PostgREST: records requests and replies with the
/// queued JSON. No network or credentials are involved.
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
      requests.add(_RecordedRequest(request.method, request.uri, decoded));

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
  late PurchaseRemoteDataSource dataSource;

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
    dataSource = PurchaseRemoteDataSource(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  Future<String> create({String? supplierId}) {
    return dataSource.createPurchase(
      supplierName: 'Kofi Bentley',
      supplierPhone: '0240000001',
      paymentMethod: 'credit',
      amountPaid: 25,
      purchaseDate: DateTime(2026, 10, 6, 15, 30),
      notes: 'Delivered',
      items: _items,
      supplierId: supplierId,
    );
  }

  test('without a supplier sends exactly the original 7 parameters', () async {
    server.reply(_purchaseId);

    final id = await create();

    expect(id, _purchaseId);
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/rest/v1/rpc/create_purchase');
    final body = request.jsonBody;
    expect(body.keys.toSet(), _originalParams);
    expect(body.containsKey('p_supplier_id'), isFalse);
    expect(body, {
      'p_supplier_name': 'Kofi Bentley',
      'p_supplier_phone': '0240000001',
      'p_payment_method': 'credit',
      'p_amount_paid': 25,
      'p_purchase_date': '2026-10-06',
      'p_notes': 'Delivered',
      'p_items': _items,
    });
  });

  test('omitting supplierId entirely matches passing null', () async {
    server.reply(_purchaseId);

    await dataSource.createPurchase(
      supplierName: null,
      supplierPhone: null,
      paymentMethod: 'cash',
      amountPaid: 0,
      purchaseDate: DateTime(2026, 10, 6),
      items: _items,
    );

    final body = server.requests.single.jsonBody;
    expect(body.keys.toSet(), _originalParams);
    expect(body['p_supplier_name'], isNull);
  });

  test(
    'with a supplier sends the original parameters plus p_supplier_id',
    () async {
      server.reply(_purchaseId);

      final id = await create(supplierId: _supplierId);

      expect(id, _purchaseId);
      final body = server.requests.single.jsonBody;
      expect(body.keys.toSet(), {..._originalParams, 'p_supplier_id'});
      expect(body['p_supplier_id'], _supplierId);
      expect(body['p_supplier_name'], 'Kofi Bentley');
      expect(body['p_supplier_phone'], '0240000001');
      expect(body['p_purchase_date'], '2026-10-06');
      expect(body['p_items'], _items);
    },
  );

  test(
    'repository threads supplierId and still re-reads the purchase',
    () async {
      final repository = PurchaseRepositoryImpl(dataSource);
      server
        ..reply(_purchaseId)
        ..reply(_purchaseRow(supplierId: _supplierId));

      final purchase = await repository.createPurchase(
        supplierName: 'Kofi Bentley',
        supplierPhone: '0240000001',
        paymentMethod: 'credit',
        amountPaid: 25,
        purchaseDate: DateTime(2026, 10, 6),
        items: _items,
        supplierId: _supplierId,
      );

      expect(server.requests, hasLength(2));
      expect(server.requests.first.jsonBody['p_supplier_id'], _supplierId);
      final reRead = server.requests.last;
      expect(reRead.method, 'GET');
      expect(reRead.uri.path, '/rest/v1/purchases');
      expect(reRead.uri.queryParameters['id'], 'eq.$_purchaseId');
      expect(purchase.id, _purchaseId);
      expect(purchase.supplierId, _supplierId);
    },
  );

  test('repository without supplierId keeps the 7-parameter request', () async {
    final repository = PurchaseRepositoryImpl(dataSource);
    server
      ..reply(_purchaseId)
      ..reply(_purchaseRow());

    final purchase = await repository.createPurchase(
      supplierName: 'Kofi Bentley',
      supplierPhone: '0240000001',
      paymentMethod: 'credit',
      amountPaid: 25,
      purchaseDate: DateTime(2026, 10, 6),
      items: _items,
    );

    expect(server.requests.first.jsonBody.keys.toSet(), _originalParams);
    expect(purchase.supplierId, isNull);
  });
}
