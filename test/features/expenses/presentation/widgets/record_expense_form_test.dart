import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/expenses/domain/entities/expense_category.dart';
import 'package:shopmate/features/expenses/domain/entities/expense_payment_method.dart';
import 'package:shopmate/features/expenses/domain/entities/record_expense_request.dart';
import 'package:shopmate/features/expenses/domain/usecases/record_expense.dart';
import 'package:shopmate/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:shopmate/features/expenses/presentation/widgets/record_expense_form.dart';

class _FakeRecordExpense implements RecordExpense {
  final requests = <RecordExpenseRequest>[];

  @override
  Future<String> call(RecordExpenseRequest request) async {
    requests.add(request);
    return 'expense-1';
  }
}

/// Opens the form the way the Expenses screen does; returns the recorder
/// and a holder for the form's result.
Future<(_FakeRecordExpense, List<bool>)> _open(
  WidgetTester tester, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final recorder = _FakeRecordExpense();
  final results = <bool>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [recordExpenseProvider.overrideWithValue(recorder)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async =>
                    results.add(await showRecordExpenseForm(context)),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
  return (recorder, results);
}

Future<void> _choose(WidgetTester tester, Type type, String option) async {
  await tester.tap(find.byWidgetPredicate((w) => w.runtimeType == type));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

FilledButton _submit(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.text('Record Expense').last,
    matching: find.byType(FilledButton),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('guides the user field by field and only then allows saving', (
    tester,
  ) async {
    final (recorder, results) = await _open(tester);

    expect(find.text('Select a category.'), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);

    await _choose(
      tester,
      DropdownButtonFormField<ExpenseCategory>,
      ExpenseCategory.rent.label,
    );
    expect(find.text('Enter an expense amount.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12.345');
    await tester.pump();
    // The inline error and the footer message both explain the problem.
    expect(find.text('Use no more than two decimal places.'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '1,500.50',
    );
    await tester.pump();
    expect(find.text('Select a payment method.'), findsOneWidget);

    await _choose(
      tester,
      DropdownButtonFormField<ExpensePaymentMethod>,
      ExpensePaymentMethod.cash.label,
    );
    expect(_submit(tester).onPressed, isNotNull);

    await tester.tap(find.text('Record Expense').last);
    await tester.pumpAndSettle();

    final request = recorder.requests.single;
    expect(request.category, ExpenseCategory.rent);
    expect(request.amount, 1500.5);
    expect(request.paymentMethod, ExpensePaymentMethod.cash);
    expect(results, [true]);
  });

  testWidgets('Close leaves without recording', (tester) async {
    final (recorder, results) = await _open(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(recorder.requests, isEmpty);
    expect(results, [false]);
  });

  for (final (label, size) in [
    ('320px', const Size(320, 760)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('lays out without overflow at $label', (tester) async {
      await _open(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(find.text('Record Expense').last.hitTestable(), findsOneWidget);
      // Amount and payment method sit side by side when there is room.
      final amount = tester.getRect(find.widgetWithText(TextField, 'Amount'));
      final method = tester.getRect(
        find.byWidgetPredicate(
          (w) => w.runtimeType == DropdownButtonFormField<ExpensePaymentMethod>,
        ),
      );
      expect(
        amount.top == method.top,
        size.width >= 900,
        reason: 'paired on the desktop dialog only',
      );
    });
  }
}
