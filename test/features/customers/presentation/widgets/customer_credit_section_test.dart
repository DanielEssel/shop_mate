import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/customers/data/models/customer_credit_statement_model.dart';
import 'package:shopmate/features/customers/domain/entities/customer_credit_statement.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/customers/presentation/widgets/customer_credit_section.dart';
import 'package:shopmate/features/customers/presentation/widgets/record_customer_payment_sheet.dart';

const _customerId = 'customer-1';

CustomerCreditStatement _statementWithOutstandingBalance() {
  return CustomerCreditStatementModel.fromRows(
    creditSales: [
      {
        'id': 'sale-1',
        'sale_number': 'SALE-0001',
        'total_amount': 150,
        'created_at': '2026-10-05T09:00:00Z',
        'customer_payment_allocations': [
          {'amount': 50},
        ],
      },
      {
        'id': 'sale-2',
        'sale_number': 'SALE-0002',
        'total_amount': 80.5,
        'created_at': '2026-10-05T10:00:00Z',
        'customer_payment_allocations': <Map<String, Object?>>[],
      },
    ],
    payments: const [],
  );
}

Future<void> _pumpNarrowSection(
  WidgetTester tester,
  CustomerCreditStatement statement,
) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerCreditStatementProvider(
          _customerId,
        ).overrideWith((ref) async => statement),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: CustomerCreditSection(
              customerId: _customerId,
              customerName: 'Test Customer',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('statement outstanding balance follows the payment ledger', () {
    final statement = _statementWithOutstandingBalance();

    expect(statement.totalCreditSales, 230.5);
    expect(statement.totalPaid, 50);
    expect(statement.outstandingBalance, 180.5);
    expect(statement.outstandingSaleCount, 2);
  });

  testWidgets(
    'narrow screen shows outstanding balance and usable Record Payment',
    (tester) async {
      await _pumpNarrowSection(tester, _statementWithOutstandingBalance());

      expect(find.text('GHS 180.50'), findsOneWidget);
      expect(find.text('GHS 230.50'), findsOneWidget);

      final button = find.widgetWithText(FilledButton, 'Record Payment');
      await tester.ensureVisible(button);
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(RecordCustomerPaymentSheet), findsOneWidget);
    },
  );

  testWidgets('Record Payment is disabled without outstanding credit', (
    tester,
  ) async {
    await _pumpNarrowSection(
      tester,
      CustomerCreditStatementModel.fromRows(creditSales: [], payments: []),
    );

    final button = find.widgetWithText(FilledButton, 'Record Payment');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });
}
