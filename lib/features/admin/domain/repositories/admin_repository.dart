import '../entities/admin_shop.dart';

/// Platform administration. The database authorises every call; failures
/// throw `AdminException`.
abstract class AdminRepository {
  /// Whether the signed-in account is a platform admin.
  Future<bool> isPlatformAdmin();

  Future<List<AdminShop>> getShops(AdminShopStatus status);

  /// pending -> active
  Future<void> approveShop(String shopId);

  /// active -> suspended
  Future<void> suspendShop(String shopId);

  /// suspended -> active
  Future<void> reactivateShop(String shopId);
}
