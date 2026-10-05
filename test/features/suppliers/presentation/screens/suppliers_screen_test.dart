import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/suppliers/domain/entities/supplier.dart';
import 'package:shopmate/features/suppliers/presentation/screens/suppliers_screen.dart';
import 'package:shopmate/features/suppliers/presentation/widgets/supplier_card.dart';

import '../supplier_test_harness.dart';

List<Supplier> _seed() {
  return [
    supplier(
      id: 's-kofi',
      name: 'Kofi Bentley',
      phone: '0240000001',
      email: 'kofi@bentley.example',
      address: 'Kumasi Central Market',
    ),
    supplier(id: 's-tuth', name: 'Tuth', phone: '0551234567'),
    supplier(
      id: 's-ama',
      name: 'Ama Wholesale',
      isActive: false,
      email: 'orders@ama.example',
    ),
  ];
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
}

Future<void> _tapFilter(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(disableFontFetching);

  testWidgets('shows active suppliers by default, ordered by name', (
    tester,
  ) async {
    final repository = FakeSupplierRepository(_seed());
    await pumpSupplierApp(tester, repository);

    expect(repository.listRequests, [false]);
    expect(find.byType(SupplierCard), findsNWidgets(2));
    expect(find.text('Kofi Bentley'), findsOneWidget);
    expect(find.text('Tuth'), findsOneWidget);
    expect(find.text('Ama Wholesale'), findsNothing);
    expect(find.text('2 suppliers'), findsOneWidget);

    final kofiTop = tester.getTopLeft(find.text('Kofi Bentley')).dy;
    final tuthTop = tester.getTopLeft(find.text('Tuth')).dy;
    expect(kofiTop, lessThan(tuthTop));
  });

  testWidgets('cards show status as text, not color alone', (tester) async {
    await pumpSupplierApp(tester, FakeSupplierRepository(_seed()));

    expect(find.text('Active'), findsWidgets);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsWidgets);
    expect(find.text('0240000001'), findsOneWidget);
    expect(find.text('Kumasi Central Market'), findsOneWidget);
  });

  testWidgets('Inactive filter loads every supplier and shows inactive only', (
    tester,
  ) async {
    final repository = FakeSupplierRepository(_seed());
    await pumpSupplierApp(tester, repository);

    await _tapFilter(tester, 'Inactive');

    expect(repository.listRequests.last, isTrue);
    expect(find.byType(SupplierCard), findsOneWidget);
    expect(find.text('Ama Wholesale'), findsOneWidget);
    expect(find.text('Kofi Bentley'), findsNothing);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);
  });

  testWidgets('All filter shows active and inactive suppliers', (tester) async {
    final repository = FakeSupplierRepository(_seed());
    await pumpSupplierApp(tester, repository);

    await _tapFilter(tester, 'All');

    expect(repository.listRequests.last, isTrue);
    expect(find.byType(SupplierCard), findsNWidgets(3));
    expect(find.text('3 suppliers'), findsOneWidget);
  });

  testWidgets('searches by name, case-insensitively and trimmed', (
    tester,
  ) async {
    await pumpSupplierApp(tester, FakeSupplierRepository(_seed()));

    await _search(tester, '  KOFI ');

    expect(find.byType(SupplierCard), findsOneWidget);
    expect(find.text('Kofi Bentley'), findsOneWidget);
  });

  testWidgets('searches by phone', (tester) async {
    await pumpSupplierApp(tester, FakeSupplierRepository(_seed()));

    await _search(tester, '0551');

    expect(find.byType(SupplierCard), findsOneWidget);
    expect(find.text('Tuth'), findsOneWidget);
  });

  testWidgets('searches by email, safely skipping suppliers without one', (
    tester,
  ) async {
    await pumpSupplierApp(tester, FakeSupplierRepository(_seed()));

    await _search(tester, 'BENTLEY.EXAMPLE');

    expect(find.byType(SupplierCard), findsOneWidget);
    expect(find.text('Kofi Bentley'), findsOneWidget);
  });

  testWidgets('no search results offers to clear search and widen filter', (
    tester,
  ) async {
    await pumpSupplierApp(tester, FakeSupplierRepository(_seed()));

    await _search(tester, 'ama');

    expect(find.text('No suppliers found'), findsOneWidget);
    expect(find.byType(SupplierCard), findsNothing);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Search all suppliers'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ama Wholesale'), findsOneWidget);

    await _tapFilter(tester, 'Active');
    expect(find.text('No suppliers found'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(SupplierCard), findsNWidgets(2));
  });

  testWidgets('empty shop shows the no-suppliers state with Add supplier', (
    tester,
  ) async {
    await pumpSupplierApp(tester, FakeSupplierRepository([]));

    expect(find.text('No active suppliers'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add supplier'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Show all suppliers'));
    await tester.pumpAndSettle();
    expect(find.text('No suppliers yet'), findsOneWidget);
  });

  testWidgets('no inactive suppliers has its own empty state', (tester) async {
    await pumpSupplierApp(
      tester,
      FakeSupplierRepository([supplier(id: 's-1', name: 'Tuth')]),
    );

    await _tapFilter(tester, 'Inactive');

    expect(find.text('No inactive suppliers'), findsOneWidget);
    expect(find.textContaining('Unable to load'), findsNothing);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    final repository = FakeSupplierRepository(_seed())
      ..pendingList = Completer<List<Supplier>>();
    final pending = repository.pendingList!;
    await pumpSupplierApp(tester, repository, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SupplierCard), findsNothing);

    pending.complete(_seed().where((s) => s.isActive).toList());
    await tester.pumpAndSettle();
    expect(find.byType(SupplierCard), findsNWidgets(2));
  });

  testWidgets('shows a friendly error with Retry that reloads', (tester) async {
    final repository = FakeSupplierRepository(_seed())
      ..nextListError = Exception('PGRST301 raw database text');
    await pumpSupplierApp(tester, repository);

    expect(find.text('Unable to load suppliers'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.textContaining('PGRST301'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(SupplierCard), findsNWidgets(2));
  });

  testWidgets('tapping a supplier opens its details', (tester) async {
    await pumpSupplierApp(tester, FakeSupplierRepository(_seed()));

    await tester.tap(find.text('Tuth'));
    await tester.pumpAndSettle();

    expect(find.text('Supplier Details'), findsOneWidget);
    expect(find.byType(SuppliersScreen), findsNothing);
  });

  for (final width in <double>[320, 1280]) {
    testWidgets('lays out without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await pumpSupplierApp(
        tester,
        FakeSupplierRepository(_seed()),
        size: Size(width, 2400),
      );
      await _tapFilter(tester, 'All');

      expect(tester.takeException(), isNull);
      expect(find.byType(SupplierCard), findsNWidgets(3));
    });
  }

  testWidgets('desktop shows two cards per row', (tester) async {
    await pumpSupplierApp(
      tester,
      FakeSupplierRepository(_seed()),
      size: const Size(1280, 2400),
    );

    final kofi = tester.getTopLeft(find.text('Kofi Bentley'));
    final tuth = tester.getTopLeft(find.text('Tuth'));
    expect(kofi.dy, tuth.dy);
    expect(tuth.dx, greaterThan(kofi.dx));
  });

  testWidgets('More screen opens Suppliers', (tester) async {
    await pumpSupplierApp(
      tester,
      FakeSupplierRepository(_seed()),
      location: '/more',
    );

    final entry = find.text('Suppliers');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(SuppliersScreen), findsOneWidget);
    expect(find.text('Kofi Bentley'), findsOneWidget);
  });
}
