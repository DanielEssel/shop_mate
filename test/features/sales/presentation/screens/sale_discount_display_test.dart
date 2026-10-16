import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/domain/entities/sale_item.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/sales/presentation/screens/receipt_preview_screen.dart';
import 'package:shopmate/features/sales/presentation/screens/sale_details_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../../app/app_test_harness.dart';
import '../../../shop/shop_role_fixtures.dart';

/// A sale recorded with a discount: Rice 10.00 at 10% x2 and Soap 2.50 at
/// 12.5% x1, as the database stores it.
final _discounted = Sale(
  id: 'sale-d',
  saleNumber: 'SL-DISC',
  totalAmount: 20.19,
  discountAmount: 2.31,
  paymentMethod: 'cash',
  amountPaid: 25,
  changeAmount: 4.81,
  createdAt: DateTime(2026, 10, 15, 9),
);

final _discountedItems = [
  SaleItem(
    id: 'i1',
    saleId: 'sale-d',
    productId: 'rice',
    productName: 'Rice 1kg',
    quantity: 2,
    unitPrice: 9.00,
    costPrice: 6.00,
    subtotal: 18.00,
    originalUnitPrice: 10.00,
    discountPercentage: 10,
    discountAmount: 2.00,
    createdAt: DateTime(2026, 10, 15, 9),
  ),
  SaleItem(
    id: 'i2',
    saleId: 'sale-d',
    productId: 'soap',
    productName: 'Soap',
    quantity: 1,
    unitPrice: 2.19,
    costPrice: 0,
    subtotal: 2.19,
    originalUnitPrice: 2.50,
    discountPercentage: 12.5,
    discountAmount: 0.31,
    createdAt: DateTime(2026, 10, 15, 9),
  ),
  // Covered by an all-products discount but cost-protected: recorded with
  // no discount.
  SaleItem(
    id: 'i3',
    saleId: 'sale-d',
    productId: 'sugar',
    productName: 'Sugar',
    quantity: 1,
    unitPrice: 7.00,
    costPrice: 6.80,
    subtotal: 7.00,
    originalUnitPrice: 7.00,
    createdAt: DateTime(2026, 10, 15, 9),
  ),
];

/// A sale recorded before discounts existed (no snapshot values).
final _historical = Sale(
  id: 'sale-h',
  saleNumber: 'SL-OLD',
  totalAmount: 20.00,
  paymentMethod: 'cash',
  amountPaid: 20,
  changeAmount: 0,
  createdAt: DateTime(2026, 9, 1, 9),
);

final _historicalItems = [
  SaleItem(
    id: 'h1',
    saleId: 'sale-h',
    productId: 'rice',
    productName: 'Rice 1kg',
    quantity: 2,
    unitPrice: 10.00,
    costPrice: 6.00,
    subtotal: 20.00,
    createdAt: DateTime(2026, 9, 1, 9),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Widget Function(String id) screen,
  required Sale sale,
  required List<SaleItem> items,
  Size size = const Size(1280, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/sales/${sale.id}',
    routes: [
      GoRoute(
        path: '/sales/:id',
        builder: (_, state) => screen(state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        saleProvider.overrideWith((ref, id) async => sale),
        saleItemsProvider.overrideWith((ref, id) async => items),
        shopBrandingProvider.overrideWith(NoBranding.new),
        shopAccessProvider.overrideWith((ref) async => activeAccess('staff')),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _details(String id) => SaleDetailsScreen(saleId: id);
Widget _receipt(String id) => ReceiptPreviewScreen(saleId: id);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('sale details', () {
    for (final (label, size) in [
      ('desktop', const Size(1280, 2400)),
      ('phone', const Size(360, 2400)),
    ]) {
      testWidgets('shows the recorded discounts ($label)', (tester) async {
        await _pump(
          tester,
          screen: _details,
          sale: _discounted,
          items: _discountedItems,
          size: size,
        );

        expect(find.text('Discount'), findsOne);
        expect(find.text('GHS 2.31'), findsOne);
        expect(find.text('Was GHS 10.00 · 10% off (-GHS 2.00)'), findsOne);
        expect(find.text('Was GHS 2.50 · 12.5% off (-GHS 0.31)'), findsOne);
        // The cost-protected line shows no discount.
        expect(find.textContaining('Was GHS 7.00'), findsNothing);
        expect(find.text('GHS 20.19'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a sale from before discounts is unchanged', (tester) async {
      await _pump(
        tester,
        screen: _details,
        sale: _historical,
        items: _historicalItems,
      );

      expect(find.text('Discount'), findsNothing);
      expect(find.textContaining('Was GHS'), findsNothing);
      expect(find.text('GHS 20.00'), findsWidgets);
    });

    testWidgets('no cost or profit is shown', (tester) async {
      await _pump(
        tester,
        screen: _details,
        sale: _discounted,
        items: _discountedItems,
      );
      expect(find.textContaining('Cost'), findsNothing);
      expect(find.textContaining('Profit'), findsNothing);
      expect(find.textContaining('GHS 6.80'), findsNothing);
    });
  });

  group('receipt', () {
    for (final (label, size) in [
      ('desktop', const Size(1280, 2400)),
      ('phone', const Size(360, 2400)),
    ]) {
      testWidgets('subtotal, discount and total from the stored values '
          '($label)', (tester) async {
        await _pump(
          tester,
          screen: _receipt,
          sale: _discounted,
          items: _discountedItems,
          size: size,
        );

        // 18.00 + 2.19 + 7.00 charged, plus 2.31 off = 29.50 before.
        expect(find.text('Subtotal'), findsOne);
        expect(find.text('GHS 29.50'), findsOne);
        expect(find.text('Discount'), findsOne);
        expect(find.text('-GHS 2.31'), findsOne);
        expect(find.text('GHS 20.19'), findsOne);
        expect(find.text('Was GHS 10.00 · 10% off (-GHS 2.00)'), findsOne);
        expect(find.textContaining('Was GHS 7.00'), findsNothing);
        expect(find.textContaining('Cost'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a receipt from before discounts is unchanged', (tester) async {
      await _pump(
        tester,
        screen: _receipt,
        sale: _historical,
        items: _historicalItems,
      );

      expect(find.text('Subtotal'), findsOne);
      expect(find.text('Discount'), findsNothing);
      expect(find.textContaining('Was GHS'), findsNothing);
      // Line total, subtotal, total and the exact payment: all the
      // recorded 20.00.
      expect(find.text('GHS 20.00'), findsNWidgets(4));
    });
  });
}
