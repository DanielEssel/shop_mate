import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/sales/data/datasources/pending_sale_local_store.dart';
import 'package:shopmate/features/sales/data/datasources/sales_remote_datasource.dart';
import 'package:shopmate/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:shopmate/features/sales/domain/entities/pending_sale_request.dart';
import 'package:shopmate/features/sales/domain/entities/sale_request_exception.dart';

class _Request {
  _Request(this.method, this.path, this.body);

  final String method;
  final String path;
  final Object? body;
}

/// Loopback stand-in for PostgREST (and a gateway in front of it).
class _FakeServer {
  late final HttpServer _server;
  final requests = <_Request>[];
  final _replies = <(int, String, ContentType)>[];

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
      final (status, body, type) = _replies.isEmpty
          ? (200, 'null', ContentType.json)
          : _replies.removeAt(0);
      request.response
        ..statusCode = status
        ..headers.contentType = type
        ..write(body);
      await request.response.close();
    });
  }

  void reply(Object? body, {int status = 200}) =>
      _replies.add((status, jsonEncode(body), ContentType.json));

  void replyRaw(String body, {required int status, ContentType? type}) =>
      _replies.add((status, body, type ?? ContentType.html));

  void replyError(String code, {String? message, int status = 400}) {
    reply({
      'code': code,
      'message': message ?? 'raw database text for $code',
      'details': null,
      'hint': null,
    }, status: status);
  }

  Future<void> stop() => _server.close(force: true);
}

const _scope = PendingSaleScope(userId: 'user-1', shopId: 'shop-1');

PendingSaleRequest _request({SaleRequestKind kind = SaleRequestKind.standard}) {
  final credit = kind == SaleRequestKind.credit;
  return PendingSaleRequest(
    idempotencyKey: '11111111-0000-4000-8000-000000000001',
    scope: _scope,
    draft: SaleDraft(
      kind: kind,
      paymentMethod: credit ? 'credit' : 'mobile_money',
      customerId: credit ? 'c-1' : null,
      amountPaid: credit ? 5 : 30,
      initialPaymentMethod: credit ? 'cash' : null,
      items: const [
        SaleRequestItem(productId: 'oil', quantity: 1),
        SaleRequestItem(productId: 'rice', quantity: 2),
      ],
      estimatedTotal: 29.99,
    ),
    createdAt: DateTime.utc(2026, 10, 15, 9),
  );
}

Matcher _kind(SaleRequestErrorKind kind) =>
    throwsA(isA<SaleRequestException>().having((e) => e.kind, 'kind', kind));

