import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/core/widgets/navigation/app_bottom_navigation.dart';
import 'package:shopmate/core/widgets/navigation/app_navigation_rail.dart';
import 'package:shopmate/core/widgets/navigation/app_sidebar.dart';
import 'package:shopmate/core/widgets/navigation/navigation_parts.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

import '../../../app/app_test_harness.dart';
import '../../../features/auth/fake_auth_repository.dart';

Future<AppHarness> _pumpAt(
  WidgetTester tester,
  Size size, {
  String role = 'owner',
}) async {
  final h = await pumpApp(
    tester,
    user: userA,
    answers: {'user-a': ShopAccessStatus.active},
    roles: {'user-a': role},
  );
  tester.view.physicalSize = size;
  await _settle(tester);
  return h;
}

/// Lets redirects land and page transitions finish.
Future<void> _settle(WidgetTester tester) async {
  await settleApp(tester);
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _sidebarItem(String label) => find.descendant(
  of: find.byType(AppSidebar),
  matching: find.widgetWithText(NavItemTile, label),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('desktop', () {
    const desktop = Size(1280, 900);

    testWidgets('tabs use the persistent sidebar, not the bottom bar', (
      tester,
    ) async {
      final h = await _pumpAt(tester, desktop);

      expect(h.location, '/dashboard');
      expect(find.byType(AppSidebar), findsOne);
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final route in const [
      '/customers',
      '/purchases',
      '/suppliers',
      '/expenses',
      '/reports/business-performance',
      '/reports/inventory',
      '/settings',
      '/users',
    ]) {
      testWidgets('$route keeps the sidebar on screen', (tester) async {
        final h = await _pumpAt(tester, desktop);

        h.router.go(route);
        await _settle(tester);

        expect(h.location, route);
        expect(find.byType(AppSidebar), findsOne);
        expect(find.byType(AppBottomNavigation), findsNothing);
      });
    }

    testWidgets('the sidebar opens a secondary area and marks it active', (
      tester,
    ) async {
      final h = await _pumpAt(tester, desktop);

      await tester.tap(_sidebarItem('Customers'));
      await _settle(tester);

      expect(h.location, '/customers');
      expect(find.byType(AppSidebar), findsOne);
      expect(
        tester.widget<NavItemTile>(_sidebarItem('Customers')).selected,
        isTrue,
      );
      expect(
        tester.widget<NavItemTile>(_sidebarItem('Dashboard')).selected,
        isFalse,
      );

      // And back to a tab from there.
      await tester.tap(_sidebarItem('Products'));
      await _settle(tester);

      expect(h.location, '/products');
      expect(
        tester.widget<NavItemTile>(_sidebarItem('Products')).selected,
        isTrue,
      );
    });

    testWidgets('a nested route keeps its area active', (tester) async {
      final h = await _pumpAt(tester, desktop);

      h.router.go('/settings/categories');
      await _settle(tester);

      expect(h.location, '/settings/categories');
      expect(
        tester.widget<NavItemTile>(_sidebarItem('Settings')).selected,
        isTrue,
      );
    });

    testWidgets('coming-soon items explain themselves and stay put', (
      tester,
    ) async {
      final h = await _pumpAt(tester, desktop);

      await tester.tap(_sidebarItem('Notifications'));
      await tester.pump();

      expect(find.text('Notifications is coming soon.'), findsOne);
      expect(h.location, '/dashboard');
    });

    testWidgets('staff never see owner-only destinations', (tester) async {
      await _pumpAt(tester, desktop, role: 'staff');

      for (final item in const [
        'Expenses',
        'Reports',
        'Inventory Report',
        'Analytics',
        'Settings',
        'Users & Permissions',
      ]) {
        expect(_sidebarItem(item), findsNothing, reason: item);
      }
      for (final item in const [
        'Dashboard',
        'Products',
        'Inventory',
        'Sales',
        'Customers',
        'Purchases',
        'Suppliers',
        'Notifications',
        'Help & Support',
      ]) {
        expect(_sidebarItem(item), findsOne, reason: item);
      }
    });

    testWidgets('owners see owner destinations', (tester) async {
      await _pumpAt(tester, desktop);

      for (final item in const [
        'Expenses',
        'Reports',
        'Inventory Report',
        'Settings',
        'Users & Permissions',
      ]) {
        expect(_sidebarItem(item), findsOne, reason: item);
      }
      // Platform Admin is for confirmed platform admins only.
      expect(_sidebarItem('Platform Admin'), findsNothing);
    });
  });

  group('tablet', () {
    testWidgets('tabs and secondary areas use the icon rail', (tester) async {
      final h = await _pumpAt(tester, const Size(800, 1100));

      expect(find.byType(AppNavigationRail), findsOne);
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(AppBottomNavigation), findsNothing);

      h.router.go('/purchases');
      await _settle(tester);

      expect(h.location, '/purchases');
      expect(find.byType(AppNavigationRail), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('phone', () {
    testWidgets('tabs use the bottom bar; secondary areas are full screen', (
      tester,
    ) async {
      final h = await _pumpAt(tester, const Size(390, 844));

      expect(find.byType(AppBottomNavigation), findsOne);
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(AppNavigationRail), findsNothing);
      expect(find.byTooltip('Open menu'), findsOne);

      h.router.push('/customers');
      await _settle(tester);

      // A pushed page: read the router state (the harness location shows
      // the base route under it).
      expect(h.router.state.uri.path, '/customers');
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(AppNavigationRail), findsNothing);
      expect(find.byType(BackButton), findsOne);

      await tester.tap(find.byType(BackButton));
      await _settle(tester);

      expect(h.location, '/dashboard');
      expect(find.byType(AppBottomNavigation), findsOne);
    });

    testWidgets('the menu button opens the drawer from every tab', (
      tester,
    ) async {
      final h = await _pumpAt(tester, const Size(390, 844));

      for (final route in const [
        '/dashboard',
        '/products',
        '/inventory',
        '/sales',
        '/more',
      ]) {
        h.router.go(route);
        await _settle(tester);

        await tester.tap(find.byTooltip('Open menu').first);
        await _settle(tester);

        expect(find.byType(Drawer), findsOne, reason: route);
        Navigator.of(tester.element(find.byType(Drawer))).pop();
        await _settle(tester);
      }
    });
  });
}
