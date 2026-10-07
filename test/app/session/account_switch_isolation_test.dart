import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:shopmate/features/auth/domain/entities/auth_credentials.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:shopmate/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:shopmate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopmate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';

/// One account's rows. Each account's data is tagged with its letter so a
/// leak is easy to spot.
class _Account {
  const _Account(this.letter, this.stock);

  final String letter;
  final int stock;

  String get userId => 'user-${letter.toLowerCase()}';
  String get email => '${letter.toLowerCase()}@shop.test';
  String get productId => 'product-${letter.toLowerCase()}';

  Map<String, Object?> get product => {
    'id': productId,
    'name': '$letter Rice',
    'category': '',
    'category_id': null,
    'product_categories': null,
    'sku': null,
    'barcode': null,
    'description': null,
    'cost_price': 10,
    'selling_price': 15,
    'stock_quantity': stock,
    'low_stock_threshold': 1,
    'image_url': null,
    'is_active': true,
    'created_at': '2026-10-01T09:00:00Z',
    'updated_at': '2026-10-01T09:00:00Z',
  };

  Map<String, Object?> get customer => {
    'id': 'customer-${letter.toLowerCase()}',
    'name': '$letter Customer',
    'phone': null,
    'email': null,
    'address': null,
    'notes': null,
    'is_active': true,
    'created_at': '2026-10-01T09:00:00Z',
    'updated_at': '2026-10-01T09:00:00Z',
  };

  Map<String, Object?> get sale => {
    'id': 'sale-${letter.toLowerCase()}',
    'sale_number': 'S-$letter-1',
    'total_amount': 15,
    'payment_method': 'cash',
    'amount_paid': 15,
    'change_amount': 0,
    'created_by': userId,
    'customer_id': null,
    'created_at': '2026-10-01T09:00:00Z',
  };

  Map<String, Object?> get purchase => {
    'id': 'purchase-${letter.toLowerCase()}',
    'purchase_number': 'P-$letter-1',
    'supplier_id': null,
    'supplier_name': '$letter Supplier',
    'supplier_phone': null,
    'total_amount': 10,
    'amount_paid': 10,
    'balance': 0,
    'payment_method': 'cash',
    'status': 'completed',
    'purchase_date': '2026-10-01',
    'notes': null,
    'created_by': userId,
    'created_at': '2026-10-01T09:00:00Z',
    'updated_at': '2026-10-01T09:00:00Z',
  };
}

const _a = _Account('A', 7);
const _b = _Account('B', 3);

/// Loopback stand-in for Supabase Auth and PostgREST. Like RLS, every data
/// request only sees the rows of the account whose token it carries; a
/// request without a user token sees nothing.
class _FakeBackend {
  late final HttpServer _server;

  /// (path, user id or null) of every data request, in order.
  final dataRequests = <(String, String?)>[];

  /// While set, customer list reads wait for it, so a test can act while a
  /// list is still loading.
  Completer<void>? holdCustomerList;

  String get url => 'http://${_server.address.host}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    final path = request.uri.path;
    final response = request.response
      ..headers.contentType = ContentType.json
      ..headers.set('x-supabase-api-version', '2024-01-01');

    if (path == '/auth/v1/token') {
      final body = Map<String, Object?>.from(jsonDecode(text) as Map);
      final account = body['email'] == _b.email ? _b : _a;
      response.write(jsonEncode(_session(account)));
    } else if (path == '/auth/v1/logout') {
      response.statusCode = HttpStatus.noContent;
    } else if (path.startsWith('/rest/v1/')) {
      final account = _accountFor(request);
      dataRequests.add((path, account?.userId));
      if (request.method == 'POST' &&
          path == '/rest/v1/customers' &&
          account != null) {
        final body = Map<String, Object?>.from(jsonDecode(text) as Map);
        response.write(
          jsonEncode({
            ...account.customer,
            'id': 'customer-new',
            'name': body['name'],
          }),
        );
      } else {
        final hold = holdCustomerList;
        if (path == '/rest/v1/customers' && hold != null) await hold.future;
        _writeRows(request, response, path, account);
      }
    } else {
      response.write('{}');
    }
    await response.close();
  }

  void _writeRows(
    HttpRequest request,
    HttpResponse response,
    String path,
    _Account? account,
  ) {
    final rows = switch ((path, account)) {
      (_, null) => <Map<String, Object?>>[],
      ('/rest/v1/products', final _Account a) => [a.product],
      ('/rest/v1/customers', final _Account a) => [a.customer],
      ('/rest/v1/sales', final _Account a) => [a.sale],
      ('/rest/v1/purchases', final _Account a) => [a.purchase],
      _ => <Map<String, Object?>>[],
    };
    final idFilter = request.uri.queryParameters['id'];
    final matching = idFilter == null
        ? rows
        : rows.where((row) => 'eq.${row['id']}' == idFilter).toList();

    final wantsOne =
        request.headers.value('accept')?.contains('vnd.pgrst.object') ?? false;
    if (!wantsOne) {
      response.write(jsonEncode(matching));
    } else if (matching.length == 1) {
      response.write(jsonEncode(matching.single));
    } else {
      response
        ..statusCode = HttpStatus.notAcceptable
        ..write(
          jsonEncode({
            'code': 'PGRST116',
            'message': 'JSON object requested, multiple (or no) rows returned',
          }),
        );
    }
  }

  static _Account? _accountFor(HttpRequest request) {
    final header = request.headers.value('authorization') ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final subject = (jsonDecode(payload) as Map)['sub'];
    if (subject == _a.userId) return _a;
    if (subject == _b.userId) return _b;
    return null;
  }

  static Map<String, Object?> _session(_Account account) {
    String part(Map<String, Object?> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(hours: 1));
    return {
      'access_token':
          '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
          '${part({'sub': account.userId, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.'
          'signature',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh-${account.userId}',
      'user': {
        'id': account.userId,
        'aud': 'authenticated',
        'email': account.email,
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
        'created_at': '2026-10-01T09:00:00Z',
      },
    };
  }
}

