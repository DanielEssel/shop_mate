import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/reports/domain/entities/business_performance.dart';
import 'package:shopmate/features/reports/domain/entities/report_date_range.dart';
import 'package:shopmate/features/reports/presentation/providers/report_period_provider.dart';
import 'package:shopmate/features/reports/presentation/providers/reports_provider.dart';
import 'package:shopmate/features/reports/presentation/screens/business_performance_screen.dart';

final _today = DateTime(2026, 10, 9);

BusinessPerformance _performance(
  ReportDateRange range, {
  double totalSales = 1234567.89,
  double totalCogs = 800000.5,
  double grossProfit = 434567.39,
  double totalExpenses = 120000,
  double netProfit = 314567.39,
  double profitMargin = 25.48,
  int salesCount = 42,
  int expenseCount = 7,
}) {
  return BusinessPerformance(
    range: range,
    totalSales: totalSales,
    totalCogs: totalCogs,
    grossProfit: grossProfit,
    totalExpenses: totalExpenses,
    netProfit: netProfit,
    profitMargin: profitMargin,
    salesCount: salesCount,
    expenseCount: expenseCount,
  );
}

/// Loads the report for whatever range the screen asks for, recording it.
class _Loader {
  _Loader(this.respond);

  final Future<BusinessPerformance> Function(ReportDateRange range) respond;
  final requested = <ReportDateRange>[];

  Future<BusinessPerformance> call(ReportDateRange range) {
    requested.add(range);
    return respond(range);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Loader loader, {
  Size size = const Size(1200, 2000),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  ReportPeriodNotifier.now = () => _today;
  addTearDown(() => ReportPeriodNotifier.now = DateTime.now);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        businessPerformanceProvider.overrideWith(
          (ref, range) => loader(range),
        ),
      ],
      child: const MaterialApp(home: BusinessPerformanceScreen()),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows every figure from the report, not recalculated', (
    tester,
  ) async {
    await _pump(tester, _Loader((range) async => _performance(range)));

    expect(find.text('Business Performance'), findsOneWidget);
    // Net profit appears in the key figures and the statement.
    expect(find.text('GHS 314,567.39'), findsNWidgets(2));
    expect(find.text('25.48%'), findsOneWidget);
    expect(find.text('GHS 1,234,567.89'), findsNWidgets(2));
    expect(find.text('GHS 800,000.50'), findsOneWidget);
    expect(find.text('GHS 434,567.39'), findsOneWidget);
    expect(find.text('GHS 120,000.00'), findsOneWidget);
    expect(find.text('42 sales'), findsNWidgets(2));
    expect(find.text('7 expenses'), findsOneWidget);
    expect(find.text('Profit'), findsWidgets);
    expect(find.text('Profit & Loss'), findsOneWidget);
  });

  testWidgets('a loss is labelled as a loss', (tester) async {
    await _pump(
      tester,
      _Loader(
        (range) async => _performance(
          range,
          grossProfit: -50,
          netProfit: -250.75,
          profitMargin: -12.5,
        ),
      ),
    );

    expect(find.text('GHS -250.75'), findsNWidgets(2));
    expect(find.text('Loss'), findsWidgets);
    expect(find.text('-12.50%'), findsOneWidget);
  });

  testWidgets('large counts use thousands separators', (tester) async {
    await _pump(
      tester,
      _Loader(
        (range) async =>
            _performance(range, salesCount: 1284, expenseCount: 1001),
      ),
    );

    expect(find.text('1,284 sales'), findsNWidgets(2));
    expect(find.text('1,001 expenses'), findsOneWidget);
  });

  testWidgets('starts on today and each preset requests its range', (
    tester,
  ) async {
    final loader = _Loader((range) async => _performance(range));
    await _pump(tester, loader);

    expect(loader.requested.last, ReportDateRange.day(_today));

    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    expect(
      loader.requested.last,
      ReportDateRange(start: DateTime(2026, 10, 3), end: _today),
    );

    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();
    expect(
      loader.requested.last,
      ReportDateRange(start: DateTime(2026, 9, 10), end: _today),
    );
  });

  testWidgets('refresh reloads the current period', (tester) async {
    final loader = _Loader((range) async => _performance(range));
    await _pump(tester, loader);
    final before = loader.requested.length;

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(loader.requested.length, greaterThan(before));
  });

  testWidgets('shows a placeholder, not zeros, while loading', (
    tester,
  ) async {
    final pending = Completer<BusinessPerformance>();
    await _pump(tester, _Loader((_) => pending.future), settle: false);
    await tester.pump();

    expect(
      find.bySemanticsLabel('Loading business performance'),
      findsOneWidget,
    );
    expect(find.text('GHS 0.00'), findsNothing);

    pending.complete(_performance(ReportDateRange.day(_today)));
    await tester.pumpAndSettle();
    expect(find.text('Profit & Loss'), findsOneWidget);
  });

  testWidgets('an error offers Retry that reloads', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      _Loader((range) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return _performance(range);
      }),
    );

    expect(find.text('Unable to load business performance'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Profit & Loss'), findsOneWidget);
  });

  testWidgets('a period without sales or expenses says so', (tester) async {
    await _pump(
      tester,
      _Loader(
        (range) async => _performance(
          range,
          totalSales: 0,
          totalCogs: 0,
          grossProfit: 0,
          totalExpenses: 0,
          netProfit: 0,
          profitMargin: 0,
          salesCount: 0,
          expenseCount: 0,
        ),
      ),
    );

    expect(find.text('No activity in this period'), findsOneWidget);
    expect(find.text('Profit & Loss'), findsNothing);
  });

  for (final (label, size) in [
    ('320px', const Size(320, 2400)),
    ('tablet', const Size(820, 2400)),
    ('desktop', const Size(1440, 2000)),
  ]) {
    testWidgets('large figures fit without overflow at $label', (
      tester,
    ) async {
      await _pump(
        tester,
        _Loader(
          (range) async => _performance(
            range,
            totalSales: 98765432.1,
            netProfit: -12345678.9,
          ),
        ),
        size: size,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
    });
  }
}
