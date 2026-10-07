import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

/// Shop access for an active shop member with [role] ('owner' or 'staff').
ShopAccess activeAccess(String role) {
  return ShopAccess(
    userId: 'user-1',
    status: ShopAccessStatus.active,
    shopId: 'shop-1',
    shopName: 'Test Shop',
    role: role,
  );
}

const ownerRole = 'owner';

/// The database's current name for the attendant role.
const attendantRole = 'staff';