/// Dashboard totals per signed-in account (its RPC is covered elsewhere).
class _Dashboard implements DashboardRepository {
  @override
  Future<DashboardSummary> getDashboardSummary() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final account = userId == _b.userId ? _b : _a;
    return DashboardSummary(
      todaySales: 0,
      todayProfit: 0,
      todayTransactions: 0,
      totalProducts: account.stock,
      lowStockProducts: 0,
      outOfStockProducts: 0,
      recentSales: const [],
    );
  }
}

/// Names are joined so the record compares by value.
typedef _Snapshot = ({
  String products,
  String customers,
  String sales,
  String purchases,
  int inventoryUnits,
  int dashboardProducts,
});

void main() {
  final backend = _FakeBackend();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding fakes every HttpClient; this test talks to a real
    // loopback server instead.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await backend.start();
    await Supabase.initialize(
      url: backend.url,
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  tearDownAll(backend.stop);

  test('A signs in, loads data and fills both carts, signs out; B signs in '
      'and sees none of A\'s state', () async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [dashboardRepositoryProvider.overrideWithValue(_Dashboard())],
    );
    addTearDown(container.dispose);

    Future<void> signIn(_Account account) async {
      await container
          .read(signInProvider)
          .call(AuthCredentials(email: account.email, password: 'secret'));
      for (var i = 0; i < 50; i++) {
        if (container.read(currentUserIdProvider) == account.userId) return;
        await pumpEventQueue();
      }
      fail('the session never switched to ${account.userId}');
    }

    Future<_Snapshot> load() async {
      final products = await container.read(productsProvider.future);
      final customers = await container.read(customersProvider.future);
      final sales = await container.read(salesProvider.future);
      final purchases = await container.read(purchasesProvider.future);
      final inventory = await container.read(inventorySummaryProvider.future);
      final dashboard = await container.read(dashboardSummaryProvider.future);
      return (
        products: products.map((p) => p.name).join(', '),
        customers: customers.map((c) => c.name).join(', '),
        sales: sales.map((s) => s.saleNumber).join(', '),
        purchases: purchases.map((p) => p.purchaseNumber).join(', '),
        inventoryUnits: inventory.totalStockUnits,
        dashboardProducts: dashboard.totalProducts,
      );
    }

    // ---- User A ---------------------------------------------------------
    await signIn(_a);
    final seenByA = await load();
    expect(seenByA, (
      products: 'A Rice',
      customers: 'A Customer',
      sales: 'S-A-1',
      purchases: 'P-A-1',
      inventoryUnits: 7,
      dashboardProducts: 7,
    ));
    final aProduct = await container.read(
      productByIdProvider(_a.productId).future,
    );
    expect(aProduct.name, 'A Rice');

    container.read(saleCartProvider.notifier).addProduct(aProduct);
    container.read(purchaseCartProvider.notifier)
      ..addProduct(aProduct)
      ..updateQuantity(aProduct.id, 4);
    expect(container.read(saleCartProvider), hasLength(1));
    expect(container.read(purchaseCartProvider).single.quantity, 4);

    // ---- A signs out ----------------------------------------------------
    await container.read(authSessionProvider.notifier).signOut();

    expect(container.read(currentUserIdProvider), isNull);
    expect(container.read(saleCartProvider), isEmpty);
    expect(container.read(purchaseCartProvider), isEmpty);

    // ---- User B ---------------------------------------------------------
    final requestsBeforeB = backend.dataRequests.length;
    final customerListHeld = backend.holdCustomerList = Completer<void>();
    await signIn(_b);

    // Riverpod keeps a provider's last value as "previous" while it reloads
    // for B, so the raw state still carries A's customers at this moment.
    // That is why every `.value` read of account data goes through
    // `unwrapPrevious()`; `.when` already shows loading instead.
    final customersReloading = container.read(customersProvider);
    expect(customersReloading.isLoading, isTrue);
    expect(customersReloading.value?.map((c) => c.name), ['A Customer']);
    expect(customersReloading.unwrapPrevious().value, isNull);

    // A mutation that lands while B's list is still reloading must not merge
    // A's customers into B's list.
    await container
        .read(customersProvider.notifier)
        .createCustomer(name: 'B New Customer');
    expect(
      container.read(customersProvider).value?.map((c) => c.name),
      isNot(contains('A Customer')),
    );
    customerListHeld.complete();
    backend.holdCustomerList = null;
    // Back to the server's list (the fake does not store the insert).
    container.invalidate(customersProvider);

    final seenByB = await load();
    expect(seenByB, (
      products: 'B Rice',
      customers: 'B Customer',
      sales: 'S-B-1',
      purchases: 'P-B-1',
      inventoryUnits: 3,
      dashboardProducts: 3,
    ));
    expect(container.read(saleCartProvider), isEmpty);
    expect(container.read(purchaseCartProvider), isEmpty);

    // A's cached product detail is not served to B; B's own read of that id
    // goes to the server and, like RLS, finds nothing.
    await expectLater(
      container.read(productByIdProvider(_a.productId).future),
      throwsA(anything),
    );

    // Every request made for B's screens carried B's identity.
    final bRequests = backend.dataRequests.skip(requestsBeforeB);
    expect(bRequests, isNotEmpty);
    expect(bRequests.map((r) => r.$2).toSet(), {_b.userId});
  });
}
