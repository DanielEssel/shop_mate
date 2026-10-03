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

  /// 'owner' or 'staff' when the user belongs to a shop.
  final String? role;

  bool get isOwner => role == 'owner';
}
