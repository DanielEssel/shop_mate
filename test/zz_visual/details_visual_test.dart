// TEMPORARY visual-review renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/app/router/app_router.dart';
import 'package:shopmate/features/customers/data/models/customer_credit_statement_model.dart';
import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/product_categories/presentation/providers/product_category_providers.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';

import '../features/suppliers/presentation/supplier_test_harness.dart';
import 'visual_harness.dart';

const _product = Product(
  id: 'p-milo',
  name: 'Milo 400g Tin Chocolate Malt Drink Family Size',
  costPrice: 35,
  sellingPrice: 42.5,
  stockQuantity: 3,
  lowStockThreshold: 5,
  categoryName: 'Beverages',
  sku: 'MILO-400',
  barcode: '6001087340106',
  description: 'Chocolate malt drink powder in a 400g tin.',
);

const _customer = Customer(
  id: 'c1',
  name: 'Akosua Darko-Appiah Enterprises',
  phone: '0201112233',
  email: 'akosua@darko-appiah.example',
  address: 'Kaneshie Market, Accra',
);

final _statement = CustomerCreditStatementModel.fromRows(
  creditSales: [
    {
      'id': 'sale-1',
      'sale_number': 'SL-2026-0038',
      'total_amount': 412.25,
      'created_at': '2026-10-07T11:24:00Z',
      'customer_payment_allocations': [
        {'amount': 100},
      ],
    },
    {
      'id': 'sale-2',
      'sale_number': 'SL-2026-0034',
      'total_amount': 33,
      'created_at': '2026-10-06T07:40:00Z',
      'customer_payment_allocations': <Map<String, Object?>>[],
    },
  ],
  payments: const [],
);

class _Customers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => const [_customer];
}

void main() {
  setUpAll(loadFonts);

  final sizes = {
    '320': const Size(320, 900),
    'phone': phone,
    'tablet': tablet,
    'desktop': desktop,
  };

  final overrides = [
    productByIdProvider.overrideWith((ref, id) async => _product),
    activeProductCategoriesProvider.overrideWith((ref) async => const []),
    customersProvider.overrideWith(_Customers.new),
    customerProvider.overrideWith((ref, id) async => _customer),
    customerCreditStatementProvider.overrideWith(
      (ref, id) async => _statement,
    ),
    supplierProvider.overrideWith(
      (ref, id) async => supplier(
        id: 's1',
        name: 'Kumasi Wholesale & Distribution',
        phone: '0240000001',
        address: 'Kumasi Central Market, Block C',
        isActive: false,
      ),
    ),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  for (final entry in sizes.entries) {
    for (final role in ['owner', 'staff']) {
      testWidgets('product $role ${entry.key}', (tester) async {
        final container = await pumpVisualApp(
          tester,
          size: entry.value,
          location: '/products/p-milo',
          role: role,
          extra: overrides,
        );
        expect(tester.takeException(), isNull);
        await shoot(tester, 'product_${role}_${entry.key}');

        container.read(routerProvider).push('/products/edit', extra: _product);
        await settle(tester);
        expect(tester.takeException(), isNull);
        await shoot(tester, 'productedit_${role}_${entry.key}');
      });
    }

    testWidgets('customer ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/customers/c1',
        extra: overrides,
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'customer_${entry.key}');

      await tester.tap(find.text('Edit Customer'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await shoot(tester, 'customeredit_${entry.key}');
    });

    testWidgets('customer staff ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/customers/c1',
        role: 'staff',
        extra: overrides,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Deactivate Customer'), findsNothing);
      await shoot(tester, 'customer_staff_${entry.key}');
    });

    testWidgets('supplier ${entry.key}', (tester) async {
      final container = await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/suppliers/s1',
        extra: overrides,
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'supplier_${entry.key}');

      container.read(routerProvider).push('/suppliers/s1/edit');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await shoot(tester, 'supplieredit_${entry.key}');
    });
  }
}
