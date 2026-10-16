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

import '../fake_discount_settings_repository.dart';

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
    test('first save: insert OFF, sync selection, then switch ON', () async {
      server
        ..reply({'shop_id': 'shop-1'}, status: 201) // insert
        ..reply(null, status: 204) // delete others
        ..reply(null, status: 201) // add selection
        ..reply([
          {'shop_id': 'shop-1'},
        ]); // enable

      await repository.saveSettings(
        _draft(endsAt: DateTime.utc(2026, 10, 21)),
        current: null,
      );

      final requests = server.requests;
      expect(requests.map((r) => '${r.method} ${r.path}'), [
        'POST /rest/v1/shop_discount_settings',
        'DELETE /rest/v1/shop_discount_products',
        'POST /rest/v1/shop_discount_products',
        'PATCH /rest/v1/shop_discount_settings',
      ]);
      // Saved switched off first, with the percentage as exact text.
      expect(requests[0].body, {
        'is_enabled': false,
        'scope': 'selected_products',
        'percentage': '12.50',
        'ends_at': '2026-10-21T00:00:00.000Z',
      });
      // Everything but the new selection is removed, for this shop only.
      expect(requests[1].query, contains('shop_id=eq.shop-1'));
      expect(requests[1].query, contains('product_id=not.in.(oil,rice)'));
      // Missing products are added; existing ones are left alone.
      expect(requests[2].body, [
        {'product_id': 'oil'},
        {'product_id': 'rice'},
      ]);
      expect(requests[2].prefer, contains('resolution=ignore-duplicates'));
      expect(requests[2].query, contains('on_conflict=shop_id,product_id'));
      // Switched on last, for this shop only.
      expect(requests[3].body, {'is_enabled': true});
      expect(requests[3].query, contains('shop_id=eq.shop-1'));
    });

    test('saving it OFF never sends the final enable', () async {
      server
        ..reply([
          {'shop_id': 'shop-1'},
        ]) // update
        ..reply(null, status: 204); // delete all (empty selection)

      await repository.saveSettings(
        _draft(isEnabled: false, selected: const {}),
        current: discountSettings(),
      );

      expect(server.requests.map((r) => '${r.method} ${r.path}'), [
        'PATCH /rest/v1/shop_discount_settings',
        'DELETE /rest/v1/shop_discount_products',
      ]);
      expect((server.requests[0].body! as Map)['is_enabled'], isFalse);
      expect(server.requests[1].query, isNot(contains('not.in')));
    });

    test(
      'an update hidden by row-level security is a refusal, not success',
      () async {
        server.reply(<Object?>[]); // PATCH matched no row

        await expectLater(
          repository.saveSettings(_draft(), current: discountSettings()),
          _throwsKind(DiscountSettingsErrorKind.permissionDenied),
        );
        // Nothing after the refused step.
        expect(server.requests, hasLength(1));
      },
    );

    test('the release gate (42501) stops at the first step', () async {
      server.replyError('42501', status: 401);

      await expectLater(
        repository.saveSettings(_draft(), current: null),
        _throwsKind(DiscountSettingsErrorKind.permissionDenied),
      );
      expect(server.requests, hasLength(1));
    });

    test(
      'a failure part-way leaves the discount OFF (enable never sent)',
      () async {
        server
          ..reply([
            {'shop_id': 'shop-1'},
          ]) // saved OFF
          ..replyError('42501', status: 401); // selection refused

        await expectLater(
          repository.saveSettings(_draft(), current: discountSettings()),
          _throwsKind(DiscountSettingsErrorKind.permissionDenied),
        );
        expect(server.requests.map((r) => r.method), ['PATCH', 'DELETE']);
        expect((server.requests[0].body! as Map)['is_enabled'], isFalse);
      },
    );

    test('constraint failures and no connection map to safe kinds', () async {
      server.replyError('23514');
      await expectLater(
        repository.saveSettings(_draft(), current: null),
        _throwsKind(DiscountSettingsErrorKind.invalid),
      );

      final offline = _client('http://127.0.0.1:1');
      addTearDown(offline.dispose);
      await expectLater(
        DiscountSettingsRepositoryImpl(
          DiscountSettingsRemoteDataSource(offline),
        ).saveSettings(_draft(), current: null),
        _throwsKind(DiscountSettingsErrorKind.network),
      );
    });
  });
}
