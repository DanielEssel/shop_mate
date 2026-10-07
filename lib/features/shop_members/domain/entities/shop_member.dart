import 'package:flutter/foundation.dart';

import '../../../shop/domain/entities/shop_access.dart';

/// A member's access to the shop (`shop_members.status`).
enum ShopMemberStatus {
  active('active'),
  suspended('suspended');

  const ShopMemberStatus(this.value);

  /// The value stored in the database.
  final String value;

  static ShopMemberStatus? fromValue(String value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// One member of the owner's shop, as `list_shop_members()` returns it.
@immutable
class ShopMember {
  const ShopMember({
    required this.memberId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.displayName,
  });

  /// The membership row.
  final String memberId;

  /// The member's ShopMate account. Suspend, restore and revoke address the
  /// member by this id.
  final String userId;

  /// Mapped from the stored role: 'owner' is the owner and every other value
  /// ('staff') is an attendant, exactly as for the signed-in account.
  final ShopRole role;

  final ShopMemberStatus status;

  /// The account's sign-in email, when known.
  final String? email;

  /// The name given when the account was created, if any.
  final String? displayName;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOwner => role == ShopRole.owner;

  bool get isActive => status == ShopMemberStatus.active;

  /// The best label for this person: their name, else their email.
  String get label => displayName ?? email ?? 'Shop attendant';
}
