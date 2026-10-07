import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/app/router/app_router.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/auth/presentation/providers/password_recovery_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

import '../../features/auth/fake_auth_repository.dart';
import '../app_test_harness.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('gate decisions', () {
    String? decide(
      String location, {
      String? userId = 'user-a',
      AsyncValue<ShopAccess>? access,
    }) {
      return resolveAppRedirect(
        location: location,
        userId: userId,
        access:
            access ??
            AsyncData(shopAccessFor('user-a', ShopAccessStatus.active)),
      );
    }

    test('signed out: protected routes go to login, auth routes stay', () {
      for (final location in ['/dashboard', '/products', '/settings']) {
        expect(decide(location, userId: null), '/login');
      }
      expect(decide('/login', userId: null), isNull);
      expect(decide('/signup', userId: null), isNull);
    });

    test('access still loading waits on the splash', () {
      const loading = AsyncLoading<ShopAccess>();
      expect(decide('/dashboard', access: loading), '/loading');
      expect(decide('/login', access: loading), '/loading');
      expect(decide('/loading', access: loading), isNull);
      // A status screen re-checking stays put.
      expect(decide('/pending', access: loading), isNull);
    });

    test('each status has its own screen', () {
      const expected = {
        ShopAccessStatus.noShop: '/register-shop',
        ShopAccessStatus.pending: '/pending',
        ShopAccessStatus.suspended: '/suspended',
        ShopAccessStatus.unavailable: '/access-error',
      };
      expected.forEach((status, target) {
        final access = AsyncData(shopAccessFor('user-a', status));
        expect(decide('/dashboard', access: access), target);
        expect(decide(target, access: access), isNull);
      });
    });

    test('active: the app opens and the gate screens are left', () {
      expect(decide('/dashboard'), isNull);
      expect(decide('/customers'), isNull);
      for (final location in [
        '/login',
        '/signup',
        '/loading',
        '/register-shop',
        '/pending',
        '/suspended',
        '/access-error',
      ]) {
        expect(decide(location), '/dashboard');
      }
    });

    test('a recovering account is held on the recovery screen', () {
      const verifying = PasswordRecovery(email: 'a@shop.test');
      const verified = PasswordRecovery(email: 'a@shop.test', userId: 'user-a');

      for (final recovery in [verifying, verified]) {
        String? recoveringDecide(String location) => resolveAppRedirect(
          location: location,
          userId: 'user-a',
          userEmail: 'a@shop.test',
          access: AsyncData(shopAccessFor('user-a', ShopAccessStatus.active)),
          recovery: recovery,
        );

        expect(recoveringDecide('/forgot-password'), isNull);
        for (final location in ['/dashboard', '/login', '/loading', '/sales']) {
          expect(recoveringDecide(location), '/forgot-password');
        }
      }
    });

    test("another account's recovery is ignored", () {
      expect(
        resolveAppRedirect(
          location: '/dashboard',
          userId: 'user-b',
          userEmail: 'b@shop.test',
          access: AsyncData(shopAccessFor('user-b', ShopAccessStatus.active)),
          recovery: const PasswordRecovery(
            email: 'a@shop.test',
            userId: 'user-a',
          ),
        ),
        isNull,
      );
    });

    test('recovery screen: open when signed out, left when signed in', () {
      expect(decide('/forgot-password', userId: null), isNull);
      expect(decide('/forgot-password'), '/dashboard');
    });

    test("another account's answer is never trusted", () {
      final staleActive = AsyncData(
        shopAccessFor('user-a', ShopAccessStatus.active),
      );
      final staleSuspended = AsyncData(
        shopAccessFor('user-a', ShopAccessStatus.suspended),
      );

      expect(
        decide('/dashboard', userId: 'user-b', access: staleActive),
        '/loading',
      );
      expect(
        decide('/dashboard', userId: 'user-b', access: staleSuspended),
        '/loading',
      );
    });
  });

  group('router', () {
    testWidgets('signed out opens on login', (tester) async {
      final h = await pumpApp(tester);

      expect(h.location, '/login');
    });

    testWidgets('signed out cannot open a protected route', (tester) async {
      final h = await pumpApp(tester);

      h.router.go('/products');
      await settleApp(tester);

      expect(h.location, '/login');
    });

    testWidgets('loading access shows the splash', (tester) async {
      final h = await pumpApp(tester, user: userA);

      expect(h.location, '/loading');

      h.shops.complete('user-a', ShopAccessStatus.active);
      await settleApp(tester);
      expect(h.location, '/dashboard');
    });

    final statusRoutes = {
      ShopAccessStatus.noShop: '/register-shop',
      ShopAccessStatus.pending: '/pending',
      ShopAccessStatus.suspended: '/suspended',
      ShopAccessStatus.unavailable: '/access-error',
      ShopAccessStatus.active: '/dashboard',
    };
    statusRoutes.forEach((status, route) {
      testWidgets('${status.name} access goes to $route', (tester) async {
        final h = await pumpApp(
          tester,
          user: userA,
          answers: {'user-a': status},
        );

        expect(h.location, route);
      });
    });

    for (final route in ['/login', '/signup']) {
      testWidgets('an active user is sent from $route into the app', (
        tester,
      ) async {
        final h = await pumpApp(
          tester,
          user: userA,
          answers: {'user-a': ShopAccessStatus.active},
        );

        h.router.go(route);
        await settleApp(tester);

        expect(h.location, '/dashboard');
      });
    }

    testWidgets('signing out leaves the app for login and keeps it closed', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.active},
      );
      expect(h.location, '/dashboard');

      await h.container.read(authSessionProvider.notifier).signOut();
      await settleApp(tester);
      expect(h.location, '/login');

      h.router.go('/dashboard');
      await settleApp(tester);
      expect(h.location, '/login');
    });

    testWidgets('A -> B: B waits for its own answer, never A\'s', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.active},
      );
      expect(h.location, '/dashboard');

      // B has no answer yet; A's "active" must not let B into the app.
      h.auth.changeUser(userB);
      await settleApp(tester);
      expect(h.location, '/loading');
      expect(h.shops.fetchedFor, ['user-a', 'user-b']);

      h.shops.complete('user-b', ShopAccessStatus.pending);
      await settleApp(tester);
      expect(h.location, '/pending');
    });

    testWidgets('signing in on the login form moves the app forward', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        answers: {'user-a': ShopAccessStatus.active},
      );
      expect(h.location, '/login');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        userA.email!,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret-pass',
      );
      await tester.tap(find.text('Sign In'));
      await settleApp(tester);

      expect(h.auth.signInCalls, hasLength(1));
      expect(h.location, '/dashboard');
    });

    testWidgets('a token refresh does not re-check access', (tester) async {
      final h = await pumpApp(
        tester,
        user: userA,
        answers: {'user-a': ShopAccessStatus.active},
      );

      h.auth.refreshToken();
      await settleApp(tester);

      expect(h.location, '/dashboard');
      expect(h.shops.fetchedFor, ['user-a']);
    });
  });
}
