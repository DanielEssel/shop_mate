import 'package:flutter/foundation.dart';

/// A supplier of the caller's active shop. Purchases keep their own
/// supplier name/phone snapshot, so editing a supplier never rewrites history.
@immutable
class Supplier {
  const Supplier({
    required this.id,
    required this.shopId,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.createdBy,
  });

  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  /// Inactive suppliers are kept for history but cannot be used on new
  /// purchases.
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
