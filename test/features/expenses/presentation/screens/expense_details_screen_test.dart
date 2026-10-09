import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/ui/ui.dart';
import 'package:shopmate/features/expenses/domain/entities/expense.dart';
import 'package:shopmate/features/expenses/domain/entities/expense_category.dart';
import 'package:shopmate/features/expenses/domain/entities/expense_payment_method.dart';
import 'package:shopmate/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:shopmate/features/expenses/presentation/screens/expense_details_screen.dart';

Expense _expense({String? reference = 'RCPT-2026-00451', String? note}) {
  return Expense(
    id: 'e1',
    category: ExpenseCategory.utilities,
    amount: 1250.75,
    paymentMethod: ExpensePaymentMethod.mobileMoney,
    expenseDate: DateTime(2026, 10, 3),
    reference: reference,
    note: note,
    createdAt: DateTime(2026, 10, 3, 9, 30),
    updatedAt: DateTime(2026, 10, 3, 9, 30),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<Expense> Function() expense,
  Size size = const Size(390, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [expenseProvider.overrideWith((ref, id) => expense())],
      child: const MaterialApp(home: ExpenseDetailsScreen(expenseId: 'e1')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows the expense with amount, method and record', (
    tester,
  ) async {
    await _pump(
      tester,
      expense: () async => _expense(note: 'October electricity bill'),
    );

    expect(find.text('Expense Details'), findsOneWidget);
    expect(find.text('Utilities'), findsWidgets);
    expect(find.text('GHS 1,250.75'), findsWidgets);
    expect(find.text('Mobile Money'), findsWidgets);
    expect(find.text('RCPT-2026-00451'), findsOneWidget);
    expect(find.text('October electricity bill'), findsOneWidget);
    expect(find.text('Recorded'), findsOneWidget);
    // Read-only: nothing to edit or delete.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('missing reference and note show "Not provided"', (tester) async {
    await _pump(tester, expense: () async => _expense(reference: null));

    expect(find.text('Not provided'), findsNWidgets(2));
  });

  testWidgets('loading shows a placeholder', (tester) async {
    final pending = Completer<Expense>();
    await _pump(tester, expense: () => pending.future);

    expect(find.byType(SkeletonBox), findsWidgets);
    pending.complete(_expense());
    await tester.pumpAndSettle();
    expect(find.text('Expense Information'), findsOneWidget);
  });

  testWidgets('an error offers Retry', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      expense: () async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return _expense();
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load this expense'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Expense Information'), findsOneWidget);
  });

  for (final (label, size) in [
    ('320px', const Size(320, 2400)),
    ('tablet', const Size(820, 2400)),
    ('desktop', const Size(1440, 2400)),
  ]) {
    testWidgets('lays out without overflow at $label', (tester) async {
      await _pump(
        tester,
        expense: () async => _expense(
          note: 'A long note about a generator repair at the Kaneshie shop.',
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
