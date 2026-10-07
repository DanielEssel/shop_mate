import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/purchases/domain/entities/purchase.dart';
import 'package:shopmate/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/purchases/presentation/screens/new_purchase_screen.dart';
import 'package:shopmate/features/suppliers/domain/entities/supplier.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../../suppliers/presentation/supplier_test_harness.dart';

const _rice = Product(
  id: 'product-rice',
  name: 'Rice 5kg',
  categoryName: 'Food',
  costPrice: 20,
  sellingPrice: 30,
  stockQuantity: 10,
  lowStockThreshold: 2,
);

List<Supplier> _suppliers() {
  return [
    supplier(id: 's-kofi', name: 'Kofi Bentley', phone: '0240000001'),
    supplier(id: 's-tuth', name: 'Tuth'),
    supplier(id: 's-ama', name: 'Ama Wholesale', isActive: false),
  ];
}

/// Records what reaches CreatePurchase; optionally fails with [error].
class _RecordingPurchaseRepository implements PurchaseRepository {
  final calls = <Map<String, Object?>>[];
  Object? error;

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
    calls.add({
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
    });
    final failure = error;
    if (failure != null) throw failure;

    return Purchase(
      id: 'purchase-1',
      purchaseNumber: 'PU-1',
      totalAmount: 20,
      amountPaid: 0,
      balance: 20,
      paymentMethod: paymentMethod,
      status: 'completed',
      purchaseDate: purchaseDate,
      createdAt: DateTime.utc(2026, 10, 6),
      updatedAt: DateTime.utc(2026, 10, 6),
      supplierId: supplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
    );
  }

  @override
  Future<List<Purchase>> getPurchases() => throw UnimplementedError();

  @override
  Future<Purchase> getPurchaseById(String id) => throw UnimplementedError();
}

class _Harness {
  _Harness(this.suppliers, this.purchases);

  final FakeSupplierRepository suppliers;
  final _RecordingPurchaseRepository purchases;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<Supplier>? suppliers,
  Size size = const Size(420, 3000),
  void Function(FakeSupplierRepository repository)? configure,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final supplierRepository = FakeSupplierRepository(suppliers ?? _suppliers());
  configure?.call(supplierRepository);
  final purchaseRepository = _RecordingPurchaseRepository();

