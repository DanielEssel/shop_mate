import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/domain/entities/customer_credit_statement.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../shop/shop_role_fixtures.dart';

const _ama = Customer(
  id: 'c1',
  name: 'Ama Mensah',
  phone: '0241234567',
  email: 'ama@example.com',
);

class _Customers extends CustomersNotifier {
  final updates = <Customer>[];

  @override
  Future<List<Customer>> build() async => const [_ama];

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    updates.add(customer);
    return customer;
  }
}

Future<_Customers> _pump(
  WidgetTester tester, {
  String role = ownerRole,
  Size size = const Size(420, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final customers = _Customers();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith((ref) async => activeAccess(role)),
        customersProvider.overrideWith(() => customers),
        customerProvider.overrideWith((ref, id) async => _ama),
        customerCreditStatementProvider.overrideWith(
          (ref, id) async => const CustomerCreditStatement(
            totalCreditSales: 0,
            totalPaid: 0,
            outstandingBalance: 0,
            outstandingSaleCount: 0,
            outstandingSales: [],
            paymentHistory: [],
          ),
        ),
      ],
      child: const MaterialApp(home: CustomerDetailsScreen(customerId: 'c1')),
    ),
  );
  await tester.pumpAndSettle();
  return customers;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _startEditing(WidgetTester tester) async {
  await tester.tap(find.text('Edit Customer'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows the customer with contact details and status', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Customer Details'), findsOneWidget);
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('ama@example.com'), findsOneWidget);
    // Address and notes are not set.
    expect(find.text('Not provided'), findsNWidgets(2));
    expect(find.text('Credit Account'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('editing shows the form and a Save bar; Cancel restores', (
    tester,
  ) async {
    final customers = await _pump(tester);
    await _startEditing(tester);

    expect(find.text('Edit Customer'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Credit Account'), findsNothing);

    await tester.enterText(_field('Customer Name *'), 'Changed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(customers.updates, isEmpty);
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('an empty name or a bad email is refused', (tester) async {
    final customers = await _pump(tester);
    await _startEditing(tester);

    await tester.enterText(_field('Customer Name *'), ' ');
    await tester.enterText(_field('Email Address'), 'not-an-email');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Customer name is required'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(customers.updates, isEmpty);
    // The Save bar stays reachable under the errors.
    expect(find.text('Save Changes').hitTestable(), findsOneWidget);
  });

  testWidgets('a valid edit saves trimmed values and returns to the view', (
    tester,
  ) async {
    final customers = await _pump(tester);
    await _startEditing(tester);

    await tester.enterText(_field('Customer Name *'), '  Ama Owusu ');
    await tester.enterText(_field('Address'), ' Adum, Kumasi ');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = customers.updates.single;
    expect(saved.id, 'c1');
    expect(saved.name, 'Ama Owusu');
    expect(saved.address, 'Adum, Kumasi');
    expect(saved.phone, '0241234567');
    expect(find.text('Save Changes'), findsNothing);
  });

  for (final role in [ownerRole, attendantRole]) {
    for (final (label, size) in [
      ('320px', const Size(320, 2400)),
      ('tablet', const Size(820, 2400)),
      ('desktop', const Size(1440, 2400)),
    ]) {
      testWidgets('$role lays out without overflow at $label', (tester) async {
        await _pump(tester, role: role, size: size);
        expect(tester.takeException(), isNull);
        expect(
          find.text('Deactivate Customer'),
          role == ownerRole ? findsOneWidget : findsNothing,
        );

        await _startEditing(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Save Changes').hitTestable(), findsOneWidget);
      });
    }
  }
}
