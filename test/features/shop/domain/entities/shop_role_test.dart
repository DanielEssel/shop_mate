import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

ShopAccess _access(
  String? role, {
  ShopAccessStatus status = ShopAccessStatus.active,
}) {
  return ShopAccess(
    userId: 'user-1',
    status: status,
    shopId: 'shop-1',
    role: role,
  );
}

void main() {
  group('ShopRole.fromValue', () {
    test('only "owner" is an owner', () {
      expect(ShopRole.fromValue('owner'), ShopRole.owner);
    });

    test('staff, the future shop_attendant and anything else fail closed', () {
      for (final value in [
        'staff',
        'shop_attendant',
        'Owner',
        'OWNER',
        'admin',
        '',
        null,
      ]) {
        expect(ShopRole.fromValue(value), ShopRole.attendant, reason: '$value');
      }
    });
  });

  test('ShopAccess exposes the typed role', () {
    final owner = _access('owner');
    final staff = _access('staff');

    expect(owner.shopRole, ShopRole.owner);
    expect(owner.isOwner, isTrue);
    expect(owner.isAttendant, isFalse);
    expect(staff.shopRole, ShopRole.attendant);
    expect(staff.isOwner, isFalse);
    expect(staff.isAttendant, isTrue);
  });

  group('selectIsShopOwner', () {
    test('true only for the owner of an active shop', () {
      expect(selectIsShopOwner(AsyncData(_access('owner'))), isTrue);
      expect(selectIsShopOwner(AsyncData(_access('staff'))), isFalse);
    });

    test('an owner whose shop is not active gets no owner UI', () {
      for (final status in [
        ShopAccessStatus.pending,
        ShopAccessStatus.suspended,
        ShopAccessStatus.unavailable,
        ShopAccessStatus.noShop,
      ]) {
        expect(
          selectIsShopOwner(AsyncData(_access('owner', status: status))),
          isFalse,
          reason: status.name,
        );
      }
    });

    test('loading and errors fail closed', () {
      expect(selectIsShopOwner(const AsyncLoading<ShopAccess>()), isFalse);
      expect(
        selectIsShopOwner(
          AsyncError<ShopAccess>(StateError('x'), StackTrace.empty),
        ),
        isFalse,
      );
    });
  });
}
