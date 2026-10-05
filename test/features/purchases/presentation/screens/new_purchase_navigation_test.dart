import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/purchases/domain/entities/purchase.dart';
import 'package:shopmate/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/purchases/presentation/screens/new_purchase_screen.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../../suppliers/presentation/supplier_test_harness.dart';

const _rice = Product(
  id: 'product-rice',
  name: 'Rice 5kg',
  category: 'Food',
  costPrice: 20,
  sellingPrice: 30,
  stockQuantity: 10,
  lowStockThreshold: 2,
);

class _PurchaseRepository implements PurchaseRepository {
  int purchasesRead = 0;

  @override
  Future<Purchase> createPurchase({
    String? supplierName,
    String? supplierPhone,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
    required DateTime purchaseDate,
    String? notes,
    String? supplierId,
  }) async {
    return Purchase(
      id: 'purchase-1',
      purchaseNumber: 'PU-1',
      totalAmount: 20,
      amountPaid: 20,
      balance: 0,
      paymentMethod: paymentMethod,
      status: 'completed',
      purchaseDate: purchaseDate,
      createdAt: DateTime.utc(2026, 10, 6),
      updatedAt: DateTime.utc(2026, 10, 6),
    );
  }

  @override
  Future<List<Purchase>> getPurchases() async {
    purchasesRead++;
    return const [];
  }

  @override
  Future<Purchase> getPurchaseById(String id) => throw UnimplementedError();
}

/// A page with a title, so tests can tell where they are.
Widget _page(String title) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text('$title body')),
  );
}

/// Mirrors the app router's shape: tabs in a StatefulShellRoute on the root
/// navigator, and /purchases as a top-level route outside the shell.
GoRouter _router() {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => _page('Dashboard'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => _page('More'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/purchases',
        builder: (context, state) => _page('Purchases'),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const NewPurchaseScreen(),
          ),
          GoRoute(
            path: ':purchaseId',
            builder: (context, state) =>
                _page('Purchase Details ${state.pathParameters['purchaseId']}'),
          ),
        ],
      ),
    ],
  );
}

Future<(GoRouter, _PurchaseRepository)> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = _router();
  addTearDown(router.dispose);
  final purchases = _PurchaseRepository();

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        purchaseProductsProvider.overrideWith((ref) async => [_rice]),
        purchaseRepositoryProvider.overrideWithValue(purchases),
        supplierRepositoryProvider.overrideWithValue(
          FakeSupplierRepository([]),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return (router, purchases);
}

/// Opens New Purchase with [router.push], adds a product and saves.
Future<void> _pushNewPurchaseAndSave(
  WidgetTester tester,
  GoRouter router,
) async {
  router.push('/purchases/new');
  await tester.pumpAndSettle();
  expect(find.byType(NewPurchaseScreen), findsOneWidget);

  ProviderScope.containerOf(
    tester.element(find.byType(NewPurchaseScreen)),
  ).read(purchaseCartProvider.notifier).addProduct(_rice);
  await tester.pump();

  final complete = find.text('Complete Purchase');
  await tester.ensureVisible(complete);
  await tester.tap(complete);
  await tester.pumpAndSettle();

  expect(find.text('Purchase Details purchase-1'), findsOneWidget);
  expect(find.byType(NewPurchaseScreen), findsNothing);
}

void main() {
  setUpAll(disableFontFetching);

  testWidgets('from Purchases: Back from details returns to Purchases', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(tester);
    router.push('/purchases');
    await tester.pumpAndSettle();

    await _pushNewPurchaseAndSave(tester, router);

    // The details page sits on the existing stack, so it shows a back arrow.
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Purchases'), findsOneWidget);
    expect(find.byType(NewPurchaseScreen), findsNothing);

    // The shell is still underneath Purchases.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('from Dashboard: Back from details returns to Dashboard', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(tester);

    await _pushNewPurchaseAndSave(tester, router);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // No Purchases page was inserted under the details page.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Purchases'), findsNothing);
    expect(router.state.uri.path, '/dashboard');
  });

  testWidgets('system Back (Android) pops details back into the shell', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(tester);

    await _pushNewPurchaseAndSave(tester, router);
    expect(router.canPop(), isTrue);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Purchase Details purchase-1'), findsNothing);
  });

  testWidgets('saving still refreshes the purchase list', (tester) async {
    final (router, purchases) = await _pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Dashboard')),
    );
    final subscription = container.listen(purchasesProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(purchasesProvider.future);
    final readsBefore = purchases.purchasesRead;

    await _pushNewPurchaseAndSave(tester, router);

    expect(purchases.purchasesRead, greaterThan(readsBefore));
  });
}
