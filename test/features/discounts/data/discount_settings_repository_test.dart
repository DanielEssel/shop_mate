import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/discounts/data/datasources/discount_settings_remote_datasource.dart';
import 'package:shopmate/features/discounts/data/repositories/discount_settings_repository_impl.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_percentage.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_scope.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings.dart';
import 'package:shopmate/features/discounts/domain/entities/discount_settings_exception.dart';

class _Request {
  _Request(this.method, this.path, this.query, this.body, this.prefer);

  final String method;
  final String path;
  final String query;
  final Object? body;
  final String prefer;

  @override
  String toString() => '$method $path?$query';
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
          Uri.decodeComponent(request.uri.query),
          text.isEmpty ? null : jsonDecode(text),
          request.headers.value('prefer') ?? '',
        ),
      );
      final (status, body) = _replies.isEmpty
          ? (200, <Object?>[])
          : _replies.removeAt(0);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
  }

  void reply(Object? body, {int status = 200}) => _replies.add((status, body));

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

Matcher _throwsKind(DiscountSettingsErrorKind kind) => throwsA(
  isA<DiscountSettingsException>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.message, 'message', isNot(contains('raw database'))),
);

SupabaseClient _client(String url) => SupabaseClient(
  url,
  'test-anon-key',
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

Map<String, Object?> _row({Object? percentage = 12.5, Object? endsAt}) => {
  'shop_id': 'shop-1',
  'is_enabled': true,
  'scope': 'selected_products',
  'percentage': percentage,
  'ends_at': endsAt,
  'updated_at': '2026-10-15T09:00:00+00:00',
};

DiscountSettingsDraft _draft({
  bool isEnabled = true,
  Set<String> selected = const {'oil', 'rice'},
  DateTime? endsAt,
}) {
  return DiscountSettingsDraft(
    isEnabled: isEnabled,
    scope: DiscountScope.selectedProducts,
    percentage: DiscountPercentage.tryParse('12.5')!,
    endsAt: endsAt,
    selectedProductIds: selected,
  );
}

void main() {
  late _FakePostgrest server;
  late SupabaseClient client;
  late DiscountSettingsRepositoryImpl repository;

  setUp(() async {
    server = _FakePostgrest();
    await server.start();
    client = _client(server.url);
    repository = DiscountSettingsRepositoryImpl(
      DiscountSettingsRemoteDataSource(client),
    );
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('load', () {
    test(
      'no configuration row: null, and selections are not fetched',
      () async {
        server.reply(<Object?>[]);

        expect(await repository.getSettings(), isNull);
        expect(server.requests.single.path, '/rest/v1/shop_discount_settings');
      },
    );

    test('parses the row (numeric as a number) and the selected ids', () async {
      server
        ..reply([_row(endsAt: '2026-10-21T00:00:00+00:00')])
        ..reply([
          {'product_id': 'rice'},
          {'product_id': 'oil'},
        ]);

      final settings = (await repository.getSettings())!;

      expect(settings.shopId, 'shop-1');
      expect(settings.isEnabled, isTrue);
      expect(settings.scope, DiscountScope.selectedProducts);
      expect(settings.percentage.basisPoints, 1250);
      expect(settings.endsAt, DateTime.utc(2026, 10, 21));
      expect(settings.selectedProductIds, {'rice', 'oil'});
      expect(server.requests.map((r) => r.path), [
        '/rest/v1/shop_discount_settings',
        '/rest/v1/shop_discount_products',
      ]);
    });

    test('a malformed row, a refusal and no connection fail safely', () async {
      server.reply([_row(percentage: 0)]);
      await expectLater(
        repository.getSettings(),
        _throwsKind(DiscountSettingsErrorKind.loadFailed),
      );

      server.replyError('42501', status: 403);
      await expectLater(
        repository.getSettings(),
        _throwsKind(DiscountSettingsErrorKind.permissionDenied),
      );

      final offline = _client('http://127.0.0.1:1');
      addTearDown(offline.dispose);
      await expectLater(
        DiscountSettingsRepositoryImpl(
          DiscountSettingsRemoteDataSource(offline),
        ).getSettings(),
        _throwsKind(DiscountSettingsErrorKind.network),
      );
    });
  });

  group('save', () {
    test('one call to save_discount_settings with exactly what was entered; '
        'no shop id, no table writes', () async {
      server.reply(null, status: 204);

      await repository.saveSettings(
        _draft(
          selected: const {'rice', 'oil'},
          endsAt: DateTime.utc(2026, 10, 21),
        ),
      );

      final sent = server.requests.single;
      expect(
        '${sent.method} ${sent.path}',
        'POST /rest/v1/rpc/save_discount_settings',
      );
      expect(sent.body, {
        'p_is_enabled': true,
        'p_scope': 'selected_products',
        // Exact decimal text, never a floating-point number.
        'p_percentage': '12.50',
        'p_ends_at': '2026-10-21T00:00:00.000Z',
        // In a stable order.
        'p_product_ids': ['oil', 'rice'],
      });
    });

    test('switched off with no products and no end date', () async {
      server.reply(null, status: 204);

      await repository.saveSettings(
        _draft(isEnabled: false, selected: const {}),
      );

      expect(server.requests.single.body, {
        'p_is_enabled': false,
        'p_scope': 'selected_products',
        'p_percentage': '12.50',
        'p_ends_at': null,
        'p_product_ids': <Object?>[],
      });
    });

    test('database refusals map by code, never by message text', () async {
      final expected = {
        // Not the owner, no active shop, or an expired session.
        '42501': DiscountSettingsErrorKind.permissionDenied,
        'PGRST301': DiscountSettingsErrorKind.permissionDenied,
        // The function is not in the database yet: never a fallback.
        'PGRST202': DiscountSettingsErrorKind.writesNotAvailable,
        '42883': DiscountSettingsErrorKind.writesNotAvailable,
        'SMD02': DiscountSettingsErrorKind.unsafeSelection,
        'SMD03': DiscountSettingsErrorKind.noProductsSelected,
        'SMD04': DiscountSettingsErrorKind.endDateInPast,
        '23514': DiscountSettingsErrorKind.invalid,
        '22023': DiscountSettingsErrorKind.invalid,
        '22P02': DiscountSettingsErrorKind.invalid,
        'XX000': DiscountSettingsErrorKind.saveFailed,
      };
      for (final MapEntry(key: code, value: kind) in expected.entries) {
        server.replyError(code, status: code == 'PGRST202' ? 404 : 400);
        await expectLater(
          repository.saveSettings(_draft()),
          _throwsKind(kind),
          reason: code,
        );
      }
      // One call per attempt; nothing else is tried.
      expect(server.requests.map((r) => r.path).toSet(), {
        '/rest/v1/rpc/save_discount_settings',
      });
    });

    test('no connection is a network failure', () async {
      final offline = _client('http://127.0.0.1:1');
      addTearDown(offline.dispose);
      await expectLater(
        DiscountSettingsRepositoryImpl(
          DiscountSettingsRemoteDataSource(offline),
        ).saveSettings(_draft()),
        _throwsKind(DiscountSettingsErrorKind.network),
      );
    });
  });
}
