import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/more/presentation/screens/more_screen.dart';
import 'package:shopmate/features/reports/domain/entities/business_performance.dart';
import 'package:shopmate/features/reports/domain/entities/inventory_report.dart';
import 'package:shopmate/features/reports/domain/entities/report_date_range.dart';
import 'package:shopmate/features/reports/domain/repositories/report_repository.dart';
import 'package:shopmate/features/reports/presentation/providers/reports_provider.dart';
import 'package:shopmate/features/reports/presentation/screens/inventory_report_screen.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

const _populated = InventoryReport(
  totalProducts: 1250,
  totalUnits: 18450,
  inventoryCostValue: 123456.78,
  potentialSellingValue: 150000.5,
  // Deliberately not selling minus cost: the screen must show this value.
  expectedGrossProfit: 26543.21,
  lowStockCount: 3,
  outOfStockCount: 2,
  unitsPurchased: 42000,
  unitsSold: 23550,
);

const _empty = InventoryReport(
  totalProducts: 0,
  totalUnits: 0,
  inventoryCostValue: 0,
  potentialSellingValue: 0,
  expectedGrossProfit: 0,
  lowStockCount: 0,
  outOfStockCount: 0,
  unitsPurchased: 0,
  unitsSold: 0,
);

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this._responses);

  /// One entry per call: an [InventoryReport], an error, or a pending future.
  final List<Object> _responses;
  int calls = 0;

  @override
  Future<InventoryReport> getInventoryReport() {
    final response =
        _responses[calls < _responses.length ? calls : _responses.length - 1];
    calls++;
    if (response is InventoryReport) return Future.value(response);
    if (response is Future<InventoryReport>) return response;
    return Future.error(response);
  }

  @override
  Future<BusinessPerformance> getBusinessPerformance(ReportDateRange range) =>
      throw UnimplementedError();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeReportRepository repository, {
  Size size = const Size(1200, 2000),
  bool automaticRetry = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // Riverpod retries failed providers by default; turning that off lets
      // a test hold the error state until the Retry button is pressed.
      retry: automaticRetry ? null : (_, _) => null,
      overrides: [reportRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: InventoryReportScreen()),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows a spinner, not zeros, while loading', (tester) async {
    final pending = Completer<InventoryReport>();
    await _pumpScreen(tester, _FakeReportRepository([pending.future]));
    await tester.pump();

    expect(find.text('Inventory Report'), findsOneWidget);
    expect(
      find.text('Current stock position and inventory value'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Loading inventory report'), findsOneWidget);
    expect(find.text('GHS 0.00'), findsNothing);

    pending.complete(_populated);
    await tester.pumpAndSettle();
  });

  testWidgets('shows every metric from the report', (tester) async {
    final repository = _FakeReportRepository([_populated]);
    await _pumpScreen(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.text('GHS 123,456.78'), findsOneWidget);
    expect(find.text('GHS 150,000.50'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('18,450'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('42,000'), findsOneWidget);
    expect(find.text('23,550'), findsOneWidget);
    expect(find.text('Profit'), findsOneWidget);
  });

  testWidgets('shows expected gross profit from the entity, not recalculated', (
    tester,
  ) async {
    await _pumpScreen(tester, _FakeReportRepository([_populated]));
    await tester.pumpAndSettle();

    // Selling minus cost would be GHS 26,543.72.
    expect(find.text('GHS 26,543.21'), findsOneWidget);
    expect(find.text('GHS 26,543.72'), findsNothing);
  });

  testWidgets('labels a negative expected gross profit as a loss', (
    tester,
  ) async {
    const loss = InventoryReport(
      totalProducts: 1,
      totalUnits: 5,
      inventoryCostValue: 50,
      potentialSellingValue: 40,
      expectedGrossProfit: -10,
      lowStockCount: 1,
      outOfStockCount: 0,
      unitsPurchased: 5,
      unitsSold: 0,
    );
    await _pumpScreen(tester, _FakeReportRepository([loss]));
    await tester.pumpAndSettle();

    expect(find.text('GHS -10.00'), findsOneWidget);
    expect(find.text('Loss'), findsOneWidget);
  });

  testWidgets('shows an empty state for a shop with no inventory', (
    tester,
  ) async {
    await _pumpScreen(tester, _FakeReportRepository([_empty]));
    await tester.pumpAndSettle();

    expect(find.text('No inventory yet'), findsOneWidget);
    expect(find.text('Inventory Cost Value'), findsNothing);
  });

  testWidgets('shows zero figures when products exist but have no stock', (
    tester,
  ) async {
    const zeroStock = InventoryReport(
      totalProducts: 2,
      totalUnits: 0,
      inventoryCostValue: 0,
      potentialSellingValue: 0,
      expectedGrossProfit: 0,
      lowStockCount: 0,
      outOfStockCount: 2,
      unitsPurchased: 0,
      unitsSold: 0,
    );
    await _pumpScreen(tester, _FakeReportRepository([zeroStock]));
    await tester.pumpAndSettle();

    expect(find.text('No inventory yet'), findsNothing);
    expect(find.text('GHS 0.00'), findsNWidgets(3));
    expect(find.text('Break-even'), findsOneWidget);
  });

  testWidgets('shows an error with Retry that reloads the report', (
    tester,
  ) async {
    final repository = _FakeReportRepository([
      Exception('offline'),
      _populated,
    ]);
    await _pumpScreen(tester, repository, automaticRetry: false);
    await tester.pumpAndSettle();

    expect(find.text('Unable to load inventory report'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Unable to load inventory report'), findsNothing);
    expect(find.text('GHS 123,456.78'), findsOneWidget);
  });

  testWidgets('refresh action fetches the report again', (tester) async {
    final repository = _FakeReportRepository([_empty, _populated]);
    await _pumpScreen(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('No inventory yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('GHS 123,456.78'), findsOneWidget);
  });

  for (final width in <double>[320, 360, 600, 1024]) {
    testWidgets('lays out without overflow at ${width.toInt()}px wide', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        _FakeReportRepository([_populated]),
        size: Size(width, 3000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Units Sold'), findsOneWidget);
    });
  }

  testWidgets('phone layout stacks the valuation cards in one column', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeReportRepository([_populated]),
      size: const Size(360, 3000),
    );
    await tester.pumpAndSettle();

    final costLeft = tester.getTopLeft(find.text('Inventory Cost Value')).dx;
    final sellingLeft = tester
        .getTopLeft(find.text('Potential Selling Value'))
        .dx;
    final costTop = tester.getTopLeft(find.text('Inventory Cost Value')).dy;
    final sellingTop = tester
        .getTopLeft(find.text('Potential Selling Value'))
        .dy;

    expect(sellingLeft, costLeft);
    expect(sellingTop, greaterThan(costTop));
  });

  testWidgets('More screen opens the inventory report', (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/more',
      routes: [
        GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
        GoRoute(
          path: '/reports/inventory',
          builder: (context, state) => const InventoryReportScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportRepositoryProvider.overrideWithValue(
            _FakeReportRepository([_populated]),
          ),
          // Reports are owner-only; More only lists them for the owner.
          shopAccessProvider.overrideWith(
            (ref) async => const ShopAccess(
              userId: 'user-1',
              status: ShopAccessStatus.active,
              shopId: 'shop-1',
              role: 'owner',
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.text('Inventory Report');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(InventoryReportScreen), findsOneWidget);
    expect(find.text('GHS 123,456.78'), findsOneWidget);
  });
}
