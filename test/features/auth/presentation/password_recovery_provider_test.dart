import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/auth/presentation/providers/password_recovery_provider.dart';

import '../fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    // Like the router, keep the recovery state listened to.
    container.listen(passwordRecoveryProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await auth.dispose();
  });

  PasswordRecoveryNotifier recovery() =>
      container.read(passwordRecoveryProvider.notifier);

  group('belongsTo', () {
    test('before verification it matches the address, ignoring case', () {
      const pending = PasswordRecovery(email: 'a@shop.test');

      expect(pending.belongsTo(userId: 'user-a', email: 'A@Shop.test'), isTrue);
      expect(
        pending.belongsTo(userId: 'user-b', email: 'b@shop.test'),
        isFalse,
      );
      expect(pending.belongsTo(userId: 'user-a', email: null), isFalse);
    });

    test('after verification only the recovering account matches', () {
      const verified = PasswordRecovery(email: 'a@shop.test', userId: 'user-a');

      expect(verified.belongsTo(userId: 'user-a', email: 'x@y.z'), isTrue);
      expect(
        verified.belongsTo(userId: 'user-b', email: 'a@shop.test'),
        isFalse,
      );
    });
  });

  test('start normalises the address; verified records the account', () {
    recovery().start('  A@Shop.Test ');
    expect(container.read(passwordRecoveryProvider)?.email, 'a@shop.test');
    expect(container.read(passwordRecoveryProvider)?.userId, isNull);

    recovery().verified(userA);
    expect(container.read(passwordRecoveryProvider)?.userId, 'user-a');
  });

  test('verified without a started recovery does nothing', () {
    recovery().verified(userA);
    expect(container.read(passwordRecoveryProvider), isNull);
  });

  test('the recovery session signing in does not end the recovery', () async {
    recovery().start(userA.email!);
    auth.changeUser(userA);
    await pumpEventQueue();

    expect(container.read(passwordRecoveryProvider), isNotNull);
  });

  test('signing the recovering account out ends the recovery', () async {
    recovery().start(userA.email!);
    auth.changeUser(userA);
    await pumpEventQueue();
    recovery().verified(userA);

    await container.read(authSessionProvider.notifier).signOut();
    await pumpEventQueue();

    expect(container.read(passwordRecoveryProvider), isNull);
  });

  test('another account taking over ends the recovery', () async {
    recovery().start(userA.email!);
    auth.changeUser(userA);
    await pumpEventQueue();
    recovery().verified(userA);

    auth.changeUser(userB);
    await pumpEventQueue();

    expect(container.read(passwordRecoveryProvider), isNull);
  });
}
