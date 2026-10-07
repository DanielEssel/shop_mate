import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/inventory/domain/entities/inventory_summary.dart';
import 'package:shopmate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:shopmate/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:shopmate/features/inventory/presentation/screens/low_stock_screen.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../shop/shop_role_fixtures.dart';

const _products = [
  Product(
    id: 'p1',
    name: 'Rice',
    costPrice: 10,
    sellingPrice: 15,
    stockQuantity: 2,
    lowStockThreshold: 5,
  ),
  Product(
    id: 'p2',
    name: 'Soap',
    costPrice: 3,
    sellingPrice: 5,
    stockQuantity: 40,
    lowStockThreshold: 5,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  String role,
  Widget screen, {
  Size size = const Size(1400, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith((ref) async => activeAccess(role)),
        productsProvider.overrideWith((ref) async => _products),
        lowStockProductsProvider.overrideWith((ref) async => [_products.first]),
        inventorySummaryProvider.overrideWith(
          (ref) async => const InventorySummary(
            totalProducts: 2,
            totalStockUnits: 42,
            lowStockProducts: 1,
            outOfStockProducts: 0,
          ),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('inventory', () {
    for (final size in [const Size(1400, 2400), const Size(420, 3000)]) {
      final label = size.width < 600 ? 'phone' : 'desktop';

      testWidgets('owner can adjust stock ($label)', (tester) async {
        await _pump(tester, ownerRole, const InventoryScreen(), size: size);

        expect(find.text('Adjust Stock'), findsOneWidget);
        expect(find.byTooltip('Adjust stock'), findsNWidgets(2));
      });

      testWidgets('attendant views stock but cannot adjust it ($label)', (
        tester,
      ) async {
        await _pump(tester, attendantRole, const InventoryScreen(), size: size);

        expect(find.text('Rice'), findsOneWidget);
        expect(find.text('Soap'), findsOneWidget);
        expect(find.text('Stock History'), findsOneWidget);
        expect(find.text('Adjust Stock'), findsNothing);
        expect(find.byTooltip('Adjust stock'), findsNothing);
      });
    }
  });

  group('low stock', () {
    testWidgets('owner can adjust a low-stock product', (tester) async {
      await _pump(tester, ownerRole, const LowStockScreen());

      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Adjust'), findsOneWidget);
    });

    testWidgets('attendant sees low stock without the Adjust action', (
      tester,
    ) async {
      await _pump(tester, attendantRole, const LowStockScreen());

      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Adjust'), findsNothing);
    });
  });
}
