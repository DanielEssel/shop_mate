import 'package:flutter/foundation.dart';

/// A shop's platform status (`shops.status`).
enum AdminShopStatus {
  pending('pending'),
  active('active'),
  suspended('suspended');

  const AdminShopStatus(this.value);

  /// The value stored in the database.
  final String value;

  static AdminShopStatus? fromValue(String value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// A shop as the platform admin sees it: enough to identify it safely.
@immutable
class AdminShop {
  const AdminShop({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.ownerEmail,
    this.approvedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final AdminShopStatus status;

  /// The owner's sign-in email, when known.
  final String? ownerEmail;

  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime updatedAt;
}
