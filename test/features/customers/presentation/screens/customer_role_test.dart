import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/domain/entities/customer_credit_statement.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:shopmate/features/customers/presentation/screens/customers_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../shop/shop_role_fixtures.dart';

const _ama = Customer(id: 'c1', name: 'Ama Mensah', phone: '0241234567');

class _FixedCustomers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => const [_ama];
}

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
        customersProvider.overrideWith(_FixedCustomers.new),
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
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCustomerMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Customer actions'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('customer list', () {
    for (final size in [const Size(1400, 2400), const Size(420, 2400)]) {
      final label = size.width < 600 ? 'phone' : 'desktop';

      testWidgets('owner can edit or deactivate ($label)', (tester) async {
        await _pump(tester, ownerRole, const CustomersScreen(), size: size);
        await _openCustomerMenu(tester);

        expect(find.text('Edit customer'), findsOneWidget);
        expect(find.text('Deactivate customer'), findsOneWidget);
      });

      testWidgets('attendant can edit but not deactivate ($label)', (
        tester,
      ) async {
        await _pump(tester, attendantRole, const CustomersScreen(), size: size);
        await _openCustomerMenu(tester);

        expect(find.text('Edit customer'), findsOneWidget);
        expect(find.text('Deactivate customer'), findsNothing);
      });
    }
  });

  group('customer details', () {
    testWidgets('owner sees Deactivate Customer', (tester) async {
      await _pump(
        tester,
        ownerRole,
        const CustomerDetailsScreen(customerId: 'c1'),
      );

      expect(find.text('Ama Mensah'), findsWidgets);
      expect(find.text('Deactivate Customer'), findsOneWidget);
    });

    testWidgets('attendant does not', (tester) async {
      await _pump(
        tester,
        attendantRole,
        const CustomerDetailsScreen(customerId: 'c1'),
      );

      expect(find.text('Ama Mensah'), findsWidgets);
      expect(find.text('Deactivate Customer'), findsNothing);
      expect(find.text('Customer Actions'), findsNothing);
    });
  });
}
