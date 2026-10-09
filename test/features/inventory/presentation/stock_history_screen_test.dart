import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/inventory/domain/entities/stock_movement.dart';
import 'package:shopmate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:shopmate/features/inventory/presentation/screens/stock_history_screen.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';

const _milo = Product(
  id: 'p1',
  name: 'Milo 400g Tin Chocolate Malt Drink Family Size',
  costPrice: 35,
  sellingPrice: 42.5,
  stockQuantity: 28,
  lowStockThreshold: 5,
);

const _soap = Product(
  id: 'p2',
  name: 'Key Soap',
  costPrice: 6,
  sellingPrice: 8,
  stockQuantity: 0,
  lowStockThreshold: 5,
);

final _movements = [
  StockMovement(
    id: 'm1',
    productId: 'p1',
    movementType: 'purchase',
    quantity: 40,
    previousQuantity: 0,
    newQuantity: 40,
    referenceId: 'PO-2026-0119',
    note: null,
    createdBy: 'u1',
    createdAt: DateTime(2026, 10, 7, 9),
  ),
  StockMovement(
    id: 'm2',
    productId: 'p1',
    movementType: 'sale',
    quantity: 12,
    previousQuantity: 40,
    newQuantity: 28,
    referenceId: 'SL-2026-0041',
    note: null,
    createdBy: 'u1',
    createdAt: DateTime(2026, 10, 8, 14),
  ),
  StockMovement(
    id: 'm3',
    productId: 'p2',
    movementType: 'adjustment',
    quantity: 3,
    previousQuantity: 3,
    newQuantity: 0,
    referenceId: null,
    note: 'Damaged in the storeroom during the rainy season leak',
    createdBy: 'u1',
    createdAt: DateTime(2026, 10, 8, 16),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  Future<List<StockMovement>> Function()? movements,
  Size size = const Size(390, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        stockMovementsProvider.overrideWith(
          (ref) => (movements ?? () async => _movements)(),
        ),
        productsProvider.overrideWith((ref) async => const [_milo, _soap]),
      ],
      child: const MaterialApp(home: StockHistoryScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('lists movements with product, type and signed change', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Stock History'), findsOneWidget);
    expect(find.text('3 records'), findsOneWidget);
    expect(find.text('Key Soap'), findsOneWidget);
    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('Stock Adjustment'), findsOneWidget);
    // Changes carry a sign and an arrow, not only a colour.
    expect(find.text('+40'), findsOneWidget);
    expect(find.text('-12'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNWidgets(2));
    // Viewing history offers no way to change stock.
    expect(find.text('Adjust Stock'), findsNothing);
    expect(find.byTooltip('Adjust stock'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('type filter and search narrow the list', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    expect(find.text('1 record'), findsOneWidget);
    expect(find.text('-12'), findsOneWidget);
    expect(find.text('+40'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'storeroom');
    await tester.pumpAndSettle();
    expect(find.text('1 record'), findsOneWidget);
    expect(find.text('Key Soap'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nothing matches');
    await tester.pumpAndSettle();
    expect(find.text('No stock movements found'), findsOneWidget);
  });

  testWidgets('tapping a movement shows everything recorded about it', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Key Soap'));
    await tester.pumpAndSettle();

    expect(find.text('Stock Movement'), findsOneWidget);
    expect(find.text('Quantity removed'), findsOneWidget);
    expect(find.text('Stock before'), findsOneWidget);
    expect(find.text('Stock after'), findsOneWidget);
    expect(
      find.text('Damaged in the storeroom during the rainy season leak'),
      findsWidgets,
    );
    // No reference was recorded for this adjustment.
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('loading, then an error with Retry', (tester) async {
    final pending = Completer<List<StockMovement>>();
    var calls = 0;
    await _pump(
      tester,
      movements: () {
        calls++;
        return calls == 1 ? pending.future : Future.value(_movements);
      },
    );
    expect(find.text('3 records'), findsNothing);

    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load stock history'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('3 records'), findsOneWidget);
  });

  for (final (label, size, table) in [
    ('320px', const Size(320, 2400), false),
    ('desktop', const Size(1440, 2400), true),
  ]) {
    testWidgets('lays out without overflow at $label', (tester) async {
      await _pump(tester, size: size);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Desktop shows a table with a Movement column; phones show rows.
      expect(find.text('MOVEMENT'), table ? findsOneWidget : findsNothing);
    });
  }
}
