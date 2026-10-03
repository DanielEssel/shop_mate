import '../entities/shop_access.dart';

abstract class ShopRepository {
  /// Reads the caller's membership and shop status.
  /// Throws if the backend cannot be reached.
  Future<ShopAccess> fetchAccess(String userId);

  /// Calls the `register_shop` database function, which creates a PENDING
  /// shop owned by the caller. Throws a [PostgrestException] whose message is
  /// user-readable when validation fails.
  Future<void> registerShop({
    required String name,
    required String phone,
  });
}
