import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:shopmate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopmate/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../../../app/app_test_harness.dart';
import '../../../shop/shop_role_fixtures.dart';

/// What the database returns: owners get today's profit; for attendants the
/// key is missing and the model falls back to 0.
DashboardSummary _summary({required double profit}) => DashboardSummary(
  todaySales: 250,
  todayProfit: profit,
  todayTransactions: 4,
  totalProducts: 12,
  lowStockProducts: 0,
  outOfStockProducts: 0,
  recentSales: const [],
);

Future<void> _pump(WidgetTester tester, String role, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopAccessProvider.overrideWith((ref) async => activeAccess(role)),
        shopBrandingProvider.overrideWith(NoBranding.new),
        dashboardSummaryProvider.overrideWith(
          (ref) async => _summary(profit: role == ownerRole ? 80 : 0),
        ),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in [const Size(420, 2400), const Size(1400, 1600)]) {
    final label = size.width < 600 ? 'phone' : 'desktop';

    testWidgets('owner sees profit and stock adjustment ($label)', (
      tester,
    ) async {
      await _pump(tester, ownerRole, size);

      expect(find.text("Today's Profit"), findsOneWidget);
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('Adjust Stock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('attendant sees no profit and no stock adjustment ($label)', (
      tester,
    ) async {
      await _pump(tester, attendantRole, size);

      expect(find.text("Today's Profit"), findsNothing);
      expect(find.text('Estimated profit today'), findsNothing);
      // Operational figures and actions stay.
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Products'), findsWidgets);
      expect(find.text('New Sale'), findsOneWidget);
      expect(find.text('New Purchase'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Adjust Stock'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
