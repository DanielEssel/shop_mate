/// What the signed-in account is allowed to do, derived from the caller's
/// shop membership and the shop's own status.
enum ShopAccessStatus {
  /// Signed in, but not linked to any shop yet -> show "register your shop".
  noShop,

  /// Shop registered, waiting for the platform admin to approve it.
  pending,

  /// Approved and active: full access to the app.
  active,

  /// The shop or this member has been suspended.
  suspended,

  /// The status could not be determined (offline / server error).
  unavailable,
}

/// The signed-in account's role in its shop.
///
/// Only 'owner' is an owner. Every other value ('staff' today, the future
/// 'shop_attendant', or anything unexpected) is an attendant, so an unknown
/// role can never gain owner access.
enum ShopRole {
  owner,
  attendant;

  static ShopRole fromValue(String? value) {
    return value == 'owner' ? ShopRole.owner : ShopRole.attendant;
  }
}

class ShopAccess {
  const ShopAccess({
    required this.userId,
    required this.status,
    this.shopId,
    this.shopName,
    this.role,
  });

  /// The account this answer belongs to. The router compares it with the
  /// current session so a stale answer for a previous user is never used.
  final String? userId;

  final ShopAccessStatus status;

  /// The shop this account currently belongs to.
  final String? shopId;

  final String? shopName;

  /// The stored role value ('owner' or 'staff') when the user belongs to a
  /// shop. Use [shopRole] for decisions.
  final String? role;

  ShopRole get shopRole => ShopRole.fromValue(role);

  bool get isOwner => shopRole == ShopRole.owner;

  bool get isAttendant => shopRole == ShopRole.attendant;
}
