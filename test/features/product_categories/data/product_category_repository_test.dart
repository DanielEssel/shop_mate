import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/product_categories/data/datasources/product_category_remote_datasource.dart';
import 'package:shopmate/features/product_categories/data/repositories/product_category_repository_impl.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_exception.dart';
import 'package:shopmate/features/product_categories/domain/entities/product_category_name.dart';
import 'package:shopmate/features/products/data/datasources/product_remote_datasource.dart';
import 'package:shopmate/features/products/data/repositories/product_repository_impl.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';

Map<String, Object?> _category(String id, String name, {bool active = true}) {
  return {
    'id': id,
    'shop_id': 'shop-1',
    'name': name,
    'is_active': active,
    'created_at': '2026-10-09T09:00:00+00:00',
    'updated_at': '2026-10-09T09:00:00+00:00',
  };
}

class _Request {
  _Request(this.method, this.uri, this.body);

  final String method;
  final Uri uri;
  final Object? body;

  Map<String, Object?> get json => Map<String, Object?>.from(body! as Map);
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
          request.uri,
          text.isEmpty ? null : jsonDecode(text),
        ),
      );
      final (status, body) = _replies.isEmpty
          ? (200, <Object>[])
          : _replies.removeAt(0);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
  }

  void reply(Object? body, {int status = 200}) => _replies.add((status, body));

  Future<void> stop() => _server.close(force: true);
}

Matcher _throwsKind(ProductCategoryErrorKind kind) {
  return throwsA(
    isA<ProductCategoryException>().having((e) => e.kind, 'kind', kind),
  );
}

