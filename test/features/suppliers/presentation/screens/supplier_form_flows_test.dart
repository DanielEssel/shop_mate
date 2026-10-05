import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/suppliers/presentation/screens/add_supplier_screen.dart';
import 'package:shopmate/features/suppliers/presentation/screens/edit_supplier_screen.dart';
import 'package:shopmate/features/suppliers/presentation/screens/supplier_details_screen.dart';
import 'package:shopmate/features/suppliers/presentation/screens/suppliers_screen.dart';

import '../supplier_test_harness.dart';

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(_field(label), text);
  await tester.pump();
}

String _fieldText(WidgetTester tester, String label) {
  return tester.widget<TextFormField>(_field(label)).controller!.text;
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Opens the add form from the list, so a successful save returns there.
Future<FakeSupplierRepository> _openAddFromList(WidgetTester tester) async {
  final repository = FakeSupplierRepository([
    supplier(id: 's-tuth', name: 'Tuth'),
  ]);
  await pumpSupplierApp(tester, repository);
  await tester.tap(find.widgetWithText(FilledButton, 'Add supplier'));
  await tester.pumpAndSettle();
  expect(find.byType(AddSupplierScreen), findsOneWidget);
  return repository;
}

void main() {
  setUpAll(disableFontFetching);

  group('add supplier', () {
    testWidgets('name is required', (tester) async {
      final repository = await _openAddFromList(tester);

      await _tapButton(tester, 'Save supplier');

      expect(find.text('Supplier name is required'), findsOneWidget);
      expect(repository.createdCalls, isEmpty);
    });

    testWidgets('whitespace-only name is rejected', (tester) async {
      final repository = await _openAddFromList(tester);

      await _enter(tester, 'Supplier name *', '    ');
      await _tapButton(tester, 'Save supplier');

      expect(find.text('Supplier name is required'), findsOneWidget);
      expect(repository.createdCalls, isEmpty);
    });

    testWidgets('enforces the database length limits', (tester) async {
      final repository = await _openAddFromList(tester);

      await _enter(tester, 'Supplier name *', 'n' * 121);
      await _enter(tester, 'Phone', '1' * 41);
      await _enter(tester, 'Email', '${'e' * 250}@x.co');
      await _enter(tester, 'Address', 'a' * 251);
      await _enter(tester, 'Notes', 'x' * 1001);
      await _tapButton(tester, 'Save supplier');

      expect(find.text('Must be 120 characters or fewer'), findsOneWidget);
      expect(find.text('Must be 40 characters or fewer'), findsOneWidget);
      expect(find.text('Must be 254 characters or fewer'), findsOneWidget);
      expect(find.text('Must be 250 characters or fewer'), findsOneWidget);
      expect(find.text('Must be 1000 characters or fewer'), findsOneWidget);
      expect(repository.createdCalls, isEmpty);
    });

    testWidgets('accepts values at the limits', (tester) async {
      final repository = await _openAddFromList(tester);

      await _enter(tester, 'Supplier name *', 'n' * 120);
      await _enter(tester, 'Phone', '1' * 40);
      await _tapButton(tester, 'Save supplier');

      expect(repository.createdCalls, hasLength(1));
    });

    testWidgets('rejects a malformed email', (tester) async {
      final repository = await _openAddFromList(tester);

      await _enter(tester, 'Supplier name *', 'Kofi');
      await _enter(tester, 'Email', 'not-an-email');
      await _tapButton(tester, 'Save supplier');

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.createdCalls, isEmpty);
    });

    testWidgets(
      'saves trimmed values, blank optionals as null, and refreshes the list',
      (tester) async {
        final repository = await _openAddFromList(tester);

        await _enter(tester, 'Supplier name *', '  Kofi  Bentley Ltd ');
        await _enter(tester, 'Phone', '   ');
        await _enter(tester, 'Email', ' Kofi@Bentley.Example ');
        await _enter(tester, 'Address', '');
        await _enter(tester, 'Notes', ' Delivers Mondays ');
        await _tapButton(tester, 'Save supplier');

        expect(repository.createdCalls.single, {
          'name': 'Kofi  Bentley Ltd',
          'phone': null,
          'email': 'Kofi@Bentley.Example',
          'address': null,
          'notes': 'Delivers Mondays',
        });
        expect(find.text('Supplier Kofi  Bentley Ltd added.'), findsOneWidget);
        expect(find.byType(SuppliersScreen), findsOneWidget);
        expect(find.text('Kofi  Bentley Ltd'), findsOneWidget);
        expect(find.text('2 suppliers'), findsOneWidget);
      },
    );

    testWidgets('a failed save keeps the input and re-enables the form', (
      tester,
    ) async {
      final repository = await _openAddFromList(tester);
      repository.writeError = Exception('network down');

      await _enter(tester, 'Supplier name *', 'Kofi Bentley');
      await _enter(tester, 'Phone', '0240000001');
      await _tapButton(tester, 'Save supplier');

      expect(find.byType(AddSupplierScreen), findsOneWidget);
      expect(
        find.text(
          'Unable to save supplier. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'Supplier name *'), 'Kofi Bentley');
      expect(_fieldText(tester, 'Phone'), '0240000001');
      final button = find.widgetWithText(FilledButton, 'Save supplier');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('a duplicate active name shows a clear message', (
      tester,
    ) async {
      final repository = await _openAddFromList(tester);
      repository.writeError = duplicateNameError();

      await _enter(tester, 'Supplier name *', 'tuth');
      await _tapButton(tester, 'Save supplier');

      expect(
        find.text('A supplier with this name already exists.'),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'Supplier name *'), 'tuth');
    });
  });

  group('supplier details', () {
    testWidgets('shows the supplier with readable dates', (tester) async {
      await pumpSupplierApp(
        tester,
        FakeSupplierRepository([
          supplier(
            id: 's-kofi',
            name: 'Kofi Bentley',
            phone: '0240000001',
            email: 'kofi@bentley.example',
            address: 'Kumasi',
            notes: 'Delivers Mondays',
          ),
        ]),
        location: '/suppliers/s-kofi',
      );

      expect(find.text('Kofi Bentley'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('0240000001'), findsOneWidget);
      expect(find.text('kofi@bentley.example'), findsOneWidget);
      expect(find.text('Kumasi'), findsOneWidget);
      expect(find.text('Delivers Mondays'), findsOneWidget);
      expect(find.textContaining('October 1, 2026'), findsOneWidget);
      expect(find.textContaining('October 2, 2026'), findsOneWidget);
      expect(find.textContaining('2026-10'), findsNothing);
    });

    testWidgets('missing optional fields show "Not provided"', (tester) async {
      await pumpSupplierApp(
        tester,
        FakeSupplierRepository([
          supplier(id: 's-tuth', name: 'Tuth', isActive: false),
        ]),
        location: '/suppliers/s-tuth',
      );

      expect(find.text('Not provided'), findsNWidgets(4));
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.textContaining('reactivate'), findsOneWidget);
    });

    testWidgets('Edit supplier opens the edit screen', (tester) async {
      await pumpSupplierApp(
        tester,
        FakeSupplierRepository([supplier(id: 's-tuth', name: 'Tuth')]),
        location: '/suppliers/s-tuth',
      );

      await _tapButton(tester, 'Edit supplier');

      expect(find.byType(EditSupplierScreen), findsOneWidget);
      expect(find.text('Edit Supplier'), findsOneWidget);
    });
  });

  group('edit supplier', () {
    Future<FakeSupplierRepository> openEdit(
      WidgetTester tester, {
      bool isActive = true,
    }) async {
      final repository = FakeSupplierRepository([
        supplier(
          id: 's-kofi',
          name: 'Kofi Bentley',
          isActive: isActive,
          phone: '0240000001',
          email: 'kofi@bentley.example',
          notes: 'Delivers Mondays',
        ),
        supplier(id: 's-tuth', name: 'Tuth'),
      ]);
      // List -> details -> edit, so refreshes can be checked on the way back.
      await pumpSupplierApp(tester, repository);
      if (!isActive) {
        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Kofi Bentley'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Edit supplier');
      return repository;
    }

    testWidgets('prepopulates the existing values', (tester) async {
      await openEdit(tester);

      expect(_fieldText(tester, 'Supplier name *'), 'Kofi Bentley');
      expect(_fieldText(tester, 'Phone'), '0240000001');
      expect(_fieldText(tester, 'Email'), 'kofi@bentley.example');
      expect(_fieldText(tester, 'Address'), '');
      expect(_fieldText(tester, 'Notes'), 'Delivers Mondays');
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('update refreshes the details and the list', (tester) async {
      final repository = await openEdit(tester);

      await _enter(tester, 'Supplier name *', ' Kofi Bentley Ltd ');
      await _enter(tester, 'Phone', '');
      await _tapButton(tester, 'Save changes');

      expect(repository.updateCalls.single, {
        'id': 's-kofi',
        'name': 'Kofi Bentley Ltd',
        'isActive': true,
        'phone': null,
        'email': 'kofi@bentley.example',
        'address': null,
        'notes': 'Delivers Mondays',
      });
      expect(find.byType(SupplierDetailsScreen), findsOneWidget);
      expect(find.text('Kofi Bentley Ltd'), findsOneWidget);
      expect(find.text('Supplier Kofi Bentley Ltd updated.'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(SuppliersScreen), findsOneWidget);
      expect(find.text('Kofi Bentley Ltd'), findsOneWidget);
      expect(find.text('Kofi Bentley'), findsNothing);
    });

    testWidgets('deactivating uses the update flow and leaves the list', (
      tester,
    ) async {
      final repository = await openEdit(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await _tapButton(tester, 'Save changes');

      expect(repository.updateCalls.single['isActive'], isFalse);
      expect(find.text('Inactive'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Kofi Bentley'), findsNothing);
      expect(find.text('1 supplier'), findsOneWidget);
    });

    testWidgets('an inactive supplier can be reactivated', (tester) async {
      final repository = await openEdit(tester, isActive: false);

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await _tapButton(tester, 'Save changes');

      expect(repository.updateCalls.single['isActive'], isTrue);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('a failed update keeps the edits and the status', (
      tester,
    ) async {
      final repository = await openEdit(tester);
      repository.writeError = Exception('timeout');

      await _enter(tester, 'Notes', 'New notes');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await _tapButton(tester, 'Save changes');

      expect(find.byType(EditSupplierScreen), findsOneWidget);
      expect(_fieldText(tester, 'Notes'), 'New notes');
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        find.text(
          'Unable to save supplier. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reactivating into a duplicate name shows the message', (
      tester,
    ) async {
      final repository = await openEdit(tester, isActive: false);
      repository.writeError = duplicateNameError();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await _tapButton(tester, 'Save changes');

      expect(
        find.text('A supplier with this name already exists.'),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'Supplier name *'), 'Kofi Bentley');
      expect(find.byType(EditSupplierScreen), findsOneWidget);
    });

    testWidgets('a permission error is not reported as a duplicate', (
      tester,
    ) async {
      final repository = await openEdit(tester);
      repository.writeError = const PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );

      await _tapButton(tester, 'Save changes');

      expect(
        find.text('You do not have permission to change suppliers.'),
        findsOneWidget,
      );
      expect(
        find.text('A supplier with this name already exists.'),
        findsNothing,
      );
    });
  });
}
