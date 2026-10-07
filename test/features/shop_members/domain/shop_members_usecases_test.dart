import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop_members/domain/entities/new_shop_attendant.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_member.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_members_exception.dart';
import 'package:shopmate/features/shop_members/domain/usecases/create_shop_attendant.dart';
import 'package:shopmate/features/shop_members/domain/usecases/get_shop_members.dart';
import 'package:shopmate/features/shop_members/domain/usecases/restore_shop_member.dart';
import 'package:shopmate/features/shop_members/domain/usecases/revoke_shop_member.dart';
import 'package:shopmate/features/shop_members/domain/usecases/suspend_shop_member.dart';

import '../fake_shop_members_repository.dart';

void main() {
  late FakeShopMembersRepository repository;

  setUp(() {
    repository = FakeShopMembersRepository(
      members: [
        ownerMember,
        shopMember('staff-1', displayName: 'Ama'),
        shopMember('staff-2', status: ShopMemberStatus.suspended),
      ],
    );
  });

  test('get shop members', () async {
    final members = await GetShopMembers(repository).call();
    expect(members.map((m) => m.userId), [ownerUserId, 'staff-1', 'staff-2']);
    expect(members.first.role, ShopRole.owner);
  });

  test('create shop attendant passes the request through', () async {
    const request = NewShopAttendant(
      email: 'esi@shop.test',
      displayName: 'Esi',
      temporaryPassword: 'Temp-Pass-123',
    );

    final created = await CreateShopAttendant(repository).call(request);

    expect(repository.created.single, same(request));
    expect(created.email, 'esi@shop.test');
  });

  test('suspend, restore and revoke address the member by user id', () async {
    await SuspendShopMember(repository).call('staff-1');
    await RestoreShopMember(repository).call('staff-2');
    await RevokeShopMember(repository).call('staff-1');

    expect(repository.actions, [
      'suspend staff-1',
      'restore staff-2',
      'revoke staff-1',
    ]);
    expect(repository.members.map((m) => m.userId), [ownerUserId, 'staff-2']);
  });

  test('the owner cannot be changed', () async {
    await expectLater(
      SuspendShopMember(repository).call(ownerUserId),
      throwsA(
        isA<ShopMembersException>().having(
          (e) => e.kind,
          'kind',
          ShopMembersErrorKind.permissionDenied,
        ),
      ),
    );
  });
}
