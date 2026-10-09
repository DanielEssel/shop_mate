import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/ui/ui.dart';
import 'package:shopmate/features/purchases/domain/entities/purchase.dart';
import 'package:shopmate/features/purchases/domain/entities/purchase_item.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/purchases/presentation/screens/purchase_details_screen.dart';

Purchase _purchase({
  String? supplierName = 'Kumasi Wholesale & Distribution Limited',
  double balance = 850,
  String? notes = 'Deliver to the back door.',
}) {
  return Purchase(
    id: 'pu-1',
    purchaseNumber: 'PO-2026-0119-LONG-REFERENCE',
    supplierName: supplierName,
    supplierPhone: supplierName == null ? null : '0302123456',
    totalAmount: 1850,
    amountPaid: 1850 - balance,
    balance: balance,
    paymentMethod: 'bank_transfer',
    status: 'completed',
    purchaseDate: DateTime(2026, 10, 7),
    notes: notes,
    createdAt: DateTime(2026, 10, 7),
    updatedAt: DateTime(2026, 10, 7),
  );
}

final _items = [
  PurchaseItem(
    id: 'i1',
    purchaseId: 'pu-1',
    productId: 'p1',
    productName: 'Milo 400g Tin Chocolate Malt Drink Family Size',
    quantity: 40,
    unitCost: 35,
    subtotal: 1400,
    createdAt: DateTime(2026, 10, 7),
  ),
  PurchaseItem(
    id: 'i2',
    purchaseId: 'pu-1',
    productId: 'p2',
    productName: 'Key Soap',
    quantity: 75,
    unitCost: 6,
    subtotal: 450,
    createdAt: DateTime(2026, 10, 7),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Future<Purchase> Function() purchase,
  Future<List<PurchaseItem>> Function()? items,
  Size size = const Size(390, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        purchaseProvider.overrideWith((ref, id) => purchase()),
        purchaseItemsProvider.overrideWith(
          (ref, id) => (items ?? () async => _items)(),
        ),
      ],
      child: const MaterialApp(home: PurchaseDetailsScreen(purchaseId: 'pu-1')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows identity, figures, supplier, items and notes', (
    tester,
  ) async {
    await _pump(tester, purchase: () async => _purchase());

    expect(find.text('Purchase Details'), findsOneWidget);
    expect(find.text('PO-2026-0119-LONG-REFERENCE'), findsOneWidget);
    // Status badge plus the Status field.
    expect(find.text('Completed'), findsNWidgets(2));
    expect(find.text('Balance due'), findsOneWidget);
    // Stored figures.
    expect(find.text('GHS 1,850.00'), findsWidgets);
    expect(find.text('GHS 1,000.00'), findsOneWidget);
    expect(find.text('GHS 850.00'), findsOneWidget);
    expect(find.text('Still owed'), findsOneWidget);
    // Supplier, items with stored line totals, notes.
    expect(find.text('0302123456'), findsOneWidget);
    expect(find.text('Key Soap'), findsOneWidget);
    expect(find.text('GHS 450.00'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Deliver to the back door.'), findsOneWidget);
  });

  testWidgets('a fully paid purchase without supplier or notes', (
    tester,
  ) async {
    await _pump(
      tester,
      purchase: () async =>
          _purchase(supplierName: null, balance: 0, notes: null),
    );

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Fully paid'), findsOneWidget);
    expect(find.text('Fully Paid'), findsOneWidget);
    expect(find.text('Not provided'), findsNWidgets(2));
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('loading shows a placeholder', (tester) async {
    final pending = Completer<Purchase>();
    await _pump(tester, purchase: () => pending.future);

    expect(find.byType(SkeletonBox), findsWidgets);

    pending.complete(_purchase());
    await tester.pumpAndSettle();
    expect(find.text('Purchased Products'), findsOneWidget);
  });

  testWidgets('a load error offers a retry', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      purchase: () async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return _purchase();
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load purchase'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('PO-2026-0119-LONG-REFERENCE'), findsOneWidget);
  });

  testWidgets('item errors and empty items are shown in the items section', (
    tester,
  ) async {
    await _pump(
      tester,
      purchase: () async => _purchase(),
      items: () async => throw Exception('items failed'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load purchase items'), findsOneWidget);
    // The rest of the purchase still shows.
    expect(find.text('Supplier'), findsOneWidget);
  });

  testWidgets('no items says so', (tester) async {
    await _pump(
      tester,
      purchase: () async => _purchase(),
      items: () async => const [],
    );
    expect(find.text('No purchase items found.'), findsOneWidget);
  });

  for (final (label, size, table) in [
    ('320px', const Size(320, 2600), false),
    ('tablet', const Size(820, 2600), true),
    ('desktop', const Size(1440, 2600), true),
  ]) {
    testWidgets('lays out without overflow at $label', (tester) async {
      await _pump(tester, purchase: () async => _purchase(), size: size);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('UNIT COST'), table ? findsOneWidget : findsNothing);
    });
  }
}
