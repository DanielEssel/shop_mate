import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/ui/ui.dart';
import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/domain/entities/sale_item.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/sales/presentation/screens/sale_details_screen.dart';

final _cashSale = Sale(
  id: 'sale-1',
  saleNumber: 'SL-2026-0041-LONG-REFERENCE',
  totalAmount: 1320.5,
  paymentMethod: 'mobile_money',
  amountPaid: 1400,
  changeAmount: 79.5,
  createdAt: DateTime(2026, 10, 8, 14, 12),
);

final _creditSale = Sale(
  id: 'sale-2',
  saleNumber: 'SL-2026-0038',
  totalAmount: 412.25,
  paymentMethod: 'credit',
  amountPaid: 100,
  changeAmount: 0,
  createdAt: DateTime(2026, 10, 7, 11, 24),
  customerId: 'c1',
);

final _items = [
  SaleItem(
    id: 'i1',
    saleId: 'sale-1',
    productId: 'p1',
    productName: 'Milo 400g Tin Chocolate Malt Drink Family Size',
    quantity: 12,
    unitPrice: 42.5,
    costPrice: 35,
    subtotal: 510,
    createdAt: DateTime(2026, 10, 8),
  ),
  SaleItem(
    id: 'i2',
    saleId: 'sale-1',
    productId: 'p2',
    productName: 'Rice 5kg',
    quantity: 1,
    unitPrice: 810.5,
    costPrice: 700,
    subtotal: 810.5,
    createdAt: DateTime(2026, 10, 8),
  ),
];

Future<GoRouter> _pump(
  WidgetTester tester, {
  required Future<Sale> Function() sale,
  Future<List<SaleItem>> Function()? items,
  Size size = const Size(390, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/sales/sale-1',
    routes: [
      GoRoute(
        path: '/sales/:id',
        builder: (_, state) =>
            SaleDetailsScreen(saleId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'receipt',
            builder: (_, _) => const Scaffold(body: Text('Receipt page')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        saleProvider.overrideWith((ref, id) => sale()),
        saleItemsProvider.overrideWith(
          (ref, id) => (items ?? () async => _items)(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows identity, figures, items and payment', (tester) async {
    await _pump(tester, sale: () async => _cashSale);

    expect(find.text('Sale Details'), findsOneWidget);
    expect(find.text('SL-2026-0041-LONG-REFERENCE'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    // Stored figures, formatted with the shared currency formatter.
    expect(find.text('GHS 1,320.50'), findsWidgets);
    expect(find.text('GHS 1,400.00'), findsOneWidget);
    expect(find.text('GHS 79.50'), findsOneWidget);
    // Items: stored line totals, not recomputed.
    expect(find.text('Rice 5kg'), findsOneWidget);
    expect(find.text('GHS 810.50'), findsWidgets);
    expect(find.text('Payment completed'), findsOneWidget);
  });

  testWidgets('a credit sale is marked as credit and shows no change', (
    tester,
  ) async {
    await _pump(tester, sale: () async => _creditSale);

    expect(find.text('Credit'), findsWidgets);
    expect(find.text('Change'), findsNothing);
    expect(find.text('Payment recorded as credit'), findsOneWidget);
  });

  testWidgets('loading shows a placeholder, not the content', (tester) async {
    final pending = Completer<Sale>();
    await _pump(tester, sale: () => pending.future);

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Sale Information'), findsNothing);

    pending.complete(_cashSale);
    await tester.pumpAndSettle();
    expect(find.text('Sale Information'), findsOneWidget);
  });

  testWidgets('an error offers a retry that reloads', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      sale: () async {
        calls++;
        if (calls == 1) throw Exception('Network down');
        return _cashSale;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load sale'), findsOneWidget);
    expect(find.text('Network down'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Sale Information'), findsOneWidget);
  });

  testWidgets('a sale without items says so', (tester) async {
    await _pump(
      tester,
      sale: () async => _cashSale,
      items: () async => const [],
    );

    expect(find.text('No items found for this sale.'), findsOneWidget);
  });

  testWidgets('View receipt opens the receipt', (tester) async {
    final router = await _pump(tester, sale: () async => _cashSale);

    await tester.tap(find.text('View receipt'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/sales/sale-1/receipt');
  });

  for (final (label, size, table) in [
    ('320px', const Size(320, 2400), false),
    ('tablet', const Size(820, 2400), true),
    ('desktop', const Size(1440, 2400), true),
  ]) {
    testWidgets('lays out without overflow at $label', (tester) async {
      await _pump(tester, sale: () async => _cashSale, size: size);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Wide layouts use a Product | Qty | Unit | Total table.
      expect(find.text('QTY'), table ? findsOneWidget : findsNothing);
      expect(find.text('View receipt').hitTestable(), findsOneWidget);
    });
  }
}
