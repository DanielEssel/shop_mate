// TEMPORARY visual-review renders.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/sales/presentation/screens/new_sale_screen.dart';
import 'package:shopmate/features/purchases/presentation/screens/new_purchase_screen.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';

import '../features/suppliers/presentation/supplier_test_harness.dart';
import 'visual_harness.dart';

final products = [
  for (var i = 0; i < 10; i++)
    Product(
      id: 'pr-$i',
      name: [
        'Rice 5kg',
        'Milo 400g Tin Chocolate Malt Drink Family Size',
        'Key Soap',
        'Indomie Chicken',
        'Sunlight Detergent',
        'Peak Milk Tin',
        'Frytol Oil 1L',
        'Sardines',
        'Sugar 1kg',
        'Tea Bags',
      ][i],
      costPrice: [80.0, 35.0, 6.0, 3.5, 14.0, 7.0, 30.0, 9.0, 12.0, 15.0][i],
      sellingPrice: [
        95.0,
        42.5,
        8.0,
        4.5,
        18.0,
        9.0,
        38.0,
        12.0,
        15.0,
        20.0,
      ][i],
      stockQuantity: [24, 3, 0, 120, 6, 48, 2, 30, 40, 12][i],
      lowStockThreshold: 5,
      categoryName: 'Groceries',
    ),
];

const customers = [
  Customer(id: 'c1', name: 'Ama Mensah', phone: '0241234567'),
  Customer(
    id: 'c2',
    name: 'Akosua Darko-Appiah Enterprises Limited',
    phone: '0201112233',
  ),
];

class _Customers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => customers;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

void main() {
  setUpAll(loadFonts);

  final sizes = {
    '320': const Size(320, 640),
    'phone': phone,
    'tablet': tablet,
    'desktop': desktop,
  };

  for (final entry in sizes.entries) {
    for (final state in ['empty', 'items', 'credit']) {
      testWidgets('new sale $state ${entry.key}', (tester) async {
        await pumpVisualApp(
          tester,
          size: entry.value,
          location: '/sales/new',
          extra: [
            salesProductsProvider.overrideWith((ref) async => products),
            customersProvider.overrideWith(_Customers.new),
          ],
        );
        if (state != 'empty') {
          final cart = _container(tester).read(saleCartProvider.notifier);
          cart
            ..addProduct(products[0])
            ..addProduct(products[0])
            ..addProduct(products[1])
            ..addProduct(products[3]);
          await tester.pump();
        }
        if (state == 'credit') {
          await tester.ensureVisible(find.text('Credit').last);
          await tester.pump();
          await tester.tap(find.text('Credit').last);
          await tester.pump();
        } else if (state == 'items') {
          final field = find.widgetWithText(TextField, 'Amount paid');
          await tester.ensureVisible(field);
          await tester.pump();
          await tester.enterText(field, '250');
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(NewSaleScreen), findsOneWidget);
        // Scroll back to top for the shot except for the payment states on
        // phones, where the payment section is what we want to see.
        await shoot(tester, 'newsale_${state}_${entry.key}');
      });
    }

    for (final state in ['empty', 'items']) {
      testWidgets('new purchase $state ${entry.key}', (tester) async {
        await pumpVisualApp(
          tester,
          size: entry.value,
          location: '/purchases/new',
          extra: [
            purchaseProductsProvider.overrideWith((ref) async => products),
            suppliersProvider.overrideWith(
              (ref) async => [
                supplier(
                  id: 's1',
                  name: 'Kumasi Wholesale',
                  phone: '0240000001',
                ),
              ],
            ),
          ],
        );
        if (state == 'items') {
          _container(tester).read(purchaseCartProvider.notifier)
            ..addProduct(products[0])
            ..addProduct(products[1])
            ..increaseQuantity(products[1].id);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(NewPurchaseScreen), findsOneWidget);
        await shoot(tester, 'newpurchase_${state}_${entry.key}');
      });
    }
  }

  testWidgets('new sale keyboard phone', (tester) async {
    debugDisableShadows = true;
    await pumpVisualApp(
      tester,
      size: phone,
      location: '/sales/new',
      extra: [
        salesProductsProvider.overrideWith((ref) async => products),
        customersProvider.overrideWith(_Customers.new),
      ],
    );
    _container(tester).read(saleCartProvider.notifier).addProduct(products[0]);
    await tester.pump();
    // Simulate a 300px keyboard.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final field = find.widgetWithText(TextField, 'Amount paid');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Complete Sale'), findsOneWidget);
    final button = tester.getRect(find.text('Complete Sale'));
    expect(button.bottom, lessThanOrEqualTo(phone.height - 300));
    await shoot(tester, 'newsale_keyboard_phone');
  });
}