void main() {
  late _FakePostgrest server;
  late SupabaseClient client;
  late ProductCategoryRepositoryImpl repository;

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
    repository = ProductCategoryRepositoryImpl(
      ProductCategoryRemoteDataSource(client),
    );
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  test('lists all categories with active product counts', () async {
    server
      ..reply([
        _category('c1', 'Beverages'),
        _category('c2', 'Old', active: false),
        _category('c3', 'Snacks'),
      ])
      ..reply([
        {'category_id': 'c1'},
        {'category_id': 'c1'},
        {'category_id': 'c2'},
      ]);

    final summaries = await repository.getCategories();

    expect(summaries.map((s) => s.category.name), [
      'Beverages',
      'Old',
      'Snacks',
    ]);
    expect(summaries.map((s) => s.activeProductCount), [2, 1, 0]);

    final categoriesRequest = server.requests[0];
    expect(categoriesRequest.uri.path, '/rest/v1/product_categories');
    expect(
      categoriesRequest.uri.queryParameters.containsKey('is_active'),
      isFalse,
    );
    expect(
      categoriesRequest.uri.queryParameters['order'],
      startsWith('name.asc'),
    );
    expect(
      categoriesRequest.uri.queryParameters.containsKey('shop_id'),
      isFalse,
    );

    final countsRequest = server.requests[1];
    expect(countsRequest.uri.path, '/rest/v1/products');
    expect(countsRequest.uri.queryParameters['select'], 'category_id');
    expect(countsRequest.uri.queryParameters['is_active'], 'eq.true');
    expect(countsRequest.uri.queryParameters['category_id'], 'not.is.null');
  });

  test('active categories are filtered by the server', () async {
    server.reply([_category('c1', 'Beverages')]);

    final categories = await repository.getActiveCategories();

    expect(categories.single.name, 'Beverages');
    expect(server.requests.single.uri.queryParameters['is_active'], 'eq.true');
  });

  test('create sends only the trimmed name', () async {
    server.reply(_category('c9', 'Drinks'));

    final created = await repository.createCategory(
      ProductCategoryName('  Drinks '),
    );

    expect(created.name, 'Drinks');
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.json, {'name': 'Drinks'});
  });

  test('rename sends only the name for that id', () async {
    server.reply(_category('c1', 'Soft drinks'));

    await repository.renameCategory('c1', ProductCategoryName('Soft drinks'));

    final request = server.requests.single;
    expect(request.method, 'PATCH');
    expect(request.uri.queryParameters['id'], 'eq.c1');
    expect(request.json, {'name': 'Soft drinks'});
  });

  test('archive and restore send only is_active', () async {
    server
      ..reply(_category('c1', 'Beverages', active: false))
      ..reply(_category('c1', 'Beverages'));

    final archived = await repository.setCategoryActive('c1', isActive: false);
    final restored = await repository.setCategoryActive('c1', isActive: true);

    expect(archived.isActive, isFalse);
    expect(restored.isActive, isTrue);
    expect(server.requests[0].json, {'is_active': false});
    expect(server.requests[1].json, {'is_active': true});
  });

  group('error translation', () {
    test('duplicate active name', () async {
      server.reply({
        'code': '23505',
        'message':
            'duplicate key value violates unique constraint '
            '"product_categories_shop_active_name_uidx"',
      }, status: 409);

      await expectLater(
        repository.createCategory(ProductCategoryName('drinks')),
        _throwsKind(ProductCategoryErrorKind.duplicateName),
      );
    });

    test('non-owner insert (RLS)', () async {
      server.reply({
        'code': '42501',
        'message': 'new row violates row-level security policy',
      }, status: 403);

      await expectLater(
        repository.createCategory(ProductCategoryName('Drinks')),
        _throwsKind(ProductCategoryErrorKind.permissionDenied),
      );
    });

    test('non-owner update returns no row', () async {
      server.reply({
        'code': 'PGRST116',
        'message': 'JSON object requested, multiple (or no) rows returned',
      }, status: 406);

      await expectLater(
        repository.setCategoryActive('c1', isActive: false),
        _throwsKind(ProductCategoryErrorKind.permissionDenied),
      );
    });

    test('name check violation', () async {
      server.reply({
        'code': '23514',
        'message': 'violates check constraint "product_categories_name_check"',
      }, status: 400);

      await expectLater(
        repository.renameCategory('c1', ProductCategoryName('X')),
        _throwsKind(ProductCategoryErrorKind.invalidName),
      );
    });

    test('other failures on load and save', () async {
      server.reply({'message': 'boom'}, status: 500);
      await expectLater(
        repository.getActiveCategories(),
        _throwsKind(ProductCategoryErrorKind.loadFailed),
      );

      server.reply({'message': 'boom'}, status: 500);
      await expectLater(
        repository.createCategory(ProductCategoryName('Drinks')),
        _throwsKind(ProductCategoryErrorKind.saveFailed),
      );
    });
  });

  group('product writes', () {
    Map<String, Object?> productRow({String? categoryId}) => {
      'id': 'p1',
      'name': 'Cola',
      'category': categoryId == null ? '' : 'Beverages',
      'category_id': categoryId,
      'product_categories': categoryId == null
          ? null
          : {'name': 'Beverages', 'is_active': true},
      'cost_price': 2,
      'selling_price': 3,
      'stock_quantity': 4,
      'low_stock_threshold': 1,
      'is_active': true,
    };

    Product product({String? categoryId}) => Product(
      id: 'p1',
      name: 'Cola',
      categoryId: categoryId,
      costPrice: 2,
      sellingPrice: 3,
      stockQuantity: 4,
      lowStockThreshold: 1,
    );

    test('create sends category_id, never the legacy text', () async {
      final products = ProductRepositoryImpl(ProductRemoteDataSource(client));
      server.reply(productRow(categoryId: 'c1'));

      final created = await products.createProduct(product(categoryId: 'c1'));

      final request = server.requests.single;
      expect(request.json['category_id'], 'c1');
      expect(request.json.containsKey('category'), isFalse);
      expect(
        request.uri.queryParameters['select'],
        contains('product_categories(name,is_active)'),
      );
      expect(created.categoryName, 'Beverages');
    });

    test('update can clear the category', () async {
      final products = ProductRepositoryImpl(ProductRemoteDataSource(client));
      server.reply(productRow());

      final updated = await products.updateProduct(product());

      final request = server.requests.single;
      expect(request.method, 'PATCH');
      expect(request.json.containsKey('category_id'), isTrue);
      expect(request.json['category_id'], isNull);
      expect(request.json.containsKey('category'), isFalse);
      expect(updated.categoryId, isNull);
    });
  });
}
