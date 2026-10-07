import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/router/app_router.dart';
import 'package:shopmate/features/admin/domain/entities/admin_shop.dart';
import 'package:shopmate/features/admin/presentation/screens/admin_screen.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

import '../../../app/app_test_harness.dart';
import '../../auth/fake_auth_repository.dart';
import '../fake_admin_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('gate decisions for /admin', () {
    String? decide({
      String? userId = 'user-a',
      ShopAccessStatus shop = ShopAccessStatus.active,
      AsyncValue<bool>? admin,
    }) {
      return resolveAppRedirect(
        location: adminRoute,
        userId: userId,
        access: AsyncData(shopAccessFor('user-a', shop)),
        platformAdmin: admin,
      );
    }

    test('a confirmed admin stays, whatever their own shop status', () {
      for (final status in ShopAccessStatus.values) {
        expect(decide(shop: status, admin: const AsyncData(true)), isNull);
      }
    });

    test('a non-admin is sent where /dashboard would send them', () {
      const notAdmin = AsyncData(false);
      expect(decide(admin: notAdmin), '/dashboard');
      expect(
        decide(shop: ShopAccessStatus.pending, admin: notAdmin),
        '/pending',
      );
      expect(
        decide(shop: ShopAccessStatus.suspended, admin: notAdmin),
        '/suspended',
      );
      expect(decide(admin: null), '/dashboard');
    });

    test('a failed check never grants access', () {
      expect(
        decide(
          admin: AsyncError<bool>(StateError('offline'), StackTrace.empty),
        ),
        '/dashboard',
      );
    });

    test('signed out goes to login, even with a stale "true"', () {
      expect(decide(userId: null, admin: const AsyncData(true)), '/login');
    });

    test('while the check runs the screen waits (and shows no data)', () {
      expect(decide(admin: const AsyncLoading<bool>()), isNull);
    });
  });

  group('routing', () {
    testWidgets('a normal shop user cannot open /admin', (tester) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.active},
      );

      h.router.go(adminRoute);
      await settleApp(tester);

      expect(h.location, '/dashboard');
      expect(find.byType(AdminScreen), findsNothing);
      expect(h.admin.adminChecks, greaterThan(0));
    });

    testWidgets('a pending shop owner who is not an admin stays gated', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.pending},
      );
      expect(h.location, '/pending');
      expect(find.text('Open Platform Admin'), findsNothing);

      h.router.go(adminRoute);
      await settleApp(tester);

      expect(h.location, '/pending');
    });

    testWidgets('an admin whose own shop is pending can reach Admin from the '
        'gate screen', (tester) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.pending},
        platformAdminIds: {userA.id},
      );
      expect(h.location, '/pending');

      await tester.tap(find.text('Open Platform Admin'));
      await settleApp(tester);

      expect(h.location, adminRoute);
      expect(find.byType(AdminScreen), findsOne);
    });

    testWidgets('admin access ends with the account: A (admin) -> B', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {
          'user-a': ShopAccessStatus.active,
          'user-b': ShopAccessStatus.active,
        },
        platformAdminIds: {userA.id},
      );
      h.router.go(adminRoute);
      await settleApp(tester);
      expect(h.location, adminRoute);

      await h.container.read(authSessionProvider.notifier).signOut();
      await settleApp(tester);
      expect(h.location, '/login');
      // Let the app shell finish animating out before B's shell mounts.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      h.auth.changeUser(userB);
      await settleApp(tester);
      h.router.go(adminRoute);
      await settleApp(tester);

      expect(h.location, '/dashboard');
      expect(find.byType(AdminScreen), findsNothing);
    });
  });

  group('database contract', () {
    test('a non-admin is refused by the repository, whatever the UI shows', () {
      // The fake mirrors the RPCs: every admin call checks the caller.
      final repository = FakeAdminRepository(
        currentUserId: () => userB.id,
        adminUserIds: {userA.id},
        shops: [adminShop('p1', 'Pending Mart', AdminShopStatus.pending)],
      );

      expect(repository.approveShop('p1'), throwsA(isA<Object>()));
      expect(
        repository.getShops(AdminShopStatus.pending),
        throwsA(isA<Object>()),
      );
    });
  });
}