  final router = GoRouter(
    initialLocation: '/purchases/new',
    routes: [
      GoRoute(
        path: '/purchases/new',
        builder: (context, state) => const NewPurchaseScreen(),
      ),
      GoRoute(
        path: '/purchases/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Purchase ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        // The purchase draft is scoped to the signed-in account.
        currentUserIdProvider.overrideWithValue('user-1'),
        purchaseProductsProvider.overrideWith((ref) async => [_rice]),
        purchaseRepositoryProvider.overrideWithValue(purchaseRepository),
        supplierRepositoryProvider.overrideWithValue(supplierRepository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  ProviderScope.containerOf(
    tester.element(find.byType(NewPurchaseScreen)),
  ).read(purchaseCartProvider.notifier).addProduct(_rice);
  await tester.pump();

  return _Harness(supplierRepository, purchaseRepository);
}

Finder get _dropdown => find.byType(DropdownButtonFormField<String?>);

Finder _textField(String label) => find.widgetWithText(TextFormField, label);

EditableText _editable(WidgetTester tester, String label) {
  return tester.widget<EditableText>(
    find.descendant(of: _textField(label), matching: find.byType(EditableText)),
  );
}

Future<void> _choose(WidgetTester tester, String itemText) async {
  await tester.tap(_dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

Future<void> _complete(WidgetTester tester) async {
  final button = find.text('Complete Purchase');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(disableFontFetching);

  testWidgets('lists active suppliers only, defaulting to none', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('No saved supplier'), findsOneWidget);

    await tester.tap(_dropdown);
    await tester.pumpAndSettle();

    expect(find.text('Kofi Bentley · 0240000001'), findsOneWidget);
    expect(find.text('Tuth'), findsOneWidget);
    expect(find.textContaining('Ama Wholesale'), findsNothing);
  });

  testWidgets('selecting fills and locks the snapshot fields', (tester) async {
    await _pump(tester);

    await _choose(tester, 'Kofi Bentley · 0240000001');

    expect(_editable(tester, 'Supplier name').controller.text, 'Kofi Bentley');
    expect(_editable(tester, 'Supplier phone').controller.text, '0240000001');
    expect(_editable(tester, 'Supplier name').readOnly, isTrue);
    expect(_editable(tester, 'Supplier phone').readOnly, isTrue);
    expect(find.text('From the selected saved supplier'), findsOneWidget);
    expect(find.text('Clear supplier'), findsOneWidget);
  });

  testWidgets('a supplier without a phone leaves the phone empty', (
    tester,
  ) async {
    await _pump(tester);

    await _choose(tester, 'Tuth');

    expect(_editable(tester, 'Supplier phone').controller.text, isEmpty);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('saving a selected supplier passes its id and snapshot', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await _choose(tester, 'Kofi Bentley · 0240000001');
    await _complete(tester);

    expect(harness.purchases.calls.single, {
      'supplierId': 's-kofi',
      'supplierName': 'Kofi Bentley',
      'supplierPhone': '0240000001',
    });
    expect(find.text('Purchase purchase-1'), findsOneWidget);
  });

  testWidgets('manual entry with no saved supplier sends supplierId null', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await tester.enterText(_textField('Supplier name'), ' ABC Trading ');
    await tester.enterText(_textField('Supplier phone'), '0241234567');
    await _complete(tester);

    expect(harness.purchases.calls.single, {
      'supplierId': null,
      'supplierName': 'ABC Trading',
      'supplierPhone': '0241234567',
    });
  });

  testWidgets('no supplier and no details is still a valid purchase', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await _complete(tester);

    expect(harness.purchases.calls.single, {
      'supplierId': null,
      'supplierName': null,
      'supplierPhone': null,
    });
  });

  testWidgets('clearing unlocks the fields and restores manual input', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await tester.enterText(_textField('Supplier name'), 'Typed Name');
    await _choose(tester, 'Kofi Bentley · 0240000001');
    await tester.tap(find.text('Clear supplier'));
    await tester.pumpAndSettle();

    expect(find.text('Clear supplier'), findsNothing);
    expect(_editable(tester, 'Supplier name').readOnly, isFalse);
    expect(_editable(tester, 'Supplier name').controller.text, 'Typed Name');

    await tester.enterText(_textField('Supplier phone'), '0209999999');
    await _complete(tester);

    expect(harness.purchases.calls.single, {
      'supplierId': null,
      'supplierName': 'Typed Name',
      'supplierPhone': '0209999999',
    });
  });

  testWidgets('choosing "No saved supplier" also clears the selection', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await _choose(tester, 'Tuth');
    await _choose(tester, 'No saved supplier');
    expect(_editable(tester, 'Supplier name').readOnly, isFalse);

    await _complete(tester);
    expect(harness.purchases.calls.single['supplierId'], isNull);
  });

  testWidgets('loading suppliers does not block the form', (tester) async {
    final pending = Completer<List<Supplier>>();
    await _pump(
      tester,
      configure: (repository) => repository.pendingList = pending,
      settle: false,
    );

    expect(find.text('Loading saved suppliers...'), findsOneWidget);
    await tester.enterText(_textField('Supplier name'), 'While Loading');
    expect(_editable(tester, 'Supplier name').readOnly, isFalse);

    pending.complete(_suppliers().where((s) => s.isActive).toList());
    await tester.pumpAndSettle();
    expect(_dropdown, findsOneWidget);
  });

  testWidgets('a supplier load error keeps manual entry and offers retry', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      configure: (repository) =>
          repository.nextListError = Exception('PGRST raw text'),
    );

    expect(
      find.textContaining('Could not load saved suppliers'),
      findsOneWidget,
    );
    expect(find.textContaining('PGRST'), findsNothing);

    await tester.enterText(_textField('Supplier name'), 'Manual Co');
    await _complete(tester);
    expect(harness.purchases.calls.single['supplierName'], 'Manual Co');
  });

  testWidgets('Retry reloads saved suppliers', (tester) async {
    await _pump(
      tester,
      configure: (repository) =>
          repository.nextListError = Exception('offline'),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(_dropdown, findsOneWidget);
  });

  testWidgets('no saved suppliers shows a hint and keeps manual entry', (
    tester,
  ) async {
    final harness = await _pump(tester, suppliers: []);

    expect(
      find.text('No saved suppliers yet. Enter supplier details below.'),
      findsOneWidget,
    );
    expect(_dropdown, findsNothing);

    await tester.enterText(_textField('Supplier name'), 'First Supplier');
    await _complete(tester);
    expect(harness.purchases.calls.single['supplierName'], 'First Supplier');
  });

  testWidgets(
    'an inactive supplier rejection is friendly, clears and refreshes',
    (tester) async {
      final harness = await _pump(tester);
      await _choose(tester, 'Kofi Bentley · 0240000001');
      final listReadsBefore = harness.suppliers.listRequests.length;
      harness.purchases.error = const PostgrestException(
        message:
            'Supplier s-kofi not found, inactive, or unavailable for this shop',
        code: 'P0001',
      );

      await _complete(tester);

      expect(
        find.text(
          'This supplier is no longer active. Please select another supplier.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('unavailable for this shop'), findsNothing);
      expect(find.text('Clear supplier'), findsNothing);
      expect(_editable(tester, 'Supplier name').readOnly, isFalse);
      expect(find.text('No saved supplier'), findsOneWidget);
      expect(
        harness.suppliers.listRequests.length,
        greaterThan(listReadsBefore),
      );
      expect(harness.purchases.calls, hasLength(1));
      expect(find.byType(NewPurchaseScreen), findsOneWidget);
    },
  );

  testWidgets('a background refresh keeps the current selection', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _choose(tester, 'Kofi Bentley · 0240000001');

    harness.suppliers.suppliers.removeWhere((s) => s.id == 's-kofi');
    ProviderScope.containerOf(
      tester.element(find.byType(NewPurchaseScreen)),
    ).invalidate(suppliersProvider);
    await tester.pumpAndSettle();

    expect(find.text('Clear supplier'), findsOneWidget);
    expect(_editable(tester, 'Supplier name').controller.text, 'Kofi Bentley');
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 1280]) {
    testWidgets('supplier section works at ${width.toInt()}px', (tester) async {
      final harness = await _pump(tester, size: Size(width, 3000));

      await _choose(tester, 'Kofi Bentley · 0240000001');

      expect(tester.takeException(), isNull);
      expect(_editable(tester, 'Supplier name').readOnly, isTrue);

      await _complete(tester);
      expect(harness.purchases.calls.single['supplierId'], 's-kofi');
    });
  }
}
