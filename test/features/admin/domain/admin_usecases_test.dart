import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/admin/domain/entities/admin_exception.dart';
import 'package:shopmate/features/admin/domain/entities/admin_shop.dart';
import 'package:shopmate/features/admin/domain/usecases/approve_shop.dart';
import 'package:shopmate/features/admin/domain/usecases/check_platform_admin.dart';
import 'package:shopmate/features/admin/domain/usecases/get_admin_shops.dart';
import 'package:shopmate/features/admin/domain/usecases/reactivate_shop.dart';
import 'package:shopmate/features/admin/domain/usecases/suspend_shop.dart';

import '../fake_admin_repository.dart';

void main() {
  late FakeAdminRepository repository;

  setUp(() {
    repository = FakeAdminRepository(
      isAdmin: true,
      shops: [
        adminShop('p1', 'Pending Mart', AdminShopStatus.pending),
        adminShop('a1', 'Active Mart', AdminShopStatus.active),
        adminShop('s1', 'Paused Mart', AdminShopStatus.suspended),
      ],
    );
  });

  test('check platform admin', () async {
    expect(await CheckPlatformAdmin(repository).call(), isTrue);
    repository.isAdmin = false;
    expect(await CheckPlatformAdmin(repository).call(), isFalse);
  });

  test('load pending and active shops', () async {
    final pending = await GetAdminShops(
      repository,
    ).call(AdminShopStatus.pending);
    final active = await GetAdminShops(repository).call(AdminShopStatus.active);

    expect(pending.map((s) => s.name), ['Pending Mart']);
    expect(active.map((s) => s.name), ['Active Mart']);
  });

  test('approve moves a pending shop to active', () async {
    await ApproveShop(repository).call('p1');

    expect(repository.actions, ['approve p1']);
    expect(repository.shopsIn(AdminShopStatus.pending), isEmpty);
    expect(
      repository.shopsIn(AdminShopStatus.active).map((s) => s.id),
      containsAll(['a1', 'p1']),
    );
  });

  test('suspend moves an active shop to suspended', () async {
    await SuspendShop(repository).call('a1');

    expect(repository.actions, ['suspend a1']);
    expect(
      repository.shopsIn(AdminShopStatus.suspended).map((s) => s.id),
      containsAll(['s1', 'a1']),
    );
  });

  test('reactivate moves a suspended shop to active', () async {
    await ReactivateShop(repository).call('s1');

    expect(repository.actions, ['reactivate s1']);
    expect(repository.shopsIn(AdminShopStatus.suspended), isEmpty);
  });

  test('typed failures pass through unchanged', () async {
    repository.isAdmin = false;

    await expectLater(
      ApproveShop(repository).call('p1'),
      throwsA(
        isA<AdminException>().having(
          (e) => e.kind,
          'kind',
          AdminErrorKind.permissionDenied,
        ),
      ),
    );
  });

  test('status values round-trip with the database', () {
    for (final status in AdminShopStatus.values) {
      expect(AdminShopStatus.fromValue(status.value), status);
    }
    expect(AdminShopStatus.fromValue('deleted'), isNull);
  });
}
