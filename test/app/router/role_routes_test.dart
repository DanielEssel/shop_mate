import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/router/app_router.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

import '../../features/auth/fake_auth_repository.dart';
import '../app_test_harness.dart';

const _ownerOnly = [
  '/expenses',
  '/expenses/expense-1',
  '/reports/business-performance',
  '/reports/inventory',
  '/settings',
  '/settings/categories',
  '/users',
  '/inventory/adjust',
];

const _operational = [
  '/dashboard',
  '/products',
  '/products/new',
  '/products/edit',
  '/products/product-1',
  '/inventory',
  '/inventory/low-stock',
  '/inventory/history',
  '/sales',
  '/sales/new',
  '/sales/sale-1',
  '/customers',
  '/customers/add',
  '/customers/customer-1',
  '/purchases',
  '/purchases/new',
  '/purchases/purchase-1',
  '/suppliers',
  '/suppliers/new',
  '/suppliers/supplier-1/edit',
  '/more',
];

String? _decide(String location, String role) {
  return resolveAppRedirect(
    location: location,
    userId: 'user-a',
    access: AsyncData(
      shopAccessFor('user-a', ShopAccessStatus.active, role: role),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('gate decisions by role', () {
    test('owner reaches every owner-only route', () {
      for (final route in _ownerOnly) {
        expect(_decide(route, 'owner'), isNull, reason: route);
      }
    });

    test('attendant is sent to the dashboard from owner-only routes', () {
      for (final route in _ownerOnly) {
        expect(_decide(route, 'staff'), '/dashboard', reason: route);
      }
    });

    test('an unknown role is treated as an attendant', () {
      expect(_decide('/expenses', 'manager'), '/dashboard');
      expect(_decide('/settings', 'shop_attendant'), '/dashboard');
    });

    test('attendant keeps every operational route', () {
      for (final route in _operational) {
        expect(_decide(route, 'staff'), isNull, reason: route);
      }
    });

    test('lookalike routes are not caught by the owner-only prefixes', () {
      expect(_decide('/inventory/history', 'staff'), isNull);
      expect(_decide('/inventory', 'staff'), isNull);
    });
  });

  group('router', () {
    for (final route in [
      '/expenses',
      '/reports/business-performance',
      '/reports/inventory',
      '/settings',
      '/settings/categories',
      '/users',
      '/inventory/adjust',
    ]) {
      testWidgets('attendant opening $route lands on the dashboard', (
        tester,
      ) async {
        final h = await pumpApp(
          tester,
          user: userA,
          answers: {'user-a': ShopAccessStatus.active},
          roles: {'user-a': 'staff'},
        );
        expect(h.location, '/dashboard');

        h.router.go(route);
        await settleApp(tester);

        expect(h.location, '/dashboard');
      });
    }

    testWidgets('the owner opens Users & Permissions', (tester) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.active},
      );

      h.router.go('/users');
      await settleApp(tester);

      expect(h.location, '/users');
      expect(find.text('Users & Permissions'), findsOne);
    });

    testWidgets('the owner\'s live access answer passes the owner-only gate', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.active},
      );

      expect(
        resolveAppRedirect(
          location: '/settings',
          userId: 'user-a',
          access: h.container.read(shopAccessProvider),
        ),
        isNull,
      );
    });
  });
}
