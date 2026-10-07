import '../entities/new_shop_attendant.dart';
import '../entities/shop_member.dart';

/// The owner's management of their shop's members. The database and the
/// `create-shop-attendant` Edge Function authorise every call; failures
/// throw `ShopMembersException`.
abstract class ShopMembersRepository {
  /// The members of the owner's shop, owner first.
  Future<List<ShopMember>> getMembers();

  /// Creates a login for a new attendant and adds it to the owner's shop.
  Future<CreatedShopAttendant> createAttendant(NewShopAttendant attendant);

  /// active -> suspended
  Future<void> suspendMember(String memberUserId);

  /// suspended -> active
  Future<void> restoreMember(String memberUserId);

  /// Removes the attendant's membership. Their account is kept.
  Future<void> revokeMember(String memberUserId);
}