SupabaseClient _client(String url) => SupabaseClient(
  url,
  'test-anon-key',
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

void main() {
  late _FakeServer server;
  late SupabaseClient client;
  late SalesRepositoryImpl repository;

  setUp(() async {
    server = _FakeServer();
    await server.start();
    client = _client(server.url);
    repository = SalesRepositoryImpl(SalesRemoteDataSource(client));
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('sending', () {
    test('standard sales go to create_sale_idempotent with the exact '
        'payload, never to create_sale', () async {
      server.reply([
        {'sale_id': 'sale-1', 'replayed': false},
      ]);

      final submission = await repository.submitSale(_request());

      final sent = server.requests.single;
      expect(sent.path, '/rest/v1/rpc/create_sale_idempotent');
      expect(sent.body, {
        'p_idempotency_key': '11111111-0000-4000-8000-000000000001',
        'p_customer_id': null,
        'p_payment_method': 'mobile_money',
        'p_amount_paid': 30.0,
        'p_items': [
          {'product_id': 'oil', 'quantity': 1},
          {'product_id': 'rice', 'quantity': 2},
        ],
      });
      expect(submission.saleId, 'sale-1');
      expect(submission.replayed, isFalse);
    });

    test('a replayed sale is reported as such', () async {
      server.reply([
        {'sale_id': 'sale-1', 'replayed': true},
      ]);
      expect((await repository.submitSale(_request())).replayed, isTrue);
    });

    test('credit sales use the unchanged credit function with the same '
        'key and payload', () async {
      server.reply('sale-2');

      final submission = await repository.submitSale(
        _request(kind: SaleRequestKind.credit),
      );

      final sent = server.requests.single;
      expect(sent.path, '/rest/v1/rpc/create_credit_sale_with_initial_payment');
      expect(sent.body, {
        'p_customer_id': 'c-1',
        'p_initial_payment_amount': 5.0,
        'p_initial_payment_method': 'cash',
        'p_items': [
          {'product_id': 'oil', 'quantity': 1},
          {'product_id': 'rice', 'quantity': 2},
        ],
        'p_idempotency_key': '11111111-0000-4000-8000-000000000001',
      });
      expect(submission.saleId, 'sale-2');
      expect(submission.replayed, isNull);
    });

    test('the lookup only reads', () async {
      server
        ..reply('sale-1')
        ..reply(null);

      expect(await repository.findSaleByIdempotencyKey('key-1'), 'sale-1');
      expect(await repository.findSaleByIdempotencyKey('key-2'), isNull);
      expect(server.requests.map((r) => '${r.path} ${jsonEncode(r.body)}'), [
        '/rest/v1/rpc/find_sale_by_idempotency_key {"p_key":"key-1"}',
        '/rest/v1/rpc/find_sale_by_idempotency_key {"p_key":"key-2"}',
      ]);
    });
  });

  group('definite refusals (the database answered: nothing recorded)', () {
    test('by SQLSTATE, not by message', () async {
      final expected = {
        'SMI01': SaleRequestErrorKind.keyConflict,
        'SMD01': SaleRequestErrorKind.discountRefused,
        'P0001': SaleRequestErrorKind.rejected,
        '23505': SaleRequestErrorKind.rejected,
        '42501': SaleRequestErrorKind.rejected,
        'PGRST301': SaleRequestErrorKind.rejected,
      };
      for (final MapEntry(key: code, value: kind) in expected.entries) {
        server.replyError(code, message: 'anything');
        await expectLater(
          repository.submitSale(_request()),
          _kind(kind),
          reason: code,
        );
      }
    });

    test('the server message is kept for ordinary refusals', () async {
      server.replyError(
        'P0001',
        message: 'Insufficient stock for Rice. Available: 0, requested: 2',
      );
      await expectLater(
        repository.submitSale(_request()),
        throwsA(
          isA<SaleRequestException>()
              .having((e) => e.isDefinite, 'definite', isTrue)
              .having(
                (e) => e.serverMessage,
                'message',
                'Insufficient stock for Rice. Available: 0, requested: 2',
              ),
        ),
      );
    });

    test('the credit function'
        's key conflict (P0001 with its message)', () async {
      server.replyError(
        'P0001',
        message:
            'Idempotency key has already been used with a different '
            'credit-sale request',
      );
      await expectLater(
        repository.submitSale(_request(kind: SaleRequestKind.credit)),
        _kind(SaleRequestErrorKind.creditKeyConflict),
      );
    });

    test('a missing function is reported, never silently replaced', () async {
      server.replyError('PGRST202', status: 404);
      await expectLater(
        repository.submitSale(_request()),
        _kind(SaleRequestErrorKind.serviceUnavailable),
      );
      expect(
        server.requests.single.path,
        '/rest/v1/rpc/create_sale_idempotent',
      );
    });
  });

  group('unknown outcomes (the sale may have been recorded)', () {
    test('a gateway error page', () async {
      server.replyRaw('<html>502 Bad Gateway</html>', status: 502);
      await expectLater(
        repository.submitSale(_request()),
        _kind(SaleRequestErrorKind.outcomeUnknown),
      );
    });

    test('a gateway timeout with a JSON body but no SQLSTATE', () async {
      server.reply({'message': 'upstream request timeout'}, status: 504);
      await expectLater(
        repository.submitSale(_request()),
        _kind(SaleRequestErrorKind.outcomeUnknown),
      );
    });

    test('an unreadable success answer', () async {
      server.reply(<Object?>[]);
      await expectLater(
        repository.submitSale(_request()),
        _kind(SaleRequestErrorKind.outcomeUnknown),
      );
    });

    test('no connection', () async {
      final offline = _client('http://127.0.0.1:1');
      addTearDown(offline.dispose);
      final offlineRepository = SalesRepositoryImpl(
        SalesRemoteDataSource(offline),
      );
      await expectLater(
        offlineRepository.submitSale(_request()),
        _kind(SaleRequestErrorKind.outcomeUnknown),
      );
      await expectLater(
        offlineRepository.findSaleByIdempotencyKey('key-1'),
        _kind(SaleRequestErrorKind.outcomeUnknown),
      );
    });
  });

  group('device store (shared_preferences)', () {
    late SharedPreferencesPendingSaleStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = SharedPreferencesPendingSaleStore(SharedPreferences.getInstance);
    });

    test('saves, reloads exactly, and deletes', () async {
      final request = _request(kind: SaleRequestKind.credit);
      await store.save(request);

      final loaded = (await store.load(_scope))!;
      expect(loaded.idempotencyKey, request.idempotencyKey);
      expect(loaded.draft.sameRequestAs(request.draft), isTrue);

      await store.delete(_scope);
      expect(await store.load(_scope), isNull);
    });

    test('one record per account and shop', () async {
      await store.save(_request());
      expect(
        await store.load(
          const PendingSaleScope(userId: 'user-2', shopId: 'shop-1'),
        ),
        isNull,
      );
      expect(
        await store.load(
          const PendingSaleScope(userId: 'user-1', shopId: 'shop-2'),
        ),
        isNull,
      );
      expect(
        SharedPreferencesPendingSaleStore.keyFor(_scope),
        'shopmate.pending_sale.v1.user-1.shop-1',
      );
    });

    test('an unreadable record is reported with its value and kept', () async {
      const raw = '{"version": 1, "idempotency_key": "k", truncated';
      SharedPreferences.setMockInitialValues({
        SharedPreferencesPendingSaleStore.keyFor(_scope): raw,
      });
      store = SharedPreferencesPendingSaleStore(SharedPreferences.getInstance);

      await expectLater(
        store.load(_scope),
        throwsA(
          isA<PendingSaleStoreException>().having(
            (e) => e.rawValue,
            'raw',
            raw,
          ),
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(SharedPreferencesPendingSaleStore.keyFor(_scope)),
        raw,
      );
    });

    test('a record saved for another account is not accepted', () async {
      final other = PendingSaleRequest(
        idempotencyKey: 'k',
        scope: const PendingSaleScope(userId: 'user-2', shopId: 'shop-1'),
        draft: _request().draft,
        createdAt: DateTime.utc(2026),
      );
      SharedPreferences.setMockInitialValues({
        SharedPreferencesPendingSaleStore.keyFor(_scope): jsonEncode(
          other.toJson(),
        ),
      });
      store = SharedPreferencesPendingSaleStore(SharedPreferences.getInstance);

      await expectLater(
        store.load(_scope),
        throwsA(isA<PendingSaleStoreException>()),
      );
    });

    group('set aside', () {
      Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
      final abandonedKey = SharedPreferencesPendingSaleStore.abandonedKeyFor(
        _scope,
      );

      test(
        'moves the request to the kept list, then removes it as pending',
        () async {
          final request = _request();
          await store.save(request);
          await store.abandon(request, DateTime.utc(2026, 10, 15, 10));

          expect(await store.load(_scope), isNull);
          final kept = (await store.loadAbandoned(_scope)).single;
          expect(kept.request.idempotencyKey, request.idempotencyKey);
          expect(kept.request.draft.sameRequestAs(request.draft), isTrue);
          expect(kept.abandonedAt, DateTime.utc(2026, 10, 15, 10));
          expect(abandonedKey, 'shopmate.abandoned_sales.v1.user-1.shop-1');
        },
      );

      test('keeps several, once each, per account and shop', () async {
        final first = _request();
        final second = PendingSaleRequest(
          idempotencyKey: 'key-2',
          scope: _scope,
          draft: first.draft,
          createdAt: first.createdAt,
        );
        await store.abandon(first, DateTime.utc(2026));
        await store.abandon(first, DateTime.utc(2026, 2));
        await store.abandon(second, DateTime.utc(2026, 3));

        expect(
          (await store.loadAbandoned(
            _scope,
          )).map((a) => a.request.idempotencyKey),
          [first.idempotencyKey, 'key-2'],
        );
        expect(
          await store.loadAbandoned(
            const PendingSaleScope(userId: 'user-2', shopId: 'shop-1'),
          ),
          isEmpty,
        );

        await store.removeAbandoned(_scope, first.idempotencyKey);
        expect(
          (await store.loadAbandoned(
            _scope,
          )).map((a) => a.request.idempotencyKey),
          ['key-2'],
        );
      });

      test('an unreadable pending record is kept verbatim', () async {
        const raw = '{"version": 1, truncated';
        await (await prefs()).setString(
          SharedPreferencesPendingSaleStore.keyFor(_scope),
          raw,
        );
        await store.abandonUnreadable(_scope, raw);

        expect(
          (await prefs()).getString(
            SharedPreferencesPendingSaleStore.keyFor(_scope),
          ),
          isNull,
        );
        expect((await prefs()).getStringList(abandonedKey), [raw]);
        expect(await store.loadAbandoned(_scope), isEmpty);

        // Removing another entry leaves it untouched.
        await store.abandon(_request(), DateTime.utc(2026));
        await store.removeAbandoned(_scope, _request().idempotencyKey);
        expect((await prefs()).getStringList(abandonedKey), [raw]);
      });

      test('an unexpected value under the key is never overwritten, and '
          'the request stays pending', () async {
        await (await prefs()).setString(abandonedKey, 'not a list');
        final request = _request();
        await store.save(request);

        await expectLater(
          store.abandon(request, DateTime.utc(2026)),
          throwsA(isA<PendingSaleStoreException>()),
        );
        expect((await prefs()).getString(abandonedKey), 'not a list');
        expect(await store.load(_scope), isNotNull);
      });
    });
  });
}
