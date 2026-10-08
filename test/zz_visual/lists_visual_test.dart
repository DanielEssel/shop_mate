// TEMPORARY visual-review renders.
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/expenses/domain/entities/expense.dart';
import 'package:shopmate/features/expenses/domain/entities/expense_category.dart';
import 'package:shopmate/features/expenses/domain/entities/expense_history.dart';
import 'package:shopmate/features/expenses/domain/entities/expense_payment_method.dart';
import 'package:shopmate/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:shopmate/features/purchases/domain/entities/purchase.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/inventory/domain/entities/inventory_summary.dart';
import 'package:shopmate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/products/presentation/providers/products_provider.dart';
import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';

import 'visual_harness.dart';

final sampleSales = [
  for (var i = 0; i < 9; i++)
    Sale(
      id: 'sale-$i',
      saleNumber: 'SL-2026-00${41 - i}',
      totalAmount: [
        245.0,
        1320.5,
        58.0,
        412.25,
        96.0,
        75.5,
        980.0,
        33.0,
        150.0,
      ][i],
      paymentMethod: [
        'cash',
        'mobile_money',
        'cash',
        'credit',
        'card',
        'cash',
        'bank_transfer',
        'credit',
        'mobile_money',
      ][i],
      amountPaid: [250.0, 1320.5, 60.0, 0.0, 96.0, 80.0, 980.0, 10.0, 150.0][i],
      changeAmount: 0,
      createdAt: DateTime(2026, 10, 8 - i ~/ 3, 14 - i, 12 + i * 4),
    ),
];

final samplePurchases = [
  for (var i = 0; i < 6; i++)
    Purchase(
      id: 'p-$i',
      purchaseNumber: 'PO-2026-01${20 - i}',
      supplierName: [
        'Kumasi Wholesale',
        'Accra Beverages Ltd',
        null,
        'Tema Foods',
        'Makola Traders',
        'Kasoa Supplies',
      ][i],
      totalAmount: [4200.0, 1850.0, 620.0, 3100.0, 980.0, 2250.0][i],
      amountPaid: [4200.0, 1000.0, 620.0, 3100.0, 0.0, 2250.0][i],
      balance: [0.0, 850.0, 0.0, 0.0, 980.0, 0.0][i],
      paymentMethod: 'cash',
      status: 'completed',
      purchaseDate: DateTime(2026, 10, 8 - i),
      createdAt: DateTime(2026, 10, 8 - i),
      updatedAt: DateTime(2026, 10, 8 - i),
    ),
];

final sampleExpenses = ExpenseHistory(
  hasMore: false,
  expenses: [
    for (var i = 0; i < 6; i++)
      Expense(
        id: 'e-$i',
        category: ExpenseCategory.values[i],
        amount: [1500.0, 320.5, 85.0, 2400.0, 140.0, 60.0][i],
        paymentMethod: ExpensePaymentMethod.values.first,
        expenseDate: DateTime(2026, 10, 8 - i),
        reference: i.isEven ? 'RCPT-${400 + i}' : null,
        createdAt: DateTime(2026, 10, 8 - i),
        updatedAt: DateTime(2026, 10, 8 - i),
      ),
  ],
);

final sampleProducts = [
  for (var i = 0; i < 7; i++)
    Product(
      id: 'pr-$i',
      name: [
        'Rice 5kg',
        'Milo 400g',
        'Key Soap',
        'Indomie Chicken',
        'Sunlight Detergent',
        'Peak Milk Tin',
        'Frytol Oil 1L',
      ][i],
      costPrice: 10,
      sellingPrice: [95.0, 42.5, 8.0, 4.5, 18.0, 9.0, 38.0][i],
      stockQuantity: [24, 3, 0, 120, 6, 48, 2][i],
      lowStockThreshold: 5,
      categoryName: [
        'Grains',
        'Beverages',
        'Toiletries',
        'Food',
        'Household',
        'Dairy',
        'Food',
      ][i],
    ),
];

void main() {
  setUpAll(loadFonts);

  final sizes = {'phone': phone, 'tablet': tablet, 'desktop': desktop};

  for (final entry in sizes.entries) {
    testWidgets('sales ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/sales',
        extra: [salesProvider.overrideWith((ref) async => sampleSales)],
      );
      await shoot(tester, 'sales_${entry.key}');
    });
  }

  for (final entry in sizes.entries) {
    testWidgets('purchases ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/purchases',
        extra: [purchasesProvider.overrideWith((ref) async => samplePurchases)],
      );
      await shoot(tester, 'purchases_${entry.key}');
    });
    testWidgets('expenses ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/expenses',
        extra: [
          expenseHistoryProvider.overrideWith((ref) async => sampleExpenses),
        ],
      );
      await shoot(tester, 'expenses_${entry.key}');
    });
  }

  for (final entry in sizes.entries) {
    testWidgets('inventory ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/inventory',
        extra: [
          productsProvider.overrideWith((ref) async => sampleProducts),
          inventorySummaryProvider.overrideWith(
            (ref) async => const InventorySummary(
              totalProducts: 7,
              totalStockUnits: 203,
              lowStockProducts: 2,
              outOfStockProducts: 1,
            ),
          ),
        ],
      );
      await shoot(tester, 'inventory_${entry.key}');
    });
    testWidgets('more ${entry.key}', (tester) async {
      await pumpVisualApp(tester, size: entry.value, location: '/more');
      await shoot(tester, 'more_${entry.key}');
    });
  }
}
