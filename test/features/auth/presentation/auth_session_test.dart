import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/purchases/presentation/providers/purchases_provider.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';

import '../fake_auth_repository.dart';

const _rice = Product(
  id: 'product-a',
  name: 'A Rice',
  costPrice: 10,
  sellingPrice: 15,
  stockQuantity: 5,
  lowStockThreshold: 1,
);

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  ProviderContainer containerFor(FakeAuthRepository repository) {
    final created = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(created.dispose);
    return created;
  }

  /// Fills both carts the way the New Sale / New Purchase screens do, and
  /// keeps them listened to like an open screen would.
  void fillCarts() {
    container
      ..listen(saleCartProvider, (_, _) {})
      ..listen(purchaseCartProvider, (_, _) {});
    container.read(saleCartProvider.notifier).addProduct(_rice);
    container.read(purchaseCartProvider.notifier)
      ..addProduct(_rice)
      ..updateUnitCost(_rice.id, 9);
    expect(container.read(saleCartProvider), hasLength(1));
    expect(container.read(purchaseCartProvider), hasLength(1));
  }

  setUp(() {
    auth = FakeAuthRepository(userA);
    container = containerFor(auth);
  });

  tearDown(() => auth.dispose());

  group('identity', () {
    test('starts from the restored session, before any auth event', () {
      expect(container.read(authSessionProvider), userA);
      expect(container.read(currentUserIdProvider), 'user-a');
    });

    test('starts signed out without a session', () {
      final signedOut = containerFor(FakeAuthRepository());

      expect(signedOut.read(authSessionProvider), isNull);
      expect(signedOut.read(currentUserIdProvider), isNull);
    });

    test('follows auth events: A -> signed out -> B', () async {
      final ids = <String?>[];
      container.listen(currentUserIdProvider, (_, next) => ids.add(next));

      auth.changeUser(null);
      await pumpEventQueue();
      auth.changeUser(userB);
      await pumpEventQueue();

      expect(ids, [null, 'user-b']);
    });

    test(
      'a token refresh keeps the same identity and notifies nobody',
      () async {
        fillCarts();
        var idChanges = 0;
        container.listen(currentUserIdProvider, (_, _) => idChanges++);

        auth
          ..refreshToken()
          ..refreshToken();
        await pumpEventQueue();

        expect(idChanges, 0);
        expect(container.read(currentUserIdProvider), 'user-a');
        expect(container.read(saleCartProvider), hasLength(1));
        expect(container.read(purchaseCartProvider), hasLength(1));
      },
    );
  });

  group('sign out', () {
    test('clears the identity and both carts at once, without waiting for the '
        'auth event', () async {
      fillCarts();
      auth.emitEvents = false;

      await container.read(authSessionProvider.notifier).signOut();

      expect(auth.signOutCalls, 1);
      expect(container.read(authSessionProvider), isNull);
      expect(container.read(currentUserIdProvider), isNull);
      expect(container.read(saleCartProvider), isEmpty);
      expect(container.read(purchaseCartProvider), isEmpty);
    });

    test(
      'a failure that keeps the session keeps the account and reports it',
      () async {
        fillCarts();
        auth.signOutFailure = const AuthFailure(AuthFailureKind.network);

        await expectLater(
          container.read(authSessionProvider.notifier).signOut(),
          throwsA(isA<AuthFailure>()),
        );

        expect(container.read(currentUserIdProvider), 'user-a');
        expect(container.read(saleCartProvider), hasLength(1));
      },
    );
  });

  group('carts are scoped to the signed-in account', () {
    test('sale cart: A -> sign out -> B starts empty', () async {
      fillCarts();

      await container.read(authSessionProvider.notifier).signOut();
      expect(container.read(saleCartProvider), isEmpty);

      auth.changeUser(userB);
      await pumpEventQueue();
      expect(container.read(currentUserIdProvider), 'user-b');
      expect(container.read(saleCartProvider), isEmpty);
    });

    test('purchase draft: A -> sign out -> B starts empty', () async {
      fillCarts();

      await container.read(authSessionProvider.notifier).signOut();
      expect(container.read(purchaseCartProvider), isEmpty);

      auth.changeUser(userB);
      await pumpEventQueue();
      expect(container.read(purchaseCartProvider), isEmpty);
    });

    test('a direct identity change A -> B drops A\'s carts', () async {
      fillCarts();

      auth.changeUser(userB);
      await pumpEventQueue();

      expect(container.read(saleCartProvider), isEmpty);
      expect(container.read(purchaseCartProvider), isEmpty);
    });

    test('carts nobody is watching are also reset on the next read', () async {
      container.read(saleCartProvider.notifier).addProduct(_rice);
      container.read(purchaseCartProvider.notifier).addProduct(_rice);

      auth.changeUser(userB);
      await pumpEventQueue();

      expect(container.read(saleCartProvider), isEmpty);
      expect(container.read(purchaseCartProvider), isEmpty);
    });
  });
}
